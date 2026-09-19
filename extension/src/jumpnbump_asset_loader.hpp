#pragma once

#include <cstdint>

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string.hpp>

#include "jumpnbump.h"

namespace godot {

// Runtime .dat asset loading (TASK-016.01): decodes a custom .dat archive's
// sprites and level/menu art into Godot Image/ImageTexture/AtlasTexture
// resources in-process, so a level not present at build time renders
// without an editor re-import step. Every decode/atlas/layer call forwards
// to exactly one jnb_* function from include/jumpnbump.h (core/asset_runtime.zig
// via core/abi.zig) -- no gob/pcx/atlas-layout logic is reimplemented here,
// matching JumpnbumpWorld's own thin-wrapper convention.
class JumpnbumpAssetLoader : public RefCounted {
	GDCLASS(JumpnbumpAssetLoader, RefCounted)

protected:
	static void _bind_methods();

public:
	// Reads dat_path's raw bytes (a plain, already-decompressed .dat archive
	// -- no .bz2/.gz outer-compression handling here, see the task notes)
	// and decodes every asset a custom level ships: the four sprite gobs
	// (rabbit/objects/numbers/font) as RGBA8 atlases sharing menu.pcx's
	// palette, the level and menu PCX/mask pairs as background+foreground
	// RGBA8 layers, and levelmap.txt's raw bytes (unparsed -- pass straight
	// to JumpnbumpWorld.init, which already parses levelmap-format text).
	//
	// Returns a Dictionary: "result" (a jnb_result, JNB_OK on success) plus,
	// on success, "sprites" (Dictionary name -> {"image": Image, "frames":
	// Array of {x,y,width,height,hotspot_x,hotspot_y}}), "level" and "menu"
	// (each a Dictionary {"background": Image, "foreground": Image}),
	// "levelmap_bytes" (PackedByteArray, levelmap.txt's raw content), and
	// "mods" (Dictionary name -> PackedByteArray, raw undecoded bytes of any
	// bump.mod/jump.mod/scores.mod entry present -- see render_mod() below;
	// TASK-016.03 deliberately doesn't render these here, since a full-song
	// render is real CPU work callers shouldn't pay during level-picker
	// preview/validation, only once a level actually starts).
	static Dictionary load_dat(const String &dat_path);

	// Renders mod_bytes (a raw, already-decompressed .mod file, e.g. one of
	// load_dat()'s "mods" entries) into a looping AudioStreamWAV, via
	// core/mod_player.zig through jnb_mod_count_frames/jnb_mod_render (see
	// that module's header comment for its documented scope). Returns a
	// Dictionary: "result" (a jnb_result) plus, on success, "stream" (an
	// AudioStreamWAV, 16-bit stereo PCM at 44100Hz -- matching every other
	// audio asset in this repo, see game/content/audio/music/manifest.json's
	// sample_rate -- looping over its full length, matching sdl/sound.c's
	// dj_start_mod, which loops the whole decoded track from its start).
	static Dictionary render_mod(const PackedByteArray &mod_bytes);
};

} // namespace godot
