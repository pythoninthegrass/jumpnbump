extends GdUnitTestSuite

## TASK-016.02 AC#2: LevelValidator flags a load_dat() result that decoded
## "OK" but is missing what a match actually needs to play, with a specific
## human-readable reason per failure -- pure Dictionary-in/Dictionary-out,
## no file I/O or live .dat needed.


func _valid_result() -> Dictionary:
	return {
		"result": LevelValidator.JNB_OK,
		"sprites": {"rabbit": {}},
		"level": {"background": Image.new(), "foreground": Image.new()},
		"menu": {},
		"levelmap_bytes": "1111".to_utf8_buffer(),
	}


func test_valid_result_passes() -> void:
	var out := LevelValidator.validate(_valid_result())
	assert_bool(out["ok"]).is_true()
	assert_str(out["error"]).is_equal("")


func test_decode_error_result_fails_with_its_specific_message() -> void:
	var out := LevelValidator.validate({"result": LevelValidator.JNB_ERR_ASSET_DECODE_FAILED})
	assert_bool(out["ok"]).is_false()
	assert_str(out["error"]).is_equal(LevelValidator.ERROR_MESSAGES[LevelValidator.JNB_ERR_ASSET_DECODE_FAILED])


func test_unknown_error_code_falls_back_to_the_default_message() -> void:
	var out := LevelValidator.validate({"result": 999})
	assert_bool(out["ok"]).is_false()
	assert_str(out["error"]).is_equal(LevelValidator.DEFAULT_ERROR_MESSAGE)


func test_missing_levelmap_bytes_fails_even_when_result_is_ok() -> void:
	var result := _valid_result()
	result["levelmap_bytes"] = PackedByteArray()
	var out := LevelValidator.validate(result)
	assert_bool(out["ok"]).is_false()
	assert_str(out["error"]).is_equal(LevelValidator.MISSING_LEVELMAP_MESSAGE)


func test_missing_level_art_fails_even_when_result_is_ok() -> void:
	var result := _valid_result()
	result["level"] = {}
	var out := LevelValidator.validate(result)
	assert_bool(out["ok"]).is_false()
	assert_str(out["error"]).is_equal(LevelValidator.MISSING_LEVEL_ART_MESSAGE)


func test_missing_result_key_is_treated_as_invalid_argument() -> void:
	var out := LevelValidator.validate({})
	assert_bool(out["ok"]).is_false()
	assert_str(out["error"]).is_equal(LevelValidator.ERROR_MESSAGES[LevelValidator.JNB_ERR_INVALID_ARGUMENT])
