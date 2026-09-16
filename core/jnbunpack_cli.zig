// Thin CLI wrapper around dat.unpack(), reproducing modify/jnbunpack.c's
// behavior (TASK-010.05). Usage: jnbunpack <datafile>
const std = @import("std");
const dat = @import("dat.zig");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    const dir = std.Io.Dir.cwd();

    var it = try std.process.Args.Iterator.initAllocator(init.minimal.args, gpa);
    defer it.deinit();
    _ = it.next(); // argv[0]

    const in_path = it.next() orelse {
        std.debug.print("dumbass, specify filename to unpack\n", .{});
        std.process.exit(1);
    };

    const buf = dir.readFileAlloc(io, in_path, gpa, .unlimited) catch |err| {
        std.debug.print("open datafile: {t}\n", .{err});
        std.process.exit(1);
    };

    const entries = try dat.unpack(gpa, buf);
    std.debug.print("{d} entries in datafile\n", .{entries.len});
    std.debug.print("Directory Listing:\n", .{});
    for (entries, 0..) |e, i| {
        const name = trimName(&e.name);
        std.debug.print("{d:0>2}:\t{s} ({d} bytes)\n", .{ i, name, e.data.len });
    }

    for (entries) |e| {
        const name = trimName(&e.name);
        std.debug.print("Extracting {s} ", .{name});
        try dir.writeFile(io, .{ .sub_path = name, .data = e.data });
        std.debug.print("OK\n", .{});
    }
}

// C: strncpy(filename, datafile[i].filename, 12) into a zeroed buffer — stop
// at the first NUL, matching the 12-byte name field's own null padding.
fn trimName(name: *const [12]u8) []const u8 {
    const nul = std.mem.indexOfScalar(u8, name, 0) orelse name.len;
    return name[0..nul];
}
