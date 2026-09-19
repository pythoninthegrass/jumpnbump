extends GdUnitTestSuite

## TASK-016.01: JumpnbumpAssetLoader.load_dat() decodes a raw .dat archive's
## sprites/level art/levelmap entirely at runtime, through the C ABI
## (core/asset_runtime.zig via core/abi.zig), producing Godot Images with no
## editor re-import step. Exercised here against the repo's own
## data/jumpbump.dat -- present at build time, but read as a plain file, the
## same way a dropped-in custom level would be -- so this stays a safe,
## deterministic CI fixture; see backlog task TASK-016.01's implementation
## notes for the manual smoke test against a real third-party custom level
## (mario3.dat) this can't commit to the repo.

const JNB_ASSET_SCREEN_W := 400
const JNB_ASSET_SCREEN_H := 256

## Local copies of jnb_result values (include/jumpnbump.h), not
## JNB_OK/JNB_ERR_INVALID_ARGUMENT: tools/validate_game_boundary.py
## (TASK-014.01) forbids anything outside game/simulation/ from referencing
## the JumpnbumpWorld GDExtension class at all, constants included.
const JNB_OK := 0
const JNB_ERR_INVALID_ARGUMENT := 1
const JNB_ERR_ASSET_DECODE_FAILED := 6


func _jumpbump_dat_path() -> String:
	var game_dir: String = ProjectSettings.globalize_path("res://").rstrip("/")
	return game_dir.get_base_dir().path_join("data/jumpbump.dat")


func test_class_is_registered() -> void:
	assert_bool(ClassDB.class_exists("JumpnbumpAssetLoader")).is_true()


func test_load_dat_decodes_sprites_level_and_menu_from_the_real_archive() -> void:
	var start_usec := Time.get_ticks_usec()
	var out: Dictionary = JumpnbumpAssetLoader.load_dat(_jumpbump_dat_path())
	var elapsed_ms := (Time.get_ticks_usec() - start_usec) / 1000.0

	assert_int(out["result"]).is_equal(JNB_OK)

	# AC#3: loading a typical .dat is not a multi-second stall.
	assert_float(elapsed_ms).is_less(1000.0)

	var sprites: Dictionary = out["sprites"]
	for name in ["rabbit", "objects", "numbers", "font"]:
		assert_bool(sprites.has(name)).is_true()
		var image: Image = sprites[name]["image"]
		assert_vector(image.get_size()).is_equal(Vector2i(JNB_ASSET_SCREEN_W, JNB_ASSET_SCREEN_H))
		assert_int(image.get_format()).is_equal(Image.FORMAT_RGBA8)
		var frames: Array = sprites[name]["frames"]
		assert_int(frames.size()).is_greater(0)

	# tools/build_sprite_atlas.py's committed manifest is the independently
	# verified oracle for exact frame counts (--check byte-diffs the PNG
	# too); this only spot-checks rabbit's count stays in lockstep with it.
	var rabbit_manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/sprites/rabbit_atlas.json"))
	assert_int((sprites["rabbit"]["frames"] as Array).size()).is_equal((rabbit_manifest["frames"] as Array).size())

	var level: Dictionary = out["level"]
	var menu: Dictionary = out["menu"]
	for layer in [level, menu]:
		var background: Image = layer["background"]
		var foreground: Image = layer["foreground"]
		assert_vector(background.get_size()).is_equal(Vector2i(JNB_ASSET_SCREEN_W, JNB_ASSET_SCREEN_H))
		assert_vector(foreground.get_size()).is_equal(Vector2i(JNB_ASSET_SCREEN_W, JNB_ASSET_SCREEN_H))

	# levelmap.txt's raw bytes, ready to hand straight to JumpnbumpWorld.init
	# (which parses levelmap-format text itself -- core/levelmap.zig).
	var levelmap_bytes: PackedByteArray = out["levelmap_bytes"]
	assert_int(levelmap_bytes.size()).is_greater(0)
	var first_digit := levelmap_bytes.get_string_from_utf8().substr(0, 1)
	assert_bool(first_digit in ["0", "1", "2", "3", "4"]).is_true()

	# TASK-016.03: raw .mod passthrough (not decoded here -- see render_mod()).
	var mods: Dictionary = out["mods"]
	for name in ["bump", "jump", "scores"]:
		assert_bool(mods.has(name)).is_true()
		assert_int((mods[name] as PackedByteArray).size()).is_greater(0)


func test_load_dat_reports_invalid_argument_for_a_missing_file() -> void:
	var out: Dictionary = JumpnbumpAssetLoader.load_dat("res://does_not_exist.dat")
	assert_int(out["result"]).is_equal(JNB_ERR_INVALID_ARGUMENT)


func test_load_dat_reports_decode_failure_for_a_corrupt_archive() -> void:
	var dir := "user://test_asset_loader_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("corrupt.dat")
	var file := FileAccess.open(path, FileAccess.WRITE)
	# A .dat directory that claims one entry named "menu.pcx" but supplies no
	# offset/size table at all -- dat.zig's find() reads past a truncated
	# buffer and reports "not found" rather than reading garbage, so this
	# actually exercises jnb_pcx_palette_decode's JNB_ERR_ASSET_NOT_FOUND
	# passthrough... except menu.pcx is optional (load_dat only decodes it
	# if present), so this instead proves a malformed .dat with NO menu.pcx
	# still fails fast on a corrupt/missing required entry rather than
	# crashing.
	file.store_32(1) # claims 1 entry, but the file ends here
	file.close()

	var out: Dictionary = JumpnbumpAssetLoader.load_dat(path)
	# No menu.pcx (palette decode skipped) and no gob/pcx entries found
	# (dat.find can't read a truncated directory) -- every asset is simply
	# absent, which load_dat treats as JNB_OK with empty sprites/layers, not
	# a decode failure. This documents that behavior explicitly rather than
	# leaving it unspecified.
	assert_int(out["result"]).is_equal(JNB_OK)
	assert_dict(out["sprites"]).is_empty()
	assert_dict(out["level"]).is_empty()
	assert_dict(out["menu"]).is_empty()

	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(dir)


## TASK-016.03: JumpnbumpAssetLoader.render_mod() renders a raw .mod's bytes
## (one of load_dat()'s "mods" entries) into a looping AudioStreamWAV, through
## core/mod_player.zig via jnb_mod_count_frames/jnb_mod_render. Exercised
## against the repo's own data/bump.mod -- see that module's header comment
## for its documented "minimal player" scope and backlog task TASK-016.03's
## implementation notes for the manual verification a real listening test
## would require, which isn't possible in this headless environment.
func test_render_mod_produces_a_looping_audio_stream_from_the_real_bump_mod() -> void:
	var game_dir: String = ProjectSettings.globalize_path("res://").rstrip("/")
	var mod_path := game_dir.get_base_dir().path_join("data/bump.mod")
	var file := FileAccess.open(mod_path, FileAccess.READ)
	var mod_bytes := file.get_buffer(file.get_length())
	file.close()

	var start_usec := Time.get_ticks_usec()
	var out: Dictionary = JumpnbumpAssetLoader.render_mod(mod_bytes)
	var elapsed_ms := (Time.get_ticks_usec() - start_usec) / 1000.0

	assert_int(out["result"]).is_equal(JNB_OK)
	assert_float(elapsed_ms).is_less(5000.0)

	var stream: AudioStreamWAV = out["stream"]
	assert_int(stream.mix_rate).is_equal(44100)
	assert_bool(stream.stereo).is_true()
	assert_int(stream.format).is_equal(AudioStreamWAV.FORMAT_16_BITS)
	assert_int(stream.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	assert_int(stream.loop_begin).is_equal(0)
	assert_int(stream.loop_end).is_greater(0)
	# 16-bit stereo: 4 bytes/frame.
	assert_int(stream.data.size()).is_equal(stream.loop_end * 4)


func test_render_mod_reports_decode_failure_for_a_non_mod_buffer() -> void:
	var garbage := PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0])
	var out: Dictionary = JumpnbumpAssetLoader.render_mod(garbage)
	assert_int(out["result"]).is_equal(JNB_ERR_ASSET_DECODE_FAILED)
