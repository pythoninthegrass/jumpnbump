// Runtime asset decoding for user-supplied .dat archives (TASK-016.01):
// pure buffer-in/buffer-out atlas-packing and level-layer-compositing logic,
// built on the Phase 2 codecs (core/gob.zig, core/pcx.zig) so a GDExtension
// consumer can turn a custom .dat's sprites/level art into Godot textures
// in-process, with no file writes and no editor re-import step.
//
// Ports tools/build_sprite_atlas.py's tile_grid()/build_atlas() and
// tools/build_level_layers.py's render_pair() from Python into Zig so the
// atlas/layer layout math has a single source of truth shared by the
// build-time pipeline and this runtime path, instead of two implementations
// that could silently drift apart.
const std = @import("std");
const gob = @import("gob.zig");
const pcx = @import("pcx.zig");

pub const palette_size = pcx.palette_size; // 768

// main.c's fixed screen resolution (sdl/gfx.c), matching
// tools/build_sprite_atlas.py's ATLAS_W/ATLAS_H and
// tools/build_level_layers.py's WIDTH/HEIGHT -- every custom .dat's
// level.pcx/mask.pcx/menu.pcx/menumask.pcx and every sprite atlas this
// module builds are packed into that same fixed frame, never a
// per-file-derived size.
pub const screen_w: u32 = 400;
pub const screen_h: u32 = 256;
pub const pixel_count: usize = @as(usize, screen_w) * screen_h;
pub const rgba_len: usize = pixel_count * 4;

pub const AtlasFrame = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    hotspot_x: i32,
    hotspot_y: i32,
};

pub const AssetError = error{
    TooManyFrames,
    BufferTooSmall,
} || gob.DecodeError || pcx.DecodeError;

// sdl/gfx.c set_palette: colors[i].r = palette[i*3+0] << 2 -- undoes
// pcx.zig's decode()'s `>> 2` VGA scaling back to a displayable 8-bit value.
// Canonical home for this so core/asset_dump_cli.zig and this module share
// one implementation instead of two copies.
pub fn scaleDisplayPalette(raw: [palette_size]u8) [palette_size]u8 {
    var out: [palette_size]u8 = undefined;
    for (&out, raw) |*o, r| o.* = r << 2;
    return out;
}

// Decodes a PCX file's embedded palette (menu.pcx, typically) at the fixed
// screen resolution and returns it display-scaled (scaleDisplayPalette()),
// ready to reuse across every gob in the same .dat via buildSpriteAtlas.
pub fn decodeDisplayPalette(allocator: std.mem.Allocator, pcx_bytes: []const u8) ![palette_size]u8 {
    var d = try pcx.decode(allocator, pcx_bytes, pixel_count, true);
    defer d.deinit();
    return scaleDisplayPalette(d.palette.?);
}

// Cheap query: how many frames a .gob file decodes to, without building an
// atlas -- lets a caller size out_frames before calling buildSpriteAtlas.
pub fn gobFrameCount(allocator: std.mem.Allocator, gob_bytes: []const u8) !usize {
    var g = try gob.decode(allocator, gob_bytes);
    defer g.deinit();
    return g.images.len;
}

// Mirrors tools/build_sprite_atlas.py's tile_grid()/build_atlas(): a uniform
// tile_w=max_width+2 x tile_h=max_height+2 grid packed row-major, including
// the preserved y_count=atlas_h/tile_w quirk (core/gobpack_cli.zig's
// doUnpack) so runtime atlases line up with the committed build-time ones.
// palette_rgb768 must already be display-scaled (scaleDisplayPalette()'s
// output) -- main.c loads menu.pcx once at startup and shares that single
// palette across rabbit/objects/numbers/font, so callers decode menu.pcx
// once and reuse its scaled palette for every gob in the same .dat.
//
// out_pixels must be exactly rgba_len bytes. out_frames must be at least
// gobFrameCount(gob_bytes) long, or this returns AssetError.BufferTooSmall.
// Returns the number of frames actually written.
pub fn buildSpriteAtlas(
    allocator: std.mem.Allocator,
    gob_bytes: []const u8,
    palette_rgb768: [palette_size]u8,
    out_frames: []AtlasFrame,
    out_pixels: []u8,
) !usize {
    if (out_pixels.len != rgba_len) return AssetError.BufferTooSmall;

    var g = try gob.decode(allocator, gob_bytes);
    defer g.deinit();

    if (out_frames.len < g.images.len) return AssetError.BufferTooSmall;
    if (g.images.len == 0) {
        @memset(out_pixels, 0);
        return 0;
    }

    var max_w: i32 = 0;
    var max_h: i32 = 0;
    for (g.images) |img| {
        max_w = @max(max_w, @as(i32, img.width));
        max_h = @max(max_h, @as(i32, img.height));
    }
    if (max_w < 0 or max_h < 0) return AssetError.TooManyFrames;

    const tile_w: u32 = @intCast(max_w + 2);
    const tile_h: u32 = @intCast(max_h + 2);
    if (tile_w == 0 or tile_w > screen_w) return AssetError.TooManyFrames;
    const x_count = screen_w / tile_w;
    const y_count = screen_h / tile_w; // preserved quirk: not tile_h
    if (x_count == 0 or g.images.len > x_count * y_count) return AssetError.TooManyFrames;

    @memset(out_pixels, 0);

    for (g.images, 0..) |img, i| {
        if (img.width < 0 or img.height < 0) return AssetError.TooManyFrames;
        const idx: u32 = @intCast(i);
        const xi = idx % x_count;
        const yi = idx / x_count;
        const dst_x = xi * tile_w;
        const dst_y = yi * tile_h;
        const w: u32 = @intCast(img.width);
        const h: u32 = @intCast(img.height);

        for (0..h) |row| {
            for (0..w) |col| {
                const palette_index = img.data[row * w + col];
                if (palette_index == 0) continue; // color 0 is the transparent key
                const dst_off = ((dst_y + row) * screen_w + (dst_x + @as(u32, @intCast(col)))) * 4;
                const p: usize = @as(usize, palette_index) * 3;
                out_pixels[dst_off + 0] = palette_rgb768[p + 0];
                out_pixels[dst_off + 1] = palette_rgb768[p + 1];
                out_pixels[dst_off + 2] = palette_rgb768[p + 2];
                out_pixels[dst_off + 3] = 255;
            }
        }

        out_frames[i] = .{
            .x = @intCast(dst_x),
            .y = @intCast(dst_y),
            .width = img.width,
            .height = img.height,
            .hotspot_x = img.hs_x,
            .hotspot_y = img.hs_y,
        };
    }

    return g.images.len;
}

// Mirrors tools/build_level_layers.py's render_pair(): decodes a background
// PCX (its own embedded, display-scaled palette) plus a boolean stencil mask
// PCX (no palette) at the fixed screen_w x screen_h resolution, producing an
// opaque background RGBA8 buffer and an alpha-keyed foreground RGBA8 buffer
// (identical pixels, alpha=0 wherever the mask is 0) that must draw on top
// of sprites -- see that script's module docstring for the put_pob
// occlusion semantics this reproduces. Both output buffers must be exactly
// rgba_len bytes.
pub fn buildLevelLayers(
    allocator: std.mem.Allocator,
    pcx_bytes: []const u8,
    mask_bytes: []const u8,
    out_background_rgba: []u8,
    out_foreground_rgba: []u8,
) !void {
    if (out_background_rgba.len != rgba_len or out_foreground_rgba.len != rgba_len) {
        return AssetError.BufferTooSmall;
    }

    var bg = try pcx.decode(allocator, pcx_bytes, pixel_count, true);
    defer bg.deinit();
    var mask = try pcx.decode(allocator, mask_bytes, pixel_count, false);
    defer mask.deinit();

    const palette = scaleDisplayPalette(bg.palette.?);

    for (0..pixel_count) |i| {
        const idx = bg.pixels[i];
        const p: usize = @as(usize, idx) * 3;
        const off = i * 4;
        out_background_rgba[off + 0] = palette[p + 0];
        out_background_rgba[off + 1] = palette[p + 1];
        out_background_rgba[off + 2] = palette[p + 2];
        out_background_rgba[off + 3] = 255;

        out_foreground_rgba[off + 0] = palette[p + 0];
        out_foreground_rgba[off + 1] = palette[p + 1];
        out_foreground_rgba[off + 2] = palette[p + 2];
        out_foreground_rgba[off + 3] = if (mask.pixels[i] != 0) 255 else 0;
    }
}

fn buildGobBytes(allocator: std.mem.Allocator, images: []const gob.Image) ![]u8 {
    return gob.encode(allocator, images);
}

test "buildSpriteAtlas packs frames into the tile grid and honors the transparent key" {
    const allocator = std.testing.allocator;
    const img0_data = [_]u8{ 0, 1, 2, 3 }; // 2x2, top-left transparent
    const images = [_]gob.Image{
        .{ .width = 2, .height = 2, .hs_x = 1, .hs_y = 1, .data = &img0_data },
    };
    const bytes = try buildGobBytes(allocator, &images);
    defer allocator.free(bytes);

    var palette: [palette_size]u8 = [_]u8{0} ** palette_size;
    palette[1 * 3 + 0] = 10;
    palette[1 * 3 + 1] = 20;
    palette[1 * 3 + 2] = 30;
    palette[2 * 3 + 0] = 40;
    palette[3 * 3 + 0] = 50;

    var frames: [1]AtlasFrame = undefined;
    var pixels: [rgba_len]u8 = undefined;
    const count = try buildSpriteAtlas(allocator, bytes, palette, &frames, &pixels);

    try std.testing.expectEqual(@as(usize, 1), count);
    try std.testing.expectEqual(@as(i32, 0), frames[0].x);
    try std.testing.expectEqual(@as(i32, 0), frames[0].y);
    try std.testing.expectEqual(@as(i32, 2), frames[0].width);
    try std.testing.expectEqual(@as(i32, 2), frames[0].height);
    try std.testing.expectEqual(@as(i32, 1), frames[0].hotspot_x);
    try std.testing.expectEqual(@as(i32, 1), frames[0].hotspot_y);

    // Pixel (0,0) had palette index 0 -> transparent (alpha 0, RGB left zeroed).
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 0 }, pixels[0..4]);
    // Pixel (1,0) had palette index 1 -> opaque, palette[1].
    const off10 = (0 * screen_w + 1) * 4;
    try std.testing.expectEqualSlices(u8, &[_]u8{ 10, 20, 30, 255 }, pixels[off10 .. off10 + 4]);
}

test "buildSpriteAtlas reports BufferTooSmall when out_frames is undersized" {
    const allocator = std.testing.allocator;
    const img0_data = [_]u8{ 1, 1 };
    const images = [_]gob.Image{
        .{ .width = 2, .height = 1, .hs_x = 0, .hs_y = 0, .data = &img0_data },
        .{ .width = 2, .height = 1, .hs_x = 0, .hs_y = 0, .data = &img0_data },
    };
    const bytes = try buildGobBytes(allocator, &images);
    defer allocator.free(bytes);

    const palette: [palette_size]u8 = [_]u8{0} ** palette_size;
    var frames: [1]AtlasFrame = undefined;
    var pixels: [rgba_len]u8 = undefined;
    try std.testing.expectError(AssetError.BufferTooSmall, buildSpriteAtlas(allocator, bytes, palette, &frames, &pixels));
}

test "buildSpriteAtlas reports BufferTooSmall on a wrong-sized pixel buffer" {
    const allocator = std.testing.allocator;
    const img0_data = [_]u8{1};
    const images = [_]gob.Image{
        .{ .width = 1, .height = 1, .hs_x = 0, .hs_y = 0, .data = &img0_data },
    };
    const bytes = try buildGobBytes(allocator, &images);
    defer allocator.free(bytes);

    const palette: [palette_size]u8 = [_]u8{0} ** palette_size;
    var frames: [1]AtlasFrame = undefined;
    var pixels: [rgba_len - 1]u8 = undefined;
    try std.testing.expectError(AssetError.BufferTooSmall, buildSpriteAtlas(allocator, bytes, palette, &frames, &pixels));
}

test "gobFrameCount matches the number of frames buildSpriteAtlas returns" {
    const allocator = std.testing.allocator;
    const img0_data = [_]u8{1};
    const img1_data = [_]u8{1};
    const images = [_]gob.Image{
        .{ .width = 1, .height = 1, .hs_x = 0, .hs_y = 0, .data = &img0_data },
        .{ .width = 1, .height = 1, .hs_x = 0, .hs_y = 0, .data = &img1_data },
    };
    const bytes = try buildGobBytes(allocator, &images);
    defer allocator.free(bytes);

    try std.testing.expectEqual(@as(usize, 2), try gobFrameCount(allocator, bytes));
}

fn buildPcxBytes(allocator: std.mem.Allocator, pixels: []const u8, width: u16, height: u16, palette: ?[palette_size]u8) ![]u8 {
    return pcx.encode(allocator, pixels, width, height, palette);
}

test "buildLevelLayers composites an opaque background and an alpha-masked foreground" {
    const allocator = std.testing.allocator;

    var pixels: [pixel_count]u8 = [_]u8{0} ** pixel_count;
    pixels[0] = 5; // pixel (0,0) uses palette index 5
    var raw_palette: [palette_size]u8 = [_]u8{0} ** palette_size;
    raw_palette[5 * 3 + 0] = 60; // stored pre-scaled (as write_pcx/read_pcx round-trip it)
    raw_palette[5 * 3 + 1] = 61;
    raw_palette[5 * 3 + 2] = 62;

    const bg_bytes = try buildPcxBytes(allocator, &pixels, screen_w, screen_h, raw_palette);
    defer allocator.free(bg_bytes);

    var mask_pixels: [pixel_count]u8 = [_]u8{0} ** pixel_count;
    mask_pixels[0] = 1; // pixel (0,0) is masked (occupied)
    const mask_bytes = try buildPcxBytes(allocator, &mask_pixels, screen_w, screen_h, null);
    defer allocator.free(mask_bytes);

    var background: [rgba_len]u8 = undefined;
    var foreground: [rgba_len]u8 = undefined;
    try buildLevelLayers(allocator, bg_bytes, mask_bytes, &background, &foreground);

    // read_pcx right-shifts the embedded palette by 2, then scaleDisplayPalette
    // shifts back left by 2 -- round-trips to the original value with its low
    // 2 bits cleared (60 -> 15 -> 60, since 60 is already a multiple of 4).
    try std.testing.expectEqualSlices(u8, &[_]u8{ 60, 60, 60, 255 }, background[0..4]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 60, 60, 60, 255 }, foreground[0..4]);

    // pixel (1,0): palette index 0, unmasked -> background opaque, foreground transparent.
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 255 }, background[4..8]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 0 }, foreground[4..8]);
}

test "decodeDisplayPalette round-trips a multiple-of-4 palette byte exactly" {
    const allocator = std.testing.allocator;
    var pixels: [pixel_count]u8 = [_]u8{0} ** pixel_count;
    var raw_palette: [palette_size]u8 = [_]u8{0} ** palette_size;
    // >> 2 then << 2 is lossless only when the low 2 bits are already zero
    // (pcx.zig's own "encode/decode round-trip" test picks values the same
    // way) -- 200 is a multiple of 4.
    raw_palette[9 * 3 + 0] = 200;
    const bytes = try buildPcxBytes(allocator, &pixels, screen_w, screen_h, raw_palette);
    defer allocator.free(bytes);

    const palette = try decodeDisplayPalette(allocator, bytes);
    try std.testing.expectEqual(raw_palette, palette);
}

test "buildLevelLayers reports BufferTooSmall on a wrong-sized output buffer" {
    const allocator = std.testing.allocator;
    var pixels: [pixel_count]u8 = [_]u8{0} ** pixel_count;
    const bg_bytes = try buildPcxBytes(allocator, &pixels, screen_w, screen_h, [_]u8{0} ** palette_size);
    defer allocator.free(bg_bytes);
    const mask_bytes = try buildPcxBytes(allocator, &pixels, screen_w, screen_h, null);
    defer allocator.free(mask_bytes);

    var background: [rgba_len - 1]u8 = undefined;
    var foreground: [rgba_len]u8 = undefined;
    try std.testing.expectError(AssetError.BufferTooSmall, buildLevelLayers(allocator, bg_bytes, mask_bytes, &background, &foreground));
}
