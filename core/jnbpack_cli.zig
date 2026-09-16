// Thin CLI wrapper around dat.pack(), byte-identical to modify/jnbpack.c's
// output (TASK-010.05). Usage: jnbpack -o <outfile> <file>...
const std = @import("std");
const dat = @import("dat.zig");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    const dir = std.Io.Dir.cwd();

    var it = try std.process.Args.Iterator.initAllocator(init.minimal.args, gpa);
    defer it.deinit();
    _ = it.next(); // argv[0]

    var out_path: ?[]const u8 = null;
    var names: std.ArrayList([]const u8) = .empty;

    while (it.next()) |arg| {
        if (std.mem.eql(u8, arg, "-o")) {
            out_path = it.next() orelse {
                std.debug.print("You must specify output filename with -o\n", .{});
                std.process.exit(1);
            };
        } else {
            try names.append(gpa, try gpa.dupe(u8, arg));
        }
    }

    const outfile = out_path orelse {
        std.debug.print("You must specify output filename with -o\n", .{});
        std.process.exit(1);
    };
    if (names.items.len == 0) {
        std.debug.print("You must specify some files to pack, duh\n", .{});
        std.process.exit(1);
    }

    std.debug.print("{d} files to pack\n", .{names.items.len});

    var files: std.ArrayList(dat.InputFile) = .empty;
    for (names.items) |name| {
        if (name.len > 12) {
            std.debug.print("filename {s} is longer than 12 chars\n", .{name});
            std.process.exit(1);
        }
        const data = dir.readFileAlloc(io, name, gpa, .unlimited) catch |err| {
            std.debug.print("{s} is not accessible: {t}\n", .{ name, err });
            std.process.exit(1);
        };
        try files.append(gpa, .{ .name = name, .data = data });
    }

    const packed_buf = try dat.pack(gpa, files.items);
    try dir.writeFile(io, .{ .sub_path = outfile, .data = packed_buf });

    std.debug.print("Opened {s}\n", .{outfile});
    for (names.items) |name| std.debug.print("adding {s}  OK\n", .{name});
}
