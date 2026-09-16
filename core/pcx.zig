// Port of 8-bit paletted PCX decoding/encoding (sdl/gfx.c read_pcx,
// modify/gobpack.c's private read_pcx/write_pcx) per docs/porting-playbook.md
// TASK-010.03. This is the single shared codec both the .dat asset pipeline
// and gobpack's duplicated implementation are meant to converge on.
//
// Layout: a 128-byte PCX header (only its presence matters here — decode()
// skips it exactly like read_pcx does, without validating its fields), then
// RLE-packed 8-bit pixel data (a byte with its top two bits set is a run:
// low 6 bits = count, next byte = value; anything else is a literal pixel),
// then (optionally) a 0x0c palette marker byte and a 768-byte (256 * RGB)
// palette. read_pcx also right-shifts every palette byte by 2 (VGA 6-bit DAC
// scaling) — preserved bug-for-bug below.
const std = @import("std");

pub const header_size = 128;
pub const palette_size = 768;

pub const DecodeError = error{Truncated};

pub const Decoded = struct {
    allocator: std.mem.Allocator,
    pixels: []u8,
    palette: ?[palette_size]u8,

    pub fn deinit(self: *Decoded) void {
        self.allocator.free(self.pixels);
        self.* = undefined;
    }
};

// read_pcx: RLE-decode buf_len pixels starting after the 128-byte header, and
// (if with_palette) the trailing VGA-scaled 768-byte palette. buf is the
// entire PCX file (header included), matching the C signature's `handle`
// pointing at the start of the file.
pub fn decode(allocator: std.mem.Allocator, buf: []const u8, pixel_count: usize, with_palette: bool) !Decoded {
    if (buf.len < header_size) return DecodeError.Truncated;

    const pixels = try allocator.alloc(u8, pixel_count);
    errdefer allocator.free(pixels);

    var src: usize = header_size;
    var dst: usize = 0;
    while (dst < pixel_count) {
        if (src >= buf.len) return DecodeError.Truncated;
        const a = buf[src];
        src += 1;
        if ((a & 0xc0) == 0xc0) {
            if (src >= buf.len) return DecodeError.Truncated;
            const b = buf[src];
            src += 1;
            const run_len = a & 0x3f;
            var c: u8 = 0;
            while (c < run_len and dst < pixel_count) : (c += 1) {
                pixels[dst] = b;
                dst += 1;
            }
        } else {
            pixels[dst] = a;
            dst += 1;
        }
    }

    var palette: ?[palette_size]u8 = null;
    if (with_palette) {
        // C: `handle++` skips the 0x0c palette-ID marker byte unconditionally,
        // without checking its value.
        if (src + 1 + palette_size > buf.len) return DecodeError.Truncated;
        src += 1;
        var pal: [palette_size]u8 = undefined;
        for (&pal, 0..) |*p, i| p.* = buf[src + i] >> 2;
        palette = pal;
    }

    return .{ .allocator = allocator, .pixels = pixels, .palette = palette };
}

// write_pcx: encode width*height 8-bit paletted pixels as a PCX file,
// byte-identical to modify/gobpack.c's write_pcx. `palette` is the raw
// (already-unscaled) 768-byte palette to embed, or null to emit the i/3
// grayscale ramp write_pcx falls back to.
pub fn encode(allocator: std.mem.Allocator, pixels: []const u8, width: u16, height: u16, palette: ?[palette_size]u8) ![]u8 {
    std.debug.assert(pixels.len == @as(usize, width) * @as(usize, height));

    var out = try std.ArrayList(u8).initCapacity(allocator, header_size + pixels.len * 2 + 1 + palette_size);
    errdefer out.deinit(allocator);

    try out.append(allocator, 0x0a); // manufacturer
    try out.append(allocator, 5); // version
    try out.append(allocator, 1); // encoding
    try out.append(allocator, 8); // bits_per_pixel
    try out.append(allocator, 0); // xmin
    try out.append(allocator, 0);
    try out.append(allocator, 0); // ymin
    try out.append(allocator, 0);
    try appendU16(allocator, &out, width -% 1); // xmax
    try appendU16(allocator, &out, height -% 1); // ymax
    try appendU16(allocator, &out, width); // hres
    try appendU16(allocator, &out, height); // vres
    try out.appendNTimes(allocator, 0, 48); // palette (EGA, unused for 8bpp)
    try out.append(allocator, 0); // reserved
    try out.append(allocator, 1); // color_planes
    try appendU16(allocator, &out, width); // bytes_per_line
    try appendU16(allocator, &out, 1); // palette_type
    try out.appendNTimes(allocator, 0, 58); // filler

    std.debug.assert(out.items.len == header_size);

    for (pixels) |p| {
        if ((p & 0xc0) != 0xc0) {
            try out.append(allocator, p);
        } else {
            try out.append(allocator, 0xc1);
            try out.append(allocator, p);
        }
    }

    try out.append(allocator, 0x0c);
    if (palette) |pal| {
        try out.appendSlice(allocator, &pal);
    } else {
        var i: usize = 0;
        while (i < palette_size) : (i += 1) try out.append(allocator, @intCast(i / 3));
    }

    return out.toOwnedSlice(allocator);
}

fn appendU16(allocator: std.mem.Allocator, out: *std.ArrayList(u8), v: u16) !void {
    try out.append(allocator, @intCast(v & 0xff));
    try out.append(allocator, @intCast((v >> 8) & 0xff));
}

test "decode: literal run then RLE run" {
    const allocator = std.testing.allocator;
    var buf = [_]u8{0} ** header_size;
    // 3 literal-ish bytes (top two bits clear) then an RLE run of 4 * 0x2a.
    const body = [_]u8{ 0x01, 0x02, 0x03, 0xc4, 0x2a };
    var full = try allocator.alloc(u8, header_size + body.len);
    defer allocator.free(full);
    @memcpy(full[0..header_size], &buf);
    @memcpy(full[header_size..], &body);
    _ = &buf;

    var d = try decode(allocator, full, 7, false);
    defer d.deinit();
    try std.testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 3, 0x2a, 0x2a, 0x2a, 0x2a }, d.pixels);
    try std.testing.expect(d.palette == null);
}

test "decode: palette is right-shifted by 2 (VGA 6-bit DAC scaling)" {
    const allocator = std.testing.allocator;
    var full = try allocator.alloc(u8, header_size + 1 + 1 + palette_size);
    defer allocator.free(full);
    @memset(full, 0);
    full[header_size] = 0x41; // one literal pixel
    full[header_size + 1] = 0x0c; // palette marker
    for (0..palette_size) |i| full[header_size + 2 + i] = 0xff;

    var d = try decode(allocator, full, 1, true);
    defer d.deinit();
    try std.testing.expectEqual(@as(u8, 0x41), d.pixels[0]);
    for (d.palette.?) |b| try std.testing.expectEqual(@as(u8, 0xff >> 2), b);
}

test "decode rejects truncated RLE data" {
    const allocator = std.testing.allocator;
    var full = [_]u8{0} ** (header_size + 1);
    full[header_size] = 0xc4; // RLE run header with no count byte following
    try std.testing.expectError(DecodeError.Truncated, decode(allocator, &full, 4, false));
}

test "encode/decode round-trip is pixel-identical" {
    const allocator = std.testing.allocator;
    const pixels = [_]u8{ 0, 1, 2, 0xc1, 0xc1, 0xc1, 5, 6, 9 };
    var palette: [palette_size]u8 = undefined;
    for (&palette, 0..) |*p, i| p.* = @intCast(i % 256);

    const encoded = try encode(allocator, &pixels, 3, 3, palette);
    defer allocator.free(encoded);

    var d = try decode(allocator, encoded, pixels.len, true);
    defer d.deinit();

    try std.testing.expectEqualSlices(u8, &pixels, d.pixels);
    // write_pcx embeds the raw palette; read_pcx right-shifts by 2 on the way
    // back out (VGA 6-bit DAC scaling) — so decode(encode(pal)) == pal >> 2,
    // not pal itself.
    var expected_palette: [palette_size]u8 = undefined;
    for (&expected_palette, palette) |*e, p| e.* = p >> 2;
    try std.testing.expectEqualSlices(u8, &expected_palette, &d.palette.?);
}

test "encode escapes bytes whose top two bits are set, even as literals" {
    const allocator = std.testing.allocator;
    const pixels = [_]u8{0xc1};
    const encoded = try encode(allocator, &pixels, 1, 1, null);
    defer allocator.free(encoded);
    try std.testing.expectEqual(@as(u8, 0xc1), encoded[header_size]);
    try std.testing.expectEqual(@as(u8, 0xc1), encoded[header_size + 1]);
}
