extends GdUnitTestSuite

## TASK-016.02 AC#3: CustomLevels' most-recently-used persistence, mirroring
## test_settings_screen.gd's temp-dir pattern for GameSettings.


func _temp_dir(prefix: String) -> String:
	return "user://%s_%d" % [prefix, Time.get_ticks_usec()]


func _cleanup(dir: String) -> void:
	DirAccess.remove_absolute(dir.path_join(CustomLevels.FILE_NAME))
	DirAccess.remove_absolute(dir)


func _touch(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.close()


func test_list_returns_empty_when_no_file_exists() -> void:
	var store := CustomLevels.new(_temp_dir("cl_missing"))
	assert_array(store.list()).is_empty()


func test_add_recent_round_trips_through_a_temp_dir() -> void:
	var dir := _temp_dir("cl_roundtrip")
	DirAccess.make_dir_recursive_absolute(dir)
	var level_path := dir.path_join("mylevel.dat")
	_touch(level_path)

	var store := CustomLevels.new(dir)
	var err := store.add_recent(level_path, "mylevel.dat")
	assert_int(err).is_equal(OK)

	var entries := store.list()
	assert_int(entries.size()).is_equal(1)
	assert_str(entries[0]["path"]).is_equal(level_path)
	assert_str(entries[0]["name"]).is_equal("mylevel.dat")

	DirAccess.remove_absolute(level_path)
	_cleanup(dir)


func test_reselecting_an_existing_entry_moves_it_to_front_without_duplicating() -> void:
	var dir := _temp_dir("cl_reorder")
	DirAccess.make_dir_recursive_absolute(dir)
	var path_a := dir.path_join("a.dat")
	var path_b := dir.path_join("b.dat")
	_touch(path_a)
	_touch(path_b)

	var store := CustomLevels.new(dir)
	store.add_recent(path_a, "a.dat")
	store.add_recent(path_b, "b.dat")
	store.add_recent(path_a, "a.dat")

	var entries := store.list()
	assert_int(entries.size()).is_equal(2)
	assert_str(entries[0]["path"]).is_equal(path_a)
	assert_str(entries[1]["path"]).is_equal(path_b)

	DirAccess.remove_absolute(path_a)
	DirAccess.remove_absolute(path_b)
	_cleanup(dir)


func test_list_is_capped_at_max_entries() -> void:
	var dir := _temp_dir("cl_cap")
	DirAccess.make_dir_recursive_absolute(dir)
	var store := CustomLevels.new(dir)
	var paths := []
	for i in CustomLevels.MAX_ENTRIES + 3:
		var path := dir.path_join("level_%d.dat" % i)
		_touch(path)
		paths.append(path)
		store.add_recent(path, "level_%d.dat" % i)

	var entries := store.list()
	assert_int(entries.size()).is_equal(CustomLevels.MAX_ENTRIES)
	assert_str(entries[0]["path"]).is_equal(paths[-1])

	for path in paths:
		DirAccess.remove_absolute(path)
	_cleanup(dir)


func test_list_silently_drops_entries_whose_file_no_longer_exists() -> void:
	var dir := _temp_dir("cl_pruned")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("gone.dat")
	_touch(path)

	var store := CustomLevels.new(dir)
	store.add_recent(path, "gone.dat")
	DirAccess.remove_absolute(path)

	assert_array(store.list()).is_empty()
	_cleanup(dir)
