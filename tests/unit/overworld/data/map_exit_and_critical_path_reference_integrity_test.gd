## Story 074, AC-30a (GDD rules 0, 11): every MapExit's target map has an
## exit back; every `critical_path` leg starts at an existing EntryPoint and
## ends at an existing MapExit, Static symbol or CampSpot, with unique leg
## IDs; every chapter step names an existing map and a leg on it.
extends GdUnitTestSuite

const _MAPS: Array[String] = ["town", "segment", "dungeon", "boss_chamber"]


func test_shipped_records_and_scenes_pass() -> void:
	var maps: Dictionary = _maps()
	var errors: PackedStringArray = MapValidator.validate_maps(maps, OverworldConfig.new())
	var legs: int = 0
	for name: String in _MAPS:
		var rec: MapData = _record(name)
		legs += rec.critical_path.size()
		errors.append_array(MapValidator.validate_legs(rec, maps[rec.id]))
	_free(maps)
	assert_array(Array(errors)).is_empty()
	assert_int(legs).is_greater_equal(7)


func test_leg_with_unknown_ends_is_reported() -> void:
	var maps: Dictionary = _maps()
	var rec: MapData = _record("segment").duplicate(true) as MapData
	rec.critical_path[0].from_entry = &"from_nowhere"
	rec.critical_path[1].to = "exit_to_nowhere"
	var errors: PackedStringArray = MapValidator.validate_legs(rec, maps[rec.id])
	_free(maps)
	assert_int(errors.size()).is_equal(2)
	assert_str(errors[0]).contains("from_nowhere")
	assert_str(errors[1]).contains("exit_to_nowhere")


func test_repeated_leg_id_is_reported() -> void:
	var maps: Dictionary = _maps()
	var rec: MapData = _record("dungeon").duplicate(true) as MapData
	rec.critical_path[1].id = rec.critical_path[0].id
	var errors: PackedStringArray = MapValidator.validate_legs(rec, maps[rec.id])
	_free(maps)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("repeated")


func test_leg_may_end_at_a_static_symbol_or_a_camp() -> void:
	var maps: Dictionary = _maps()
	var errors := PackedStringArray()
	for name: String in ["town", "dungeon", "boss_chamber"]:
		var rec: MapData = _record(name)
		errors.append_array(MapValidator.validate_legs(rec, maps[rec.id]))
	_free(maps)
	assert_array(Array(errors)).is_empty()


func test_exit_without_a_way_back_is_reported() -> void:
	var maps: Dictionary = _maps()
	var dungeon: OverworldMap = maps["map_paris_dungeon_placeholder"]
	var back: MapExit = dungeon.map_exits()[0]  # exit_to_segment
	dungeon.remove_child(back)
	back.free()
	var errors: PackedStringArray = MapValidator.validate_maps(maps, OverworldConfig.new())
	_free(maps)
	assert_str(", ".join(errors)).contains(
			"map_paris_segment_placeholder: exit 'exit_to_dungeon' leads to map_paris_dungeon_placeholder, which has no exit back")


func _record(name: String) -> MapData:
	return load("res://data/maps/map_paris_%s_placeholder.tres" % name) as MapData


func _maps() -> Dictionary:
	var maps: Dictionary = {}
	for name: String in _MAPS:
		var map: OverworldMap = (load("res://data/maps/paris_%s_placeholder.tscn" % name) as PackedScene) \
				.instantiate() as OverworldMap
		maps[map.map_id] = map
	return maps


func _free(maps: Dictionary) -> void:
	for map: OverworldMap in maps.values():
		map.free()


func test_shipped_chapter_steps_name_existing_legs() -> void:
	var steps: ChapterSteps = load(OverworldConfig.new().chapter_steps_path) as ChapterSteps
	assert_int(steps.steps.size()).is_equal(7)
	assert_array(Array(MapValidator.validate_steps(steps, _records()))).is_empty()


func test_step_with_unknown_map_leg_or_repeated_id_is_reported() -> void:
	var steps: ChapterSteps = (load(OverworldConfig.new().chapter_steps_path) as ChapterSteps).duplicate(true)
	steps.steps[0].map_id = "map_nowhere"
	steps.steps[1].leg_id = "leg_nowhere"
	steps.steps[2].id = steps.steps[3].id
	var errors: PackedStringArray = MapValidator.validate_steps(steps, _records())
	assert_int(errors.size()).is_equal(3)
	assert_str(", ".join(errors)).contains("map_nowhere").contains("leg_nowhere").contains("repeated")


func _records() -> Dictionary:
	var out: Dictionary = {}
	for name: String in _MAPS:
		var rec: MapData = _record(name)
		out[rec.id] = rec
	return out
