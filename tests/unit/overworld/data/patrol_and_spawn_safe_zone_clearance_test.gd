## Story 077, AC-30c (GDD rule 12 "Safe zones"): no spawn point or patrol
## segment (a loop's closing segment included) lies within `safe_radius_m`
## of an EntryPoint or CampSpot (segment to point) or a MapExit rectangle
## (segment to rectangle), or within `symbol_chase_m + body_radius` of a
## return marker. The shipped maps pass; each violation is named with the
## symbol, its segment and the margin. Static symbols are exempt.
extends GdUnitTestSuite

const _PATHS: Array[String] = [
	"res://data/maps/paris_town_placeholder.tscn",
	"res://data/maps/paris_segment_placeholder.tscn",
	"res://data/maps/paris_dungeon_placeholder.tscn",
	"res://data/maps/paris_boss_chamber_placeholder.tscn",
]
const _DUNGEON: String = "map_paris_dungeon_placeholder"


func test_shipped_patrols_clear_every_safe_zone() -> void:
	var maps: Dictionary = _maps()
	var patrols: int = 0
	for map: OverworldMap in maps.values():
		for sym: EncounterSymbol in map.symbol_markers():
			if not sym.is_static:
				patrols += 1
	var errors: PackedStringArray = _validate(maps)
	_free(maps)
	assert_int(patrols).is_greater_equal(4)
	assert_array(Array(errors)).is_empty()


func test_segment_inside_an_entry_point_margin_is_reported() -> void:
	var cfg := OverworldConfig.new()
	var maps: Dictionary = _maps()
	var dungeon: OverworldMap = maps[_DUNGEON]
	var entry: Vector2 = dungeon.find_entry_point(&"from_boss_chamber").ground_position(dungeon)
	# A horizontal segment passing just inside the radius below the entry.
	var y: float = entry.y + cfg.safe_radius_m - 0.05
	_hall(dungeon).patrol_path = PackedVector2Array([Vector2(entry.x - 3.0, y), Vector2(entry.x + 3.0, y)])
	var errors: PackedStringArray = _validate(maps)
	_free(maps)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("sym_dungeon_clerks_hall").contains("EntryPoint 'from_boss_chamber'")


func test_segment_just_outside_the_margin_passes() -> void:
	var cfg := OverworldConfig.new()
	var maps: Dictionary = _maps()
	var dungeon: OverworldMap = maps[_DUNGEON]
	var entry: Vector2 = dungeon.find_entry_point(&"from_boss_chamber").ground_position(dungeon)
	var y: float = entry.y + cfg.safe_radius_m + 0.05
	_hall(dungeon).patrol_path = PackedVector2Array([Vector2(entry.x - 3.0, y), Vector2(entry.x + 3.0, y)])
	var errors: PackedStringArray = _validate(maps)
	_free(maps)
	assert_array(Array(errors)).is_empty()


func test_loop_closing_segment_is_checked() -> void:
	var maps: Dictionary = _maps()
	var dungeon: OverworldMap = maps[_DUNGEON]
	var hall: EncounterSymbol = _hall(dungeon)
	# Both open legs clear the boss-chamber entry at (17, 3.5); the leg from
	# (22, 5) back to (11, 9.5) passes about 3.5 m from it.
	hall.patrol_path = PackedVector2Array([Vector2(11.0, 9.5), Vector2(22.0, 9.5), Vector2(22.0, 5.0)])
	hall.path_mode = SymbolBrain.PathMode.PINGPONG
	var pingpong_errors: PackedStringArray = _validate(maps)
	hall.path_mode = SymbolBrain.PathMode.LOOP
	var loop_errors: PackedStringArray = _validate(maps)
	_free(maps)
	assert_array(Array(pingpong_errors)).is_empty()
	assert_int(loop_errors.size()).is_greater_equal(1)
	for err: String in loop_errors:
		assert_str(err).contains("closing segment")
	assert_str(", ".join(loop_errors)).contains("EntryPoint 'from_boss_chamber'")


func test_spawn_point_near_an_exit_rectangle_is_reported() -> void:
	var maps: Dictionary = _maps()
	var dungeon: OverworldMap = maps[_DUNGEON]
	var rect: Rect2 = dungeon.map_exits()[1].trigger_rect  # exit_to_boss_chamber
	_hall(dungeon).patrol_path = PackedVector2Array([rect.get_center() + Vector2(4.0, 2.0)])
	var errors: PackedStringArray = _validate(maps)
	_free(maps)
	assert_str(", ".join(errors)).contains("spawn point").contains("MapExit 'exit_to_boss_chamber'")


func test_patrol_near_a_return_marker_uses_the_chase_margin() -> void:
	var cfg := OverworldConfig.new()
	var maps: Dictionary = _maps()
	var dungeon: OverworldMap = maps[_DUNGEON]
	var first_room: EncounterSymbol = null
	for sym: EncounterSymbol in dungeon.symbol_markers():
		if sym.symbol_id == "sym_dungeon_clerks_first_room":
			first_room = sym
	var marker: Vector2 = dungeon.find_checkpoint(&"cp_permit_boom").return_marker
	var x: float = marker.x + cfg.symbol_chase_m + cfg.body_radius - 0.05
	first_room.patrol_path = PackedVector2Array([Vector2(x, 14.0), Vector2(x, marker.y + 0.5)])
	var errors: PackedStringArray = _validate(maps)
	_free(maps)
	assert_str(", ".join(errors)).contains("return marker of")


func test_static_symbols_are_exempt() -> void:
	var maps: Dictionary = _maps()
	var errors: PackedStringArray = PackedStringArray()
	var dungeon: OverworldMap = maps[_DUNGEON]
	# The Permit Counter stands 2 m from its own return marker by design.
	MapStructureValidator._check_patrol_clearance(dungeon, OverworldConfig.new(), errors)
	_free(maps)
	assert_array(Array(errors)).is_empty()


func test_segment_rect_distance() -> void:
	var rect := Rect2(0, 0, 2, 2)
	assert_float(MapStructureValidator.segment_rect_distance(Vector2(5, 1), Vector2(5, 3), rect)).is_equal_approx(3.0, 1e-6)
	assert_float(MapStructureValidator.segment_rect_distance(Vector2(-1, 1), Vector2(3, 1), rect)).is_equal(0.0)
	# The segment lies on x + y = 11; its nearest point to corner (2, 2) is
	# (5.5, 5.5), at 7 / sqrt(2).
	assert_float(MapStructureValidator.segment_rect_distance(Vector2(5, 6), Vector2(6, 5), rect)) \
			.is_equal_approx(7.0 / sqrt(2.0), 1e-5)


func _hall(dungeon: OverworldMap) -> EncounterSymbol:
	for sym: EncounterSymbol in dungeon.symbol_markers():
		if sym.symbol_id == "sym_dungeon_clerks_hall":
			return sym
	return null


func _validate(maps: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for map: OverworldMap in maps.values():
		MapStructureValidator._check_patrol_clearance(map, OverworldConfig.new(), errors)
	return errors


func _maps() -> Dictionary:
	var maps: Dictionary = {}
	for path: String in _PATHS:
		var map: OverworldMap = (load(path) as PackedScene).instantiate() as OverworldMap
		maps[map.map_id] = map
	return maps


func _free(maps: Dictionary) -> void:
	for map: OverworldMap in maps.values():
		map.free()
