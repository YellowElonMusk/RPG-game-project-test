## Story 069, AC-27e (GDD rule 17): the overworld segment and the Town (the
## last act's maps) both have a `liberated_profile_id` and a
## `liberated_kit_id` that resolve, and with `paris_liberated` set no walk
## route from the segment reaches the dungeon or the boss chamber.
extends GdUnitTestSuite

const _MAPS: Array[String] = ["town", "segment", "dungeon", "boss_chamber"]


func test_the_shipped_last_act_passes() -> void:
	var maps: Dictionary = _maps()
	assert_array(Array(MapValidator.validate_last_act(_steps(), _records(), maps, OverworldConfig.new()))).is_empty()


func test_the_last_act_maps_are_the_segment_and_town() -> void:
	var steps: ChapterSteps = _steps()
	var act: Dictionary = {}
	var started: bool = false
	for step: ChapterStep in steps.steps:
		started = started or step.id == steps.last_act_from
		if started:
			act[step.map_id] = true
	assert_array(act.keys()).contains_exactly_in_any_order(
			["map_paris_segment_placeholder", "map_paris_town_placeholder"])


func test_a_missing_or_unresolved_field_is_an_error() -> void:
	for field: String in ["liberated_profile_id", "liberated_kit_id"]:
		for value: String in ["", "nonexistent_id"]:
			var records: Dictionary = _records()
			var town: MapData = (records["map_paris_town_placeholder"] as MapData).duplicate()
			town.set(field, value)
			records["map_paris_town_placeholder"] = town
			var errors: PackedStringArray = MapValidator.validate_last_act(_steps(), records, _maps(), OverworldConfig.new())
			assert_str("\n".join(errors)).override_failure_message("%s = '%s' passed" % [field, value]) \
					.contains("%s '%s' does not resolve" % [field, value])


func test_without_the_tape_the_dungeon_is_reachable() -> void:
	var maps: Dictionary = _maps()
	var segment: OverworldMap = maps["map_paris_segment_placeholder"]
	for exit: MapExit in segment.map_exits():
		exit.closed_when_flag = ""
	var errors: PackedStringArray = MapValidator.validate_last_act(_steps(), _records(), maps, OverworldConfig.new())
	assert_str("\n".join(errors)).contains("exit_to_dungeon to map_paris_dungeon_placeholder is still reachable")


func _steps() -> ChapterSteps:
	return load("res://data/chapters/chapter_paris_steps.tres")


func _records() -> Dictionary:
	var out: Dictionary = {}
	for name: String in _MAPS:
		var rec: MapData = load("res://data/maps/map_paris_%s_placeholder.tres" % name)
		out[rec.id] = rec
	return out


func _maps() -> Dictionary:
	var out: Dictionary = {}
	for name: String in _MAPS:
		var map: OverworldMap = auto_free((load("res://data/maps/paris_%s_placeholder.tscn" % name) as PackedScene).instantiate())
		out["map_paris_%s_placeholder" % name] = map
	return out
