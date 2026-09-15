const std = @import("std");

// Tier-C ABI conformance suite (TASK-012.03). Once ../include/jumpnbump.h
// exists, this file's tests reach core/abi.zig's exports exclusively through
// @cImport("jumpnbump.h") -- never by importing core/*.zig modules directly.
// Placeholder until then: proves `zig build abitest` runs against the
// (currently empty) abi.zig static library linked in build.zig.
test "abitest step runs" {
    try std.testing.expect(true);
}
