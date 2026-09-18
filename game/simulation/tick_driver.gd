class_name TickDriver
extends RefCounted

## Deliberately not a Node: no _physics_process (variable step re-read after
## each tick, engine-owned catch-up cap, forces the sim onto the tree) and no
## Timer (fires on a fixed interval with no accumulator, so it discards the
## remainder instead of carrying it -- a hitch loses ticks the oracle's own
## accumulator would still run). advance_frame never reads a clock or
## inspects world/game state itself: raw_frame_ms, running, and gate are all
## caller-supplied so this stays a pure forwarding call onto
## SimWorld.pump / jnb_pump (AC#1). project.godot's
## application/run/delta_smoothing must stay false (TASK-014.01) or
## raw_frame_ms itself would already be an averaged number by the time it
## gets here, defeating jnb_pump's own accumulator math.

## running: whether the app/scene tree is currently processing frames at all
## (false while engine-paused, e.g. a modal settings/quit overlay).
## gate: whether the game's own state currently permits ticking (e.g. the
## match is actively playing, not on a menu/scoreboard screen). Either being
## false discards this frame's delta outright -- it is never banked for a
## later call, matching jnb_pump's own "not advancing" no-op rather than
## silently accumulating backlog time (AC#2).
##
## left/right/jump are held for the whole delta's worth of ticks, matching
## jnb_pump's own contract (core/game_loop.zig's pump()) that a single call
## runs every whole tick with the same inputs. Real per-player input comes
## from TASK-015.01's InputRouter; until then callers may pass 0/0/0.
static func advance_frame(world: SimWorld, raw_frame_ms: float, running: bool, gate: bool, left: int = 0, right: int = 0, jump: int = 0) -> Dictionary:
	if not running or not gate:
		return {"result": SimWorld.OK, "ticks": 0}
	var delta_ms := int(round(raw_frame_ms))
	return world.pump(delta_ms, left, right, jump)
