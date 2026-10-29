## Story 083, AC-31 (GDD rule 12 bypass lane): rule 12's ordered search
## finds a route clear of every patrol band on every critical-path leg of
## every non-boss map. A patrol band across the only way fails the leg; the
## dungeon's boss leg passes only through the story-encounter split (up to
## the counter, then on from beyond its boom); a leg ending at a symbol ends
## within reach of it.
extends GdUnitTestSuite

const _NAMES: Array[String] = ["town", "segment", "dungeon", "boss_chamber"]


func test_every_shipped_leg_has_a_bypass_lane() -> void:
	var maps: Dictionary = _maps()
	var errors := PackedStringArray()
	for name: String in _NAMES:
		var rec: MapData = _record(name)
		errors.append_array(BypassSearch.check(rec, maps[rec.id], OverworldConfig.new()))
	_free(maps)
	assert_array(Array(errors)).is_empty()


func test_a_band_across_the_hall_fails_the_boss_leg() -> void:
	var maps: Dictionary = _maps()
	var dungeon: OverworldMap = maps["map_paris_dungeon_placeholder"]
	_symbol(dungeon, "sym_dungeon_clerks_hall").patrol_path = \
			PackedVector2Array([Vector2(2.5, 9.5), Vector2(13.5, 9.5)])
	var errors: PackedStringArray = BypassSearch.check(_record("dungeon"), dungeon, OverworldConfig.new())
	_free(maps)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("dungeon_to_boss")


func test_bands_across_the_segment_top_row_fail_both_legs() -> void:
	var maps: Dictionary = _maps()
	var segment: OverworldMap = maps["map_paris_segment_placeholder"]
	segment.symbol_markers()[0].patrol_path = PackedVector2Array([Vector2(9.5, 4.5), Vector2(14.5, 4.5)])
	segment.symbol_markers()[1].patrol_path = PackedVector2Array([Vector2(18.5, 4.5), Vector2(18.5, 11.5)])
	var errors: PackedStringArray = BypassSearch.check(_record("segment"), segment, OverworldConfig.new())
	_free(maps)
	assert_int(errors.size()).is_equal(2)


func test_the_boss_leg_needs_the_story_encounter_split() -> void:
	# With the boom closed and no split, the boss exit is unreachable from the
	# segment entry: only the split's second search reaches it.
	var maps: Dictionary = _maps()
	var dungeon: OverworldMap = maps["map_paris_dungeon_placeholder"]
	var cfg := OverworldConfig.new()
	var grid: WalkGrid = BypassSearch.banded_grid(dungeon, cfg)
	var start: Vector2i = grid.cell_of(dungeon.find_entry_point(&"from_segment").ground_position(dungeon))
	var reach: Dictionary = MapStructureValidator.walk_distances(grid, [start])
	var exit_cell: Vector2i = grid.cell_of(dungeon.map_exits()[1].trigger_rect.get_center())
	var errors: PackedStringArray = BypassSearch.check(_record("dungeon"), dungeon, cfg)
	_free(maps)
	assert_bool(reach.has(exit_cell)).is_false()
	assert_array(Array(errors)).is_empty()


func test_a_leg_to_the_counter_fails_when_a_band_covers_its_reach() -> void:
	var maps: Dictionary = _maps()
	var dungeon: OverworldMap = maps["map_paris_dungeon_placeholder"]
	_symbol(dungeon, "sym_dungeon_clerks_first_room").patrol_path = \
			PackedVector2Array([Vector2(9.5, 13.5), Vector2(9.5, 15.5)])
	var errors: PackedStringArray = BypassSearch.check(_record("dungeon"), dungeon, OverworldConfig.new())
	_free(maps)
	assert_str(", ".join(errors)).contains("dungeon_to_counter")


func _symbol(map: OverworldMap, symbol_id: String) -> EncounterSymbol:
	for sym: EncounterSymbol in map.symbol_markers():
		if sym.symbol_id == symbol_id:
			return sym
	return null


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
