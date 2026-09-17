// Draw-boundary stubs only (add_pob/add_leftovers), for the core/steer.zig
// Tier-A unit-test build.
//
// steer.zig owns objects[]/object_anims[]/ban_map[] (its own strong exports)
// and, since TASK-011.04, reaches add_object() as an extern fn whose
// definition lives in core/objects.zig. That objects.zig object references
// add_pob()/add_leftovers() — the renderer boundary, undefined in core. In
// this compilation steer.zig already supplies the world arrays, so only the
// two draw stubs are added here; core/unit_objects_globals.zig (which also
// defines the arrays) would collide with steer.zig's exports, so the two are
// separate files. See core/build.zig's addTestStep for where each is linked.
fn noop_add_pob(page: ?*anyopaque, x: c_int, y: c_int, image: c_int, gobs: ?*anyopaque) callconv(.c) void {
    _ = .{ page, x, y, image, gobs };
}
fn noop_add_leftovers(which: c_int, x: c_int, y: c_int, frame: c_int, gobs: ?*anyopaque) callconv(.c) void {
    _ = .{ which, x, y, frame, gobs };
}
comptime {
    @export(&noop_add_pob, .{ .name = "add_pob" });
    @export(&noop_add_leftovers, .{ .name = "add_leftovers" });
}
