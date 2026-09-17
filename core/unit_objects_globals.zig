// Standalone-build backing for core/objects.zig's Tier-A unit tests.
//
// objects.zig declares objects[]/object_anims[]/ban_map[] as `extern var`
// (their real home is steer.zig per the globals rule) and add_pob()/
// add_leftovers() as `extern fn` (Core purity: no renderer in the core). When
// objects.zig is its own test root — `zig build test` compiles each unit-test
// file standalone — none of those symbols exist in that compilation, so this TU
// supplies them, compiled as an object and linked into the objects.zig unit
// test only (see core/build.zig's addTestStep). It is the same arrangement as
// core/unit_net_globals.zig for is_server/is_net.
//
// This TU deliberately does NOT @import("objects.zig"): importing the module
// here would drag objects.zig's own update_objects/add_object exports into the
// object file a second time (the unit test already links objects.zig as its
// root), producing duplicate symbols. It only needs the array element types,
// which it mirrors as layout-identical extern structs (world.Object for the
// slots, a local ObjectAnim twin for the anim table). The Tier-B differential
// (core/objects_difftest.zig) does not use this file at all — there steer.zig
// provides the real world arrays and the harness provides the real capture
// sinks, all in one compilation.
const world = @import("world.zig");

const AnimFrame = extern struct {
    image: c_int = 0,
    ticks: c_int = 0,
};
const ObjectAnim = extern struct {
    num_frames: c_int = 0,
    restart_frame: c_int = 0,
    frame: [10]AnimFrame = [_]AnimFrame{.{}} ** 10,
};

pub export var objects_store: [world.num_objects]world.Object = [_]world.Object{.{}} ** world.num_objects;
pub export var object_anims_store: [8]ObjectAnim = [_]ObjectAnim{.{}} ** 8;
pub export var ban_map_store: [world.ban_rows][world.ban_cols]u32 = [_][world.ban_cols]u32{[_]u32{0} ** world.ban_cols} ** world.ban_rows;

comptime {
    @export(&objects_store, .{ .name = "objects" });
    @export(&object_anims_store, .{ .name = "object_anims" });
    @export(&ban_map_store, .{ .name = "ban_map" });
    @export(&noop_add_pob, .{ .name = "add_pob" });
    @export(&noop_add_leftovers, .{ .name = "add_leftovers" });
}

fn noop_add_pob(page: ?*anyopaque, x: c_int, y: c_int, image: c_int, gobs: ?*anyopaque) callconv(.c) void {
    _ = .{ page, x, y, image, gobs };
}
fn noop_add_leftovers(which: c_int, x: c_int, y: c_int, frame: c_int, gobs: ?*anyopaque) callconv(.c) void {
    _ = .{ which, x, y, frame, gobs };
}
