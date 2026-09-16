// Port of the .gob sprite format (sdl/gfx.c register_gob, modify/gobpack.c
// read_gob/write_gob) per docs/porting-playbook.md TASK-010.02 and
// levelmaking/gob.txt.
//
// Layout: u16 num_images, then u32 offset[num_images] (little-endian), then
// per image at its offset: u16 width, u16 height, u16 hs_x, u16 hs_y, then an
// 8-bit paletted width*height bitmap with color 0 as the transparent key.
// width/height/hs_x/hs_y are all read as *signed* 16-bit (register_gob casts
// through `(short)`), so a hotspot may legitimately be negative.
const std = @import("std");

pub const DecodeError = error{Truncated};
pub const EncodeError = error{ TooManyImages, NegativeImageSize };

pub const Image = struct {
    width: i16,
    height: i16,
    hs_x: i16,
    hs_y: i16,
    // Row-major, width*height bytes, sliced from the Gob's owned buffer.
    data: []const u8,
};

pub const Gob = struct {
    allocator: std.mem.Allocator,
    // Owns a duplicate of the decoded input buffer; every Image.data slice
    // points into this, mirroring register_gob's single malloc+memcpy.
    owned_buf: []u8,
    images: []Image,

    pub fn deinit(self: *Gob) void {
        self.allocator.free(self.owned_buf);
        self.allocator.free(self.images);
        self.* = undefined;
    }
};

fn readI16(buf: []const u8, ofs: usize) i16 {
    return @bitCast(std.mem.readInt(u16, buf[ofs..][0..2], .little));
}

// register_gob / read_gob: decode a .gob payload (as returned by dat_open) of
// the given length into a Gob. buf is duplicated internally so the result
// outlives the caller's buffer.
pub fn decode(allocator: std.mem.Allocator, buf: []const u8) !Gob {
    if (buf.len < 2) return DecodeError.Truncated;

    const owned_buf = try allocator.dupe(u8, buf);
    errdefer allocator.free(owned_buf);

    const num_images = std.mem.readInt(u16, owned_buf[0..2], .little);
    const images = try allocator.alloc(Image, num_images);
    errdefer allocator.free(images);

    var i: usize = 0;
    while (i < num_images) : (i += 1) {
        const table_ofs = 2 + i * 4;
        if (table_ofs + 4 > owned_buf.len) return DecodeError.Truncated;
        const offset = std.mem.readInt(u32, owned_buf[table_ofs..][0..4], .little);
        if (offset + 8 > owned_buf.len) return DecodeError.Truncated;

        const width = readI16(owned_buf, offset);
        const height = readI16(owned_buf, offset + 2);
        const hs_x = readI16(owned_buf, offset + 4);
        const hs_y = readI16(owned_buf, offset + 6);

        const image_size: i32 = @as(i32, width) * @as(i32, height);
        if (image_size < 0) return DecodeError.Truncated;
        const pixel_start = offset + 8;
        const pixel_end = pixel_start + @as(u32, @intCast(image_size));
        if (pixel_end > owned_buf.len) return DecodeError.Truncated;

        images[i] = .{
            .width = width,
            .height = height,
            .hs_x = hs_x,
            .hs_y = hs_y,
            .data = owned_buf[pixel_start..pixel_end],
        };
    }

    return .{ .allocator = allocator, .owned_buf = owned_buf, .images = images };
}

// write_gob: encode images (in order) into a .gob payload, byte-identical to
// modify/gobpack.c's writer.
pub fn encode(allocator: std.mem.Allocator, images: []const Image) ![]u8 {
    if (images.len > std.math.maxInt(u16)) return EncodeError.TooManyImages;

    var total: usize = 2 + images.len * 4;
    for (images) |img| {
        const size: i32 = @as(i32, img.width) * @as(i32, img.height);
        if (size < 0) return EncodeError.NegativeImageSize;
        total += 8 + @as(usize, @intCast(size));
    }

    const out = try allocator.alloc(u8, total);
    errdefer allocator.free(out);

    std.mem.writeInt(u16, out[0..2], @intCast(images.len), .little);

    var offset: u32 = @intCast(2 + images.len * 4);
    for (images, 0..) |img, i| {
        std.mem.writeInt(u32, out[2 + i * 4 ..][0..4], offset, .little);
        offset += 8 + @as(u32, @intCast(img.data.len));
    }

    var cursor: usize = 2 + images.len * 4;
    for (images) |img| {
        std.mem.writeInt(u16, out[cursor..][0..2], @bitCast(img.width), .little);
        std.mem.writeInt(u16, out[cursor + 2 ..][0..2], @bitCast(img.height), .little);
        std.mem.writeInt(u16, out[cursor + 4 ..][0..2], @bitCast(img.hs_x), .little);
        std.mem.writeInt(u16, out[cursor + 6 ..][0..2], @bitCast(img.hs_y), .little);
        cursor += 8;
        @memcpy(out[cursor .. cursor + img.data.len], img.data);
        cursor += img.data.len;
    }

    return out;
}

pub const BlitPosition = struct { x: i32, y: i32 };

// A sprite at (x, y) blits at (x - hs_x, y - hs_y): the hotspot is the offset
// from the sprite's top-left corner to its logical anchor point.
pub fn blitPosition(x: i32, y: i32, hs_x: i16, hs_y: i16) BlitPosition {
    return .{ .x = x - hs_x, .y = y - hs_y };
}

fn buildGobBytes(allocator: std.mem.Allocator) ![]u8 {
    const img0_data = [_]u8{ 1, 2, 3, 4, 5, 6 }; // 3x2
    const img1_data = [_]u8{ 7, 8, 9, 10, 11, 12, 13, 14 }; // 2x4
    const images = [_]Image{
        .{ .width = 3, .height = 2, .hs_x = 1, .hs_y = 1, .data = &img0_data },
        .{ .width = 2, .height = 4, .hs_x = -1, .hs_y = 0, .data = &img1_data },
    };
    return encode(allocator, &images);
}

test "encode/decode round-trips image data and hotspots" {
    const allocator = std.testing.allocator;
    const bytes = try buildGobBytes(allocator);
    defer allocator.free(bytes);

    var gob = try decode(allocator, bytes);
    defer gob.deinit();

    try std.testing.expectEqual(@as(usize, 2), gob.images.len);

    try std.testing.expectEqual(@as(i16, 3), gob.images[0].width);
    try std.testing.expectEqual(@as(i16, 2), gob.images[0].height);
    try std.testing.expectEqual(@as(i16, 1), gob.images[0].hs_x);
    try std.testing.expectEqual(@as(i16, 1), gob.images[0].hs_y);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 3, 4, 5, 6 }, gob.images[0].data);

    try std.testing.expectEqual(@as(i16, 2), gob.images[1].width);
    try std.testing.expectEqual(@as(i16, 4), gob.images[1].height);
    try std.testing.expectEqual(@as(i16, -1), gob.images[1].hs_x);
    try std.testing.expectEqual(@as(i16, 0), gob.images[1].hs_y);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 7, 8, 9, 10, 11, 12, 13, 14 }, gob.images[1].data);
}

test "encode matches the offset-table layout write_gob produces" {
    const allocator = std.testing.allocator;
    const bytes = try buildGobBytes(allocator);
    defer allocator.free(bytes);

    // header: num_images(2) + offset table(2*4) = 10 bytes
    try std.testing.expectEqual(@as(u16, 2), std.mem.readInt(u16, bytes[0..2], .little));
    try std.testing.expectEqual(@as(u32, 10), std.mem.readInt(u32, bytes[2..6], .little));
    // image 0 header(8) + pixels(6) = 14 bytes -> image 1 at 10+14=24
    try std.testing.expectEqual(@as(u32, 24), std.mem.readInt(u32, bytes[6..10], .little));
}

test "blit-position math matches a real sprite's hotspot (rabbit.gob frame 0)" {
    // data/rabbit.gob frame 0: width=13 height=15 hs_x=-2 hs_y=-1 (read directly
    // out of the file with struct.unpack_from in Python to cross-check this).
    const pos = blitPosition(100, 50, -2, -1);
    try std.testing.expectEqual(BlitPosition{ .x = 102, .y = 51 }, pos);
}

test "blit-position math with a positive hotspot" {
    const pos = blitPosition(100, 50, 12, 20);
    try std.testing.expectEqual(BlitPosition{ .x = 88, .y = 30 }, pos);
}

test "decode rejects a truncated header" {
    const allocator = std.testing.allocator;
    var buf = [_]u8{ 1, 0, 0, 0 }; // claims 1 image but no offset entry follows
    try std.testing.expectError(DecodeError.Truncated, decode(allocator, &buf));
}
