#include "jumpnbump_world.hpp"

#include <cstring>

#include <godot_cpp/core/class_db.hpp>

namespace godot {

namespace {

// Carves a jnb_world_align()-aligned pointer out of `buf`, which must be at
// least jnb_world_size() + jnb_world_align() - 1 bytes long. Assumes
// jnb_world_align() returns a power of two, matching every real alignment
// value the C ABI can report.
jnb_world *align_world_ptr(std::vector<uint8_t> &buf) {
	size_t align = jnb_world_align();
	uintptr_t base = reinterpret_cast<uintptr_t>(buf.data());
	uintptr_t aligned = (base + align - 1) & ~(align - 1);
	return reinterpret_cast<jnb_world *>(aligned);
}

} // namespace

void JumpnbumpWorld::_bind_methods() {
	ClassDB::bind_method(D_METHOD("init", "rng_seed", "flies_enabled", "level_bytes", "player_count", "player_ai_mask", "no_gore"), &JumpnbumpWorld::init, DEFVAL(0), DEFVAL(0), DEFVAL(false));
	ClassDB::bind_method(D_METHOD("reset"), &JumpnbumpWorld::reset);
	ClassDB::bind_method(D_METHOD("step", "left", "right", "jump"), &JumpnbumpWorld::step);
	ClassDB::bind_method(D_METHOD("pump", "delta_ms", "left", "right", "jump"), &JumpnbumpWorld::pump);
	ClassDB::bind_method(D_METHOD("player_view_get", "player"), &JumpnbumpWorld::player_view_get);
	ClassDB::bind_method(D_METHOD("objects_copy"), &JumpnbumpWorld::objects_copy);
	ClassDB::bind_method(D_METHOD("world_dump_len"), &JumpnbumpWorld::world_dump_len);
	ClassDB::bind_method(D_METHOD("world_dump"), &JumpnbumpWorld::world_dump);
	ClassDB::bind_static_method(get_class_static(), D_METHOD("checksum", "bytes"), &JumpnbumpWorld::checksum);
	ClassDB::bind_method(D_METHOD("event_count"), &JumpnbumpWorld::event_count);
	ClassDB::bind_method(D_METHOD("event_drain", "capacity"), &JumpnbumpWorld::event_drain);

	// BIND_CONSTANT, not BIND_ENUM_CONSTANT: these come from jumpnbump.h's
	// anonymous C enums, which have no registered Variant enum type for
	// BIND_ENUM_CONSTANT's GetTypeInfo lookup to resolve.
	BIND_CONSTANT(JNB_OK);
	BIND_CONSTANT(JNB_ERR_INVALID_ARGUMENT);
	BIND_CONSTANT(JNB_ERR_BUFFER_TOO_SMALL);
	BIND_CONSTANT(JNB_ERR_ABI_VERSION_MISMATCH);
	BIND_CONSTANT(JNB_ERR_LEVEL_PARSE_FAILED);

	BIND_CONSTANT(JNB_EVENT_SFX);
	BIND_CONSTANT(JNB_EVENT_OBJECT_SPAWN);
	BIND_CONSTANT(JNB_EVENT_PLAYER_DEATH);
	BIND_CONSTANT(JNB_EVENT_SCORE_CHANGE);
	BIND_CONSTANT(JNB_EVENT_DRAW);
	BIND_CONSTANT(JNB_EVENT_SFX_VOLUME);
}

int JumpnbumpWorld::init(uint32_t rng_seed, bool flies_enabled, const PackedByteArray &level_bytes, uint8_t player_count, uint8_t player_ai_mask, bool no_gore) {
	jnb_config config{};
	config.abi_version = static_cast<uint16_t>(JNB_ABI_VERSION);
	config.rng_seed = rng_seed;
	config.flies_enabled = flies_enabled ? 1 : 0;
	config.player_count = player_count;
	config.player_ai_mask = player_ai_mask;
	config.no_gore = no_gore ? 1 : 0;

	size_t align = jnb_world_align();
	size_t size = jnb_world_size();
	storage_.assign(size + align - 1, 0);
	world_ = nullptr;

	jnb_world *candidate = align_world_ptr(storage_);
	jnb_result result = jnb_world_init(candidate, &config, level_bytes.ptr(), static_cast<size_t>(level_bytes.size()));
	if (result == JNB_OK) {
		world_ = candidate;
	}
	return result;
}

int JumpnbumpWorld::reset() {
	if (!is_ready()) {
		return JNB_ERR_INVALID_ARGUMENT;
	}
	return jnb_world_reset(world_);
}

int JumpnbumpWorld::step(int left, int right, int jump) {
	if (!is_ready()) {
		return JNB_ERR_INVALID_ARGUMENT;
	}

	jnb_input input{};
	input.left = static_cast<uint8_t>(left);
	input.right = static_cast<uint8_t>(right);
	input.jump = static_cast<uint8_t>(jump);

	return jnb_step(world_, input);
}

Dictionary JumpnbumpWorld::pump(int delta_ms, int left, int right, int jump) {
	Dictionary out;
	if (!is_ready()) {
		out["result"] = JNB_ERR_INVALID_ARGUMENT;
		out["ticks"] = 0;
		return out;
	}

	jnb_input input{};
	input.left = static_cast<uint8_t>(left);
	input.right = static_cast<uint8_t>(right);
	input.jump = static_cast<uint8_t>(jump);

	uint32_t ticks = 0;
	jnb_result result = jnb_pump(world_, static_cast<uint32_t>(delta_ms), input, &ticks);
	out["result"] = result;
	out["ticks"] = static_cast<int>(ticks);
	return out;
}

Dictionary JumpnbumpWorld::player_view_get(int player) {
	Dictionary out;
	if (!is_ready()) {
		out["result"] = JNB_ERR_INVALID_ARGUMENT;
		return out;
	}

	jnb_player_view view{};
	jnb_result result = jnb_player_view_get(world_, static_cast<uint8_t>(player), &view);
	out["result"] = result;
	if (result == JNB_OK) {
		out["enabled"] = view.enabled;
		out["dead_flag"] = view.dead_flag;
		out["direction"] = view.direction;
		out["jump_ready"] = view.jump_ready;
		out["jump_abort"] = view.jump_abort;
		out["in_water"] = view.in_water;
		out["x"] = view.x;
		out["y"] = view.y;
		out["x_add"] = view.x_add;
		out["y_add"] = view.y_add;
		out["bumps"] = view.bumps;
		out["anim"] = view.anim;
		out["frame"] = view.frame;
		out["image"] = view.image;
	}
	return out;
}

Dictionary JumpnbumpWorld::objects_copy() {
	Dictionary out;
	if (!is_ready()) {
		out["result"] = JNB_ERR_INVALID_ARGUMENT;
		return out;
	}

	size_t required = 0;
	jnb_result result = jnb_objects_copy(world_, nullptr, 0, &required);
	if (result != JNB_OK && result != JNB_ERR_BUFFER_TOO_SMALL) {
		out["result"] = result;
		return out;
	}

	std::vector<jnb_object_view> objects(required);
	size_t actual_required = 0;
	result = jnb_objects_copy(world_, objects.data(), objects.size(), &actual_required);
	out["result"] = result;
	if (result == JNB_OK) {
		Array out_objects;
		for (size_t i = 0; i < objects.size(); i++) {
			Dictionary entry;
			entry["used"] = objects[i].used;
			entry["type"] = objects[i].type;
			entry["x"] = objects[i].x;
			entry["y"] = objects[i].y;
			entry["x_add"] = objects[i].x_add;
			entry["y_add"] = objects[i].y_add;
			entry["anim"] = objects[i].anim;
			entry["frame"] = objects[i].frame;
			entry["image"] = objects[i].image;
			out_objects.push_back(entry);
		}
		out["objects"] = out_objects;
	}
	return out;
}

int JumpnbumpWorld::world_dump_len() {
	return static_cast<int>(jnb_world_dump_len());
}

Dictionary JumpnbumpWorld::world_dump() {
	Dictionary out;
	if (!is_ready()) {
		out["result"] = JNB_ERR_INVALID_ARGUMENT;
		return out;
	}

	size_t len = jnb_world_dump_len();
	std::vector<uint8_t> buf(len);
	size_t written = 0;
	jnb_result result = jnb_world_dump(world_, buf.data(), buf.size(), &written);
	out["result"] = result;
	if (result == JNB_OK) {
		PackedByteArray out_bytes;
		out_bytes.resize(static_cast<int>(written));
		std::memcpy(out_bytes.ptrw(), buf.data(), written);
		out["bytes"] = out_bytes;
	}
	return out;
}

Dictionary JumpnbumpWorld::checksum(const PackedByteArray &bytes) {
	Dictionary out;
	uint32_t value = 0;
	jnb_result result = jnb_checksum(bytes.ptr(), static_cast<size_t>(bytes.size()), &value);
	out["result"] = result;
	if (result == JNB_OK) {
		out["checksum"] = static_cast<int64_t>(value);
	}
	return out;
}

int JumpnbumpWorld::event_count() {
	if (!is_ready()) {
		return 0;
	}
	return static_cast<int>(jnb_event_count(world_));
}

Dictionary JumpnbumpWorld::event_drain(int capacity) {
	Dictionary out;
	if (!is_ready()) {
		out["result"] = JNB_ERR_INVALID_ARGUMENT;
		return out;
	}

	std::vector<jnb_event> events(capacity);
	size_t count = 0;
	jnb_result result = jnb_event_drain(world_, events.data(), events.size(), &count);
	out["result"] = result;
	if (result == JNB_OK) {
		Array out_events;
		for (size_t i = 0; i < count; i++) {
			Dictionary entry;
			entry["kind"] = events[i].kind;
			entry["a"] = events[i].a;
			entry["b"] = events[i].b;
			entry["c"] = events[i].c;
			entry["d"] = events[i].d;
			out_events.push_back(entry);
		}
		out["events"] = out_events;
		out["count"] = static_cast<int>(count);
	}
	return out;
}

} // namespace godot
