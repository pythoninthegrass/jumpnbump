// Thin CLI wrapper around dat/gob/pcx codecs, reproducing modify/gobpack.c's
// behavior (TASK-010.05) — including its atlas layout for the pack/unpack
// direction, and the y_count = 256 / width bug (should be / height; the
// original tool has always used the tile's width for both axes).
//
//   gobpack <name>              pack <name>.pcx + <name>.txt -> <name>.gob
//   gobpack -u <name> [pal.pcx] unpack <name>.gob -> <name>.pcx + <name>.txt
const std = @import("std");
const dat = @import("dat.zig");
const gob = @import("gob.zig");
const pcx = @import("pcx.zig");

const atlas_w = 400;
const atlas_h = 256;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    const dir = std.Io.Dir.cwd();

    var it = try std.process.Args.Iterator.initAllocator(init.minimal.args, gpa);
    defer it.deinit();
    _ = it.next(); // argv[0]

    var args: std.ArrayList([]const u8) = .empty;
    while (it.next()) |a| try args.append(gpa, try gpa.dupe(u8, a));

    var unpack_mode = false;
    var rest = args.items;
    if (rest.len >= 1 and rest[0].len >= 2 and rest[0][0] == '-' and rest[0][1] == 'u') {
        unpack_mode = true;
        rest = rest[1..];
    }
    if (rest.len == 0) {
        std.debug.print("Usage: gobpack [-u] <file> [palette.pcx]\n\t-u to unpack the gob\n", .{});
        std.process.exit(1);
    }

    if (unpack_mode) {
        try doUnpack(gpa, io, dir, rest[0], if (rest.len > 1) rest[1] else null);
    } else {
        try doPack(gpa, io, dir, rest[0]);
    }
}

fn doUnpack(gpa: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, name: []const u8, palette_file: ?[]const u8) !void {
    var palette: ?[pcx.palette_size]u8 = null;
    if (palette_file) |pf| {
        if (dir.readFileAlloc(io, pf, gpa, .unlimited) catch null) |pal_bytes| {
            // C: fseek(f, -769, SEEK_END); fgetc marker; if 0x0c, read the
            // following raw 768 bytes as-is (no VGA >>2 scaling here).
            if (pal_bytes.len >= 769 and pal_bytes[pal_bytes.len - 769] == 0x0c) {
                var pal: [pcx.palette_size]u8 = undefined;
                @memcpy(&pal, pal_bytes[pal_bytes.len - 768 ..]);
                palette = pal;
            }
        }
    }

    const gob_path = try std.fmt.allocPrint(gpa, "{s}.gob", .{name});
    const gob_bytes = try dir.readFileAlloc(io, gob_path, gpa, .unlimited);
    var g = try gob.decode(gpa, gob_bytes);

    var max_w: i32 = 0;
    var max_h: i32 = 0;
    for (g.images) |img| {
        if (img.width > max_w) max_w = img.width;
        if (img.height > max_h) max_h = img.height;
    }
    const tile_w: usize = @intCast(max_w + 2);
    const tile_h: usize = @intCast(max_h + 2);

    const data = try gpa.alloc(u8, atlas_w * atlas_h);
    @memset(data, 0);

    const x_count = atlas_w / tile_w;
    const y_count = atlas_h / tile_w; // preserved bug: divides by tile_w, not tile_h

    var txt: std.ArrayList(u8) = .empty;
    try txt.print(gpa, "num_images: {d}\n\n", .{g.images.len});

    var yi: usize = 0;
    while (yi < y_count) : (yi += 1) {
        var xi: usize = 0;
        while (xi < x_count) : (xi += 1) {
            const i = yi * x_count + xi;
            if (i >= g.images.len) continue;
            const img = g.images[i];
            const iw: usize = @intCast(img.width);
            const ih: usize = @intCast(img.height);
            const dst_x = xi * tile_w;
            const dst_y = yi * tile_h;
            var row: usize = 0;
            while (row < ih) : (row += 1) {
                const dst_off = (dst_y + row) * atlas_w + dst_x;
                const src_off = row * iw;
                @memcpy(data[dst_off .. dst_off + iw], img.data[src_off .. src_off + iw]);
            }

            try txt.print(gpa, "image: {d}\n", .{i + 1});
            try txt.print(gpa, "x: {d}\n", .{dst_x});
            try txt.print(gpa, "y: {d}\n", .{dst_y});
            try txt.print(gpa, "width: {d}\n", .{img.width});
            try txt.print(gpa, "height: {d}\n", .{img.height});
            try txt.print(gpa, "hotspot_x: {d}\n", .{img.hs_x});
            try txt.print(gpa, "hotspot_y: {d}\n\n", .{img.hs_y});
        }
    }

    const pcx_bytes = try pcx.encode(gpa, data, atlas_w, atlas_h, palette);
    const pcx_path = try std.fmt.allocPrint(gpa, "{s}.pcx", .{name});
    try dir.writeFile(io, .{ .sub_path = pcx_path, .data = pcx_bytes });

    const txt_path = try std.fmt.allocPrint(gpa, "{s}.txt", .{name});
    try dir.writeFile(io, .{ .sub_path = txt_path, .data = txt.items });

    std.debug.print("unpacked {s}\n", .{name});
    g.deinit();
}

const FrameRecord = struct {
    x: usize = 0,
    y: usize = 0,
    width: i16 = 0,
    height: i16 = 0,
    hs_x: i16 = 0,
    hs_y: i16 = 0,
};

fn doPack(gpa: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, name: []const u8) !void {
    const pcx_path = try std.fmt.allocPrint(gpa, "{s}.pcx", .{name});
    const pcx_bytes = try dir.readFileAlloc(io, pcx_path, gpa, .unlimited);
    var decoded = try pcx.decode(gpa, pcx_bytes, atlas_w * atlas_h, false);
    const atlas = decoded.pixels;

    const txt_path = try std.fmt.allocPrint(gpa, "{s}.txt", .{name});
    const txt_bytes = try dir.readFileAlloc(io, txt_path, gpa, .unlimited);

    var num_images: usize = 0;
    var records: []FrameRecord = &.{};
    var cur: usize = 0;

    var lines = std.mem.tokenizeAny(u8, txt_bytes, " \t\r\n");
    while (lines.next()) |key| {
        const value_tok = lines.next() orelse break;
        const value = try std.fmt.parseInt(i64, value_tok, 10);

        if (std.mem.eql(u8, key, "num_images:")) {
            num_images = @intCast(value);
            records = try gpa.alloc(FrameRecord, num_images);
            for (records) |*r| r.* = .{};
        } else if (std.mem.eql(u8, key, "image:")) {
            cur = @intCast(value - 1);
        } else if (std.mem.eql(u8, key, "x:")) {
            records[cur].x = @intCast(value);
        } else if (std.mem.eql(u8, key, "y:")) {
            records[cur].y = @intCast(value);
        } else if (std.mem.eql(u8, key, "width:")) {
            records[cur].width = @intCast(value);
        } else if (std.mem.eql(u8, key, "height:")) {
            records[cur].height = @intCast(value);
        } else if (std.mem.eql(u8, key, "hotspot_x:")) {
            records[cur].hs_x = @intCast(value);
        } else if (std.mem.eql(u8, key, "hotspot_y:")) {
            records[cur].hs_y = @intCast(value);
        }
    }

    var images = try gpa.alloc(gob.Image, num_images);
    for (records, 0..) |r, i| {
        const iw: usize = @intCast(r.width);
        const ih: usize = @intCast(r.height);
        const pixels = try gpa.alloc(u8, iw * ih);
        var row: usize = 0;
        while (row < ih) : (row += 1) {
            const src_off = (r.y + row) * atlas_w + r.x;
            @memcpy(pixels[row * iw .. row * iw + iw], atlas[src_off .. src_off + iw]);
        }
        images[i] = .{ .width = r.width, .height = r.height, .hs_x = r.hs_x, .hs_y = r.hs_y, .data = pixels };
    }

    const gob_bytes = try gob.encode(gpa, images);
    const gob_path = try std.fmt.allocPrint(gpa, "{s}.gob", .{name});
    try dir.writeFile(io, .{ .sub_path = gob_path, .data = gob_bytes });

    std.debug.print("{s}.gob build\n", .{name});
    decoded.deinit();
}
