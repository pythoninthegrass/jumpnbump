class_name LevelValidator
extends RefCounted

## Pure validation of a JumpnbumpAssetLoader.load_dat() result (TASK-016.02
## AC#2). load_dat() itself returns JNB_OK even when a required entry
## (levelmap.txt, level.pcx/mask.pcx) is simply absent from a malformed .dat
## -- it only reports a jnb_result error for an entry that IS present but
## fails to decode -- so a "this isn't a playable level" check has to live
## here, one layer up. No file I/O, mirroring sprite_geometry.gd's
## pure-math convention so this is unit-testable without a live Godot
## scene tree or a real .dat on disk.

const JNB_OK := 0
const JNB_ERR_INVALID_ARGUMENT := 1
const JNB_ERR_ABI_VERSION_MISMATCH := 3
const JNB_ERR_LEVEL_PARSE_FAILED := 4
const JNB_ERR_ASSET_NOT_FOUND := 5
const JNB_ERR_ASSET_DECODE_FAILED := 6

const ERROR_MESSAGES := {
	JNB_ERR_INVALID_ARGUMENT: "Could not open that file.",
	JNB_ERR_ABI_VERSION_MISMATCH: "This level was built for a different game version.",
	JNB_ERR_LEVEL_PARSE_FAILED: "The level layout couldn't be parsed.",
	JNB_ERR_ASSET_NOT_FOUND: "A required asset is missing from this file.",
	JNB_ERR_ASSET_DECODE_FAILED: "This file's artwork is corrupted and couldn't be decoded.",
}
const DEFAULT_ERROR_MESSAGE := "That file isn't a valid Jump'n'Bump level."
const MISSING_LEVELMAP_MESSAGE := "This file has no level layout (levelmap.txt) to play."
const MISSING_LEVEL_ART_MESSAGE := "This file is missing its level artwork (level.pcx/mask.pcx)."

## `load_dat_result` is whatever JumpnbumpAssetLoader.load_dat() returned.
## Returns {"ok": bool, "error": String} -- error is "" when ok is true.
static func validate(load_dat_result: Dictionary) -> Dictionary:
	var result := int(load_dat_result.get("result", JNB_ERR_INVALID_ARGUMENT))
	if result != JNB_OK:
		return {"ok": false, "error": ERROR_MESSAGES.get(result, DEFAULT_ERROR_MESSAGE)}

	var levelmap_bytes: PackedByteArray = load_dat_result.get("levelmap_bytes", PackedByteArray())
	if levelmap_bytes.is_empty():
		return {"ok": false, "error": MISSING_LEVELMAP_MESSAGE}

	var level: Dictionary = load_dat_result.get("level", {})
	if not level.has("background") or not level.has("foreground"):
		return {"ok": false, "error": MISSING_LEVEL_ART_MESSAGE}

	return {"ok": true, "error": ""}
