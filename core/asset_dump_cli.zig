// Thin CLI decoder for the Godot asset pipeline (TASK-013): dumps .gob
// sprites and .pcx screens to raw palette-index bytes + a JSON manifest, so
// tools/*.py can do the PNG/atlas/compositing work without re-implementing
// gob.zig/pcx.zig's decode logic in Python. Not part of the simulation core
// (does argv/file I/O like jnbpack_cli.zig etc.), so it gets its own
// `zig build asset-dump` install step.
//
//   asset-dump gob <in.gob> <palette.pcx> <out_dir>
//       writes out_dir/palette.rgb (768 bytes, display-scaled 8-bit RGB,
//       i.e. the file's palette bytes with the low 2 bits cleared -- see
//       sdl/gfx.c set_palette's `<< 2` of the `>> 2`-loaded value),
//       out_dir/frame_NNNN.idx (raw width*height index bytes) per image, and
//       out_dir/manifest.json.
//
//   asset-dump pcx <in.pcx> <out_dir> <out_stem> <width> <height> <with_palette 0|1>
//       writes out_dir/<out_stem>.idx (raw width*height index bytes),
//       out_dir/<out_stem>.palette.rgb (768 bytes, only if with_palette=1),
//       and out_dir/<out_stem>.json.
const std = @import("std");
const gob = @import("gob.zig");
const pcx = @import("pcx.zig");
const asset_runtime = @import("asset_runtime.zig");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    const dir = std.Io.Dir.cwd();

    var it = try std.process.Args.Iterator.initAllocator(init.minimal.args, gpa);
    defer it.deinit();
    _ = it.next(); // argv[0]

    const mode = it.next() orelse usage();
    if (std.mem.eql(u8, mode, "gob")) {
        const gob_path = it.next() orelse usage();
        const palette_path = it.next() orelse usage();
        const out_dir = it.next() orelse usage();
        try dumpGob(gpa, io, dir, gob_path, palette_path, out_dir);
    } else if (std.mem.eql(u8, mode, "pcx")) {
        const pcx_path = it.next() orelse usage();
        const out_dir = it.next() orelse usage();
        const out_stem = it.next() orelse usage();
        const width_str = it.next() orelse usage();
        const height_str = it.next() orelse usage();
        const with_palette_str = it.next() orelse usage();
        const width = try std.fmt.parseInt(u32, width_str, 10);
        const height = try std.fmt.parseInt(u32, height_str, 10);
        const with_palette = !std.mem.eql(u8, with_palette_str, "0");
        try dumpPcx(gpa, io, dir, pcx_path, out_dir, out_stem, width, height, with_palette);
    } else {
        usage();
    }
}

fn usage() noreturn {
    std.debug.print(
        \\Usage:
        \\  asset-dump gob <in.gob> <palette.pcx> <out_dir>
        \\  asset-dump pcx <in.pcx> <out_dir> <out_stem> <width> <height> <with_palette 0|1>
        \\
    , .{});
    std.process.exit(1);
}

fn writeJson(io: std.Io, dir: std.Io.Dir, path: []const u8, json: []const u8) !void {
    try dir.writeFile(io, .{ .sub_path = path, .data = json });
}

fn dumpGob(
    gpa: std.mem.Allocator,
    io: std.Io,
    dir: std.Io.Dir,
    gob_path: []const u8,
    palette_path: []const u8,
    out_dir: []const u8,
) !void {
    const gob_bytes = try dir.readFileAlloc(io, gob_path, gpa, .unlimited);
    var g = try gob.decode(gpa, gob_bytes);
    defer g.deinit();

    const pal_bytes = try dir.readFileAlloc(io, palette_path, gpa, .unlimited);
    var decoded_pal = try pcx.decode(gpa, pal_bytes, @as(usize, 400) * 256, true);
    defer decoded_pal.deinit();
    const palette = asset_runtime.scaleDisplayPalette(decoded_pal.palette.?);

    const palette_path_out = try std.fmt.allocPrint(gpa, "{s}/palette.rgb", .{out_dir});
    try dir.writeFile(io, .{ .sub_path = palette_path_out, .data = &palette });

    var manifest: std.ArrayList(u8) = .empty;
    try manifest.print(gpa, "{{\n  \"num_images\": {d},\n  \"frames\": [\n", .{g.images.len});
    for (g.images, 0..) |img, i| {
        const frame_name = try std.fmt.allocPrint(gpa, "frame_{d:0>4}.idx", .{i});
        const frame_path = try std.fmt.allocPrint(gpa, "{s}/{s}", .{ out_dir, frame_name });
        try dir.writeFile(io, .{ .sub_path = frame_path, .data = img.data });

        try manifest.print(
            gpa,
            "    {{ \"index\": {d}, \"width\": {d}, \"height\": {d}, \"hotspot_x\": {d}, \"hotspot_y\": {d}, \"file\": \"{s}\" }}{s}\n",
            .{ i, img.width, img.height, img.hs_x, img.hs_y, frame_name, if (i + 1 < g.images.len) "," else "" },
        );
    }
    try manifest.print(gpa, "  ],\n  \"palette_file\": \"palette.rgb\"\n}}\n", .{});

    const manifest_path = try std.fmt.allocPrint(gpa, "{s}/manifest.json", .{out_dir});
    try writeJson(io, dir, manifest_path, manifest.items);
}

fn dumpPcx(
    gpa: std.mem.Allocator,
    io: std.Io,
    dir: std.Io.Dir,
    pcx_path: []const u8,
    out_dir: []const u8,
    out_stem: []const u8,
    width: u32,
    height: u32,
    with_palette: bool,
) !void {
    const pcx_bytes = try dir.readFileAlloc(io, pcx_path, gpa, .unlimited);
    var decoded = try pcx.decode(gpa, pcx_bytes, @as(usize, width) * height, with_palette);
    defer decoded.deinit();

    const idx_path = try std.fmt.allocPrint(gpa, "{s}/{s}.idx", .{ out_dir, out_stem });
    try dir.writeFile(io, .{ .sub_path = idx_path, .data = decoded.pixels });

    var has_palette = false;
    if (with_palette) {
        if (decoded.palette) |raw_pal| {
            const palette = asset_runtime.scaleDisplayPalette(raw_pal);
            const pal_path = try std.fmt.allocPrint(gpa, "{s}/{s}.palette.rgb", .{ out_dir, out_stem });
            try dir.writeFile(io, .{ .sub_path = pal_path, .data = &palette });
            has_palette = true;
        }
    }

    const json = try std.fmt.allocPrint(
        gpa,
        "{{\n  \"width\": {d},\n  \"height\": {d},\n  \"has_palette\": {}\n}}\n",
        .{ width, height, has_palette },
    );
    const json_path = try std.fmt.allocPrint(gpa, "{s}/{s}.json", .{ out_dir, out_stem });
    try writeJson(io, dir, json_path, json);
}
