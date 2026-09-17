#pragma once

#include <cstdint>
#include <vector>

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

#include "jumpnbump.h"

namespace godot {

// Thin GDExtension wrapper around include/jumpnbump.h's C ABI (TASK-012.04).
// Every method here forwards to exactly one jnb_* call; no simulation logic
// is reimplemented -- core/*.zig (via core/abi.zig) remains the only place
// game rules live.
class JumpnbumpWorld : public RefCounted {
	GDCLASS(JumpnbumpWorld, RefCounted)

protected:
	static void _bind_methods();

public:
	JumpnbumpWorld() = default;
	~JumpnbumpWorld() override = default;

	int init(uint32_t rng_seed, bool flies_enabled, const PackedByteArray &level_bytes);
	int reset();
	int step(int left, int right, int jump);
	Dictionary pump(int delta_ms, int left, int right, int jump);
	Dictionary player_view_get(int player);
	Dictionary objects_copy();
	int world_dump_len();
	Dictionary world_dump();
	static Dictionary checksum(const PackedByteArray &bytes);
	int event_count();
	Dictionary event_drain(int capacity);

private:
	// storage_ is over-allocated by jnb_world_align() - 1 bytes so an
	// aligned jnb_world* can be carved out of it manually; std::vector's own
	// default alignment is not guaranteed to satisfy whatever
	// jnb_world_align() reports (docs/build-layout.md).
	std::vector<uint8_t> storage_;
	jnb_world *world_ = nullptr;

	bool is_ready() const { return world_ != nullptr; }
};

} // namespace godot
