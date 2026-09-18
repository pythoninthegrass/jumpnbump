class_name SimWorld
extends RefCounted

## The only .gd file (besides tick_driver.gd) allowed to reference
## JumpnbumpWorld (TASK-014.01's boundary check) -- every other script goes
## through this wrapper instead. Each method here forwards to exactly one
## JumpnbumpWorld method; no simulation logic is reimplemented here.

## Re-exported JumpnbumpWorld/jnb_* constants, so callers outside this file
## never need to reference JumpnbumpWorld directly just to check a result
## code or an event kind.
const OK := JumpnbumpWorld.JNB_OK
const ERR_INVALID_ARGUMENT := JumpnbumpWorld.JNB_ERR_INVALID_ARGUMENT
const ERR_BUFFER_TOO_SMALL := JumpnbumpWorld.JNB_ERR_BUFFER_TOO_SMALL
const ERR_ABI_VERSION_MISMATCH := JumpnbumpWorld.JNB_ERR_ABI_VERSION_MISMATCH
const ERR_LEVEL_PARSE_FAILED := JumpnbumpWorld.JNB_ERR_LEVEL_PARSE_FAILED

const EVENT_SFX := JumpnbumpWorld.JNB_EVENT_SFX
const EVENT_OBJECT_SPAWN := JumpnbumpWorld.JNB_EVENT_OBJECT_SPAWN
const EVENT_PLAYER_DEATH := JumpnbumpWorld.JNB_EVENT_PLAYER_DEATH
const EVENT_SCORE_CHANGE := JumpnbumpWorld.JNB_EVENT_SCORE_CHANGE
const EVENT_DRAW := JumpnbumpWorld.JNB_EVENT_DRAW
const EVENT_SFX_VOLUME := JumpnbumpWorld.JNB_EVENT_SFX_VOLUME

var _world: JumpnbumpWorld = JumpnbumpWorld.new()

func init(rng_seed: int, flies_enabled: bool, level_bytes: PackedByteArray, player_count: int = 0, player_ai_mask: int = 0, no_gore: bool = false) -> int:
	return _world.init(rng_seed, flies_enabled, level_bytes, player_count, player_ai_mask, no_gore)

func reset() -> int:
	return _world.reset()

func step(left: int, right: int, jump: int) -> int:
	return _world.step(left, right, jump)

func pump(delta_ms: int, left: int, right: int, jump: int) -> Dictionary:
	return _world.pump(delta_ms, left, right, jump)

func player_view_get(player: int) -> Dictionary:
	return _world.player_view_get(player)

func objects_copy() -> Dictionary:
	return _world.objects_copy()

func world_dump_len() -> int:
	return _world.world_dump_len()

func world_dump() -> Dictionary:
	return _world.world_dump()

static func checksum(bytes: PackedByteArray) -> Dictionary:
	return JumpnbumpWorld.checksum(bytes)

func event_count() -> int:
	return _world.event_count()

func event_drain(capacity: int) -> Dictionary:
	return _world.event_drain(capacity)
