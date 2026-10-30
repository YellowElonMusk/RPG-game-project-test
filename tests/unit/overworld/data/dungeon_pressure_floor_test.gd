## Story 085, AC-31b (GDD rule 12 "Pressure floor (dungeon)"): on the
## dungeon, every tied shortest route to its exits crosses at least
## ceil(N/2) patrol bands, and the bypass lane is at least
## `bypass_ratio_min` times that route. The shipped dungeon passes: its hall
## Clerk watches the near gap of the hall wall, and the far gap is the
## detour. A Clerk moved off the short route fails the floor; a stricter
## ratio fails the ratio.
extends GdUnitTestSuite

const _NAMES: Array[String] = ["town", "segment", "dungeon", "boss_chamber"]


func test_shipped_dungeon_meets_the_pressure_floor() -> void:
	var maps: Dictionary = _maps()
	var errors := PackedStringArray()
	for name: String in _NAMES:
		var rec: MapData = _record(name)
		errors.append_array(BypassSearch.check_pressure(rec, maps[rec.id], OverworldConfig.new()))
	_free(maps)
	assert_array(Array(errors)).is_empty()


func test_a_clerk_off_the_short_route_fails_the_floor() -> void:
	var maps: Dictionary = _maps()
	var dungeon: OverworldMap = maps["map_paris_dungeon_placeholder"]
	# Every patrolling Clerk now watches nothing the short route crosses: the
	# hall ones pace the far west lane, the first-room one a far corner.
	for sym: EncounterSymbol in dungeon.symbol_markers():
		if sym.is_static:
			continue
		if sym.symbol_id == "sym_dungeon_clerks_first_room":
			sym.patrol_path = PackedVector2Array([Vector2(21.5, 30.5), Vector2(21.5, 32.5)])
		else:
			sym.patrol_path = PackedVector2Array([Vector2(2.5, 5.5), Vector2(2.5, 8.5)])
	var errors: PackedStringArray = BypassSearch.check_pressure(_record("dungeon"), dungeon, OverworldConfig.new())
	_free(maps)
	assert_str(", ".join(errors)).contains("dungeon_to_boss").contains("fewer than 3 of 6 patrol bands")


func test_a_stricter_ratio_fails_the_ratio() -> void:
	var maps: Dictionary = _maps()
	var cfg := OverworldConfig.new()
	cfg.bypass_ratio_min = 5.0
	var errors: PackedStringArray = BypassSearch.check_pressure(_record("dungeon"),
			maps["map_paris_dungeon_placeholder"], cfg)
	_free(maps)
	assert_str(", ".join(errors)).contains("bypass_ratio_min 5.00")


func test_only_the_story_encounter_map_is_checked() -> void:
	var maps: Dictionary = _maps()
	var cfg := OverworldConfig.new()
	cfg.bypass_ratio_min = 5.0
	var errors := PackedStringArray()
	for name: String in ["town", "segment", "boss_chamber"]:
		var rec: MapData = _record(name)
		errors.append_array(BypassSearch.check_pressure(rec, maps[rec.id], cfg))
	_free(maps)
	assert_array(Array(errors)).is_empty()


func test_subsets_enumerates_every_combination() -> void:
	assert_array(BypassSearch._subsets([0, 1, 2], 2)).is_equal([[0, 1], [0, 2], [1, 2]])
	assert_array(BypassSearch._subsets([0, 1], 2)).is_equal([[0, 1]])
	assert_array(BypassSearch._subsets([0], 0)).is_equal([[]])


func _record(name: String) -> MapData:
	return load("res://data/maps/map_paris_%s_placeholder.tres" % name) as MapData


func _maps() -> Dictionary:
	var maps: Dictionary = {}
	for name: String in _NAMES:
		var map: OverworldMap = (load("res://data/maps/paris_%s_placeholder.tscn" % name) as PackedScene) \
				.instantiate() as OverworldMap
		maps[map.map_id] = map
	return maps


func _free(maps: Dictionary) -> void:
	for map: OverworldMap in maps.values():
		map.free()
