// Port of the .dat archive format (main.c dat_open/dat_filelen, modify/jnbpack.c,
// modify/jnbunpack.c) per docs/porting-playbook.md TASK-010.01.
//
// Layout: u32 entry count, then entries of {char[12] name, u32 offset, u32 size}
// (little-endian, matching the original byte-by-byte manual shifts), followed by
// concatenated payloads at the offsets given.
const std = @import("std");
const bz2 = @cImport({
    @cInclude("bzlib.h");
});

pub const entry_size = 20; // 12 (name) + 4 (offset) + 4 (size)

pub const Entry = struct {
    offset: u32,
    size: u32,
};

pub const InputFile = struct {
    name: []const u8,
    data: []const u8,
};

pub const PackError = error{NameTooLong};
pub const UnpackError = error{Truncated};

// strnicmp(name, file_name, strlen(file_name)) == 0 against a 12-byte name field:
// a case-insensitive PREFIX match, not equality — "menu" matches "menumask.pcx".
// This quirk is load-bearing: menu.c relies on it. C reads out of the 12-byte
// field for a query longer than 12 chars (UB in the original); we treat that as
// simply "cannot match" rather than replicate undefined behavior.
fn prefixMatch(name: []const u8, file_name: []const u8) bool {
    if (file_name.len > name.len) return false;
    for (file_name, 0..) |ch, i| {
        if (std.ascii.toLower(ch) != std.ascii.toLower(name[i])) return false;
    }
    return true;
}

// Find the first entry (in file order) whose name prefix-matches file_name.
pub fn find(buf: []const u8, file_name: []const u8) ?Entry {
    if (buf.len < 4) return null;
    const num = std.mem.readInt(u32, buf[0..4], .little);
    var ptr: usize = 4;
    var i: u32 = 0;
    while (i < num) : (i += 1) {
        if (ptr + entry_size > buf.len) return null;
        const name = buf[ptr .. ptr + 12];
        const ofs = std.mem.readInt(u32, buf[ptr + 12 ..][0..4], .little);
        const size = std.mem.readInt(u32, buf[ptr + 16 ..][0..4], .little);
        if (prefixMatch(name, file_name)) return .{ .offset = ofs, .size = size };
        ptr += entry_size;
    }
    return null;
}

// dat_open: return the payload slice for file_name, or null if not found or the
// stored offset falls outside the buffer.
pub fn open(buf: []const u8, file_name: []const u8) ?[]const u8 {
    const e = find(buf, file_name) orelse return null;
    if (e.offset > buf.len) return null;
    return buf[e.offset..];
}

// dat_filelen: return the stored size for file_name, or null if not found.
pub fn filelen(buf: []const u8, file_name: []const u8) ?u32 {
    const e = find(buf, file_name) orelse return null;
    return e.size;
}

// jnbpack: pack files (in the given order) into a .dat archive, byte-identical
// to modify/jnbpack.c's output. Names longer than 12 bytes are rejected (the C
// tool instead aborts the whole process with an error message).
pub fn pack(allocator: std.mem.Allocator, files: []const InputFile) ![]u8 {
    for (files) |f| {
        if (f.name.len > 12) return PackError.NameTooLong;
    }

    const dir_size: usize = 4 + files.len * entry_size;
    var total: usize = dir_size;
    for (files) |f| total += f.data.len;

    const out = try allocator.alloc(u8, total);
    errdefer allocator.free(out);

    std.mem.writeInt(u32, out[0..4], @intCast(files.len), .little);

    var dir_ptr: usize = 4;
    var data_ptr: usize = dir_size;
    for (files) |f| {
        var namebuf = [_]u8{0} ** 12;
        @memcpy(namebuf[0..f.name.len], f.name);
        @memcpy(out[dir_ptr .. dir_ptr + 12], &namebuf);
        std.mem.writeInt(u32, out[dir_ptr + 12 ..][0..4], @intCast(data_ptr), .little);
        std.mem.writeInt(u32, out[dir_ptr + 16 ..][0..4], @intCast(f.data.len), .little);
        dir_ptr += entry_size;

        @memcpy(out[data_ptr .. data_ptr + f.data.len], f.data);
        data_ptr += f.data.len;
    }

    return out;
}

pub const UnpackedFile = struct {
    name: [12]u8,
    data: []const u8,
};

// jnbunpack: list every entry, with its payload sliced directly out of buf (no
// copy — caller controls buf's lifetime), in file order.
pub fn unpack(allocator: std.mem.Allocator, buf: []const u8) ![]UnpackedFile {
    if (buf.len < 4) return UnpackError.Truncated;
    const num = std.mem.readInt(u32, buf[0..4], .little);

    var list = try std.ArrayList(UnpackedFile).initCapacity(allocator, num);
    errdefer list.deinit(allocator);

    var ptr: usize = 4;
    var i: u32 = 0;
    while (i < num) : (i += 1) {
        if (ptr + entry_size > buf.len) return UnpackError.Truncated;
        var name: [12]u8 = undefined;
        @memcpy(&name, buf[ptr .. ptr + 12]);
        const ofs = std.mem.readInt(u32, buf[ptr + 12 ..][0..4], .little);
        const size = std.mem.readInt(u32, buf[ptr + 16 ..][0..4], .little);
        ptr += entry_size;

        if (ofs > buf.len or ofs + size > buf.len) return UnpackError.Truncated;
        try list.append(allocator, .{ .name = name, .data = buf[ofs .. ofs + size] });
    }

    return list.toOwnedSlice(allocator);
}

// preread_datafile: load path (resolved against dir), trying path++".bz2" then
// path++".gz" then path itself, transparently decompressing the outer file
// (matches main.c's BZLIB_SUPPORT/ZLIB_SUPPORT probing order). Returns an
// allocator-owned buffer. Pass std.Io.Dir.cwd() for normal use; tests pass a
// tmpDir so fixtures don't touch the real cwd.
pub fn loadDatafile(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, path: []const u8) ![]u8 {
    if (try tryLoadBz2(allocator, io, dir, path)) |buf| return buf;
    if (try tryLoadGz(allocator, io, dir, path)) |buf| return buf;
    return dir.readFileAlloc(io, path, allocator, .unlimited);
}

fn tryLoadBz2(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, path: []const u8) !?[]u8 {
    const bz2_path = try std.fmt.allocPrint(allocator, "{s}.bz2", .{path});
    defer allocator.free(bz2_path);

    const compressed = dir.readFileAlloc(io, bz2_path, allocator, .unlimited) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer allocator.free(compressed);

    return try decompressBz2(allocator, compressed);
}

fn decompressBz2(allocator: std.mem.Allocator, compressed: []const u8) ![]u8 {
    var cap: usize = compressed.len * 4 + 4096;
    while (true) {
        const dest = try allocator.alloc(u8, cap);
        var dest_len: c_uint = @intCast(cap);
        const rc = bz2.BZ2_bzBuffToBuffDecompress(
            dest.ptr,
            &dest_len,
            @constCast(compressed.ptr),
            @intCast(compressed.len),
            0,
            0,
        );
        if (rc == bz2.BZ_OK) {
            return allocator.realloc(dest, dest_len);
        }
        allocator.free(dest);
        if (rc == bz2.BZ_OUTBUFF_FULL) {
            cap *= 2;
            continue;
        }
        return error.Bzip2DecompressFailed;
    }
}

fn tryLoadGz(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, path: []const u8) !?[]u8 {
    const gz_path = try std.fmt.allocPrint(allocator, "{s}.gz", .{path});
    defer allocator.free(gz_path);

    const compressed = dir.readFileAlloc(io, gz_path, allocator, .unlimited) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer allocator.free(compressed);

    return try decompressGz(allocator, compressed);
}

fn decompressGz(allocator: std.mem.Allocator, compressed: []const u8) ![]u8 {
    var in: std.Io.Reader = .fixed(compressed);
    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();

    var decompress: std.compress.flate.Decompress = .init(&in, .gzip, &.{});
    _ = try decompress.reader.streamRemaining(&aw.writer);
    return aw.toOwnedSlice();
}

test "find: exact match" {
    var buf: [4 + entry_size]u8 = undefined;
    std.mem.writeInt(u32, buf[0..4], 1, .little);
    @memcpy(buf[4..16], "rabbit.gob\x00\x00");
    std.mem.writeInt(u32, buf[16..20], 24, .little);
    std.mem.writeInt(u32, buf[20..24], 100, .little);

    const e = find(&buf, "rabbit.gob").?;
    try std.testing.expectEqual(@as(u32, 24), e.offset);
    try std.testing.expectEqual(@as(u32, 100), e.size);
}

test "find: prefix-match quirk (menu matches menumask.pcx)" {
    var buf: [4 + entry_size]u8 = undefined;
    std.mem.writeInt(u32, buf[0..4], 1, .little);
    @memcpy(buf[4..16], "menumask.pcx");
    std.mem.writeInt(u32, buf[16..20], 4 + entry_size, .little);
    std.mem.writeInt(u32, buf[20..24], 7, .little);

    const e = find(&buf, "menu").?;
    try std.testing.expectEqual(@as(u32, 4 + entry_size), e.offset);
}

test "find: case-insensitive" {
    var buf: [4 + entry_size]u8 = undefined;
    std.mem.writeInt(u32, buf[0..4], 1, .little);
    @memcpy(buf[4..16], "RaBBit.gob\x00\x00");
    std.mem.writeInt(u32, buf[16..20], 0, .little);
    std.mem.writeInt(u32, buf[20..24], 0, .little);

    try std.testing.expect(find(&buf, "rabbit.gob") != null);
}

test "find: no match returns null" {
    var buf: [4 + entry_size]u8 = undefined;
    std.mem.writeInt(u32, buf[0..4], 1, .little);
    @memcpy(buf[4..16], "rabbit.gob\x00\x00");
    std.mem.writeInt(u32, buf[16..20], 0, .little);
    std.mem.writeInt(u32, buf[20..24], 0, .little);

    try std.testing.expect(find(&buf, "objects.gob") == null);
}

test "open/filelen return payload and size" {
    const payload = "hello";
    var buf: [4 + entry_size + payload.len]u8 = undefined;
    std.mem.writeInt(u32, buf[0..4], 1, .little);
    @memcpy(buf[4..16], "f.txt\x00\x00\x00\x00\x00\x00\x00");
    std.mem.writeInt(u32, buf[16..20], 4 + entry_size, .little);
    std.mem.writeInt(u32, buf[20..24], payload.len, .little);
    @memcpy(buf[4 + entry_size ..], payload);

    try std.testing.expectEqualSlices(u8, payload, open(&buf, "f.txt").?);
    try std.testing.expectEqual(@as(u32, payload.len), filelen(&buf, "f.txt").?);
}

test "pack/unpack round-trip is byte-identical to a hand-built archive" {
    const allocator = std.testing.allocator;
    const files = [_]InputFile{
        .{ .name = "a.txt", .data = "hello" },
        .{ .name = "bbbbbbbbbbbb", .data = "world!!" },
    };
    const packed_buf = try pack(allocator, &files);
    defer allocator.free(packed_buf);

    // Hand-built expected layout: 4 + 2*20 = 44 byte directory.
    try std.testing.expectEqual(@as(usize, 4 + 2 * entry_size + 5 + 7), packed_buf.len);
    try std.testing.expectEqualSlices(u8, "hello", open(packed_buf, "a.txt").?[0..filelen(packed_buf, "a.txt").?]);
    try std.testing.expectEqualSlices(u8, "world!!", open(packed_buf, "bbbbbbbbbbbb").?[0..filelen(packed_buf, "bbbbbbbbbbbb").?]);

    const unpacked = try unpack(allocator, packed_buf);
    defer allocator.free(unpacked);
    try std.testing.expectEqual(@as(usize, 2), unpacked.len);
    try std.testing.expectEqualSlices(u8, "hello", unpacked[0].data);
    try std.testing.expectEqualSlices(u8, "world!!", unpacked[1].data);
}

test "pack rejects names longer than 12 bytes" {
    const allocator = std.testing.allocator;
    const files = [_]InputFile{.{ .name = "way-too-long-a-filename.txt", .data = "x" }};
    try std.testing.expectError(PackError.NameTooLong, pack(allocator, &files));
}

test "unpack rejects a truncated header" {
    const allocator = std.testing.allocator;
    var buf: [4 + entry_size]u8 = undefined;
    std.mem.writeInt(u32, buf[0..4], 2, .little); // claims 2 entries but body has room for none
    try std.testing.expectError(UnpackError.Truncated, unpack(allocator, &buf));
}

test "gzip decompression round-trips" {
    const allocator = std.testing.allocator;
    // "gzip non compressed block" fixture from std.compress.flate.Decompress's
    // own test suite — a minimal valid gzip stream, avoids depending on the
    // system gzip binary.
    const compressed = [_]u8{
        0x1f,        0x8b,        0x08, 0x00,        0x00, 0x00, 0x00, 0x00, 0x00, 0x03,
        0b0000_0001, 0b0000_1100, 0x00, 0b1111_0011, 0xff, 'H',  'e',  'l',  'l',  'o',
        ' ',         'w',         'o',  'r',         'l',  'd',  0x0a, 0xd5, 0xe0, 0x39,
        0xb7,        0x0c,        0x00, 0x00,        0x00,
    };
    const out = try decompressGz(allocator, &compressed);
    defer allocator.free(out);
    try std.testing.expectEqualStrings("Hello world\n", out);
}

test "loadDatafile: plain file, no compressed sibling" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "plain.dat", .data = "plain contents" });

    const out = try loadDatafile(allocator, io, tmp.dir, "plain.dat");
    defer allocator.free(out);
    try std.testing.expectEqualStrings("plain contents", out);
}

test "loadDatafile: prefers a .bz2 sibling over the plain file" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "compressed.dat", .data = "stale plain copy" });

    const original = "the real bz2 payload" ** 3;
    var dest_len: c_uint = original.len * 2 + 600;
    const dest = try allocator.alloc(u8, dest_len);
    defer allocator.free(dest);
    const rc = bz2.BZ2_bzBuffToBuffCompress(dest.ptr, &dest_len, @constCast(original.ptr), @intCast(original.len), 9, 0, 0);
    try std.testing.expectEqual(bz2.BZ_OK, rc);
    try tmp.dir.writeFile(io, .{ .sub_path = "compressed.dat.bz2", .data = dest[0..dest_len] });

    const out = try loadDatafile(allocator, io, tmp.dir, "compressed.dat");
    defer allocator.free(out);
    try std.testing.expectEqualStrings(original, out);
}

test "bzip2 decompression round-trips" {
    const allocator = std.testing.allocator;
    const original = "Hello world, compressed with bzip2!" ** 4;

    var dest_len: c_uint = original.len * 2 + 600;
    const dest = try allocator.alloc(u8, dest_len);
    defer allocator.free(dest);
    const rc = bz2.BZ2_bzBuffToBuffCompress(dest.ptr, &dest_len, @constCast(original.ptr), @intCast(original.len), 9, 0, 0);
    try std.testing.expectEqual(bz2.BZ_OK, rc);

    const out = try decompressBz2(allocator, dest[0..dest_len]);
    defer allocator.free(out);
    try std.testing.expectEqualStrings(original, out);
}
