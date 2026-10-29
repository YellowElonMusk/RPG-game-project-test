## Story 082, AC-30h (GDD rule 5 patrol legality): every cell a patrol
## sweeps within `body_radius` (a loop's closing segment included) and its
## origin cell are symbol-legal. The shipped maps pass; a segment through a
## wall, an origin in a `SAFE` cell, a body grazing a wall and a loop whose
## closing leg crosses a wall are each named. Uses the segment's wall block
## at cells (10..11, 7..9).
extends GdUnitTestSuite

const _NAMES: Array[String] = ["town", "segment", "dungeon", "boss_chamber"]
const _SEGMENT: String = "map_paris_segment_placeholder"


func test_shipped_patrols_are_legal() -> void:
	var maps: Dictionary = _maps()
	var errors: PackedStringArray = _validate(maps)
	_free(maps)
	assert_array(Array(errors)).is_empty()


func test_segment_through_a_wall_is_reported() -> void:
	var errors: PackedStringArray = _with_path(
			PackedVector2Array([Vector2(9.6, 7.5), Vector2(13.5, 7.5)]))
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("(10, 7)").contains("blocked")


func test_origin_in_a_safe_cell_is_reported() -> void:
	# Beside the from_town EntryPoint at (4.5, 8.5).
	var errors: PackedStringArray = _with_path(
			PackedVector2Array([Vector2(5.5, 10.5), Vector2(5.5, 11.5)]))
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("(5, 10)").contains("SAFE")


func test_body_radius_sweep_counts_a_grazed_wall() -> void:
	var cfg := OverworldConfig.new()
	# A short run alongside the wall cell (10, 7), whose west edge is x = 10.
	var grazing: float = 10.0 - (cfg.body_radius - 0.05)
	var clear: float = 10.0 - (cfg.body_radius + 0.05)
	var hit: PackedStringArray = _with_path(PackedVector2Array([Vector2(grazing, 7.4), Vector2(grazing, 7.6)]))
	var miss: PackedStringArray = _with_path(PackedVector2Array([Vector2(clear, 7.4), Vector2(clear, 7.6)]))
	assert_int(hit.size()).is_equal(1)
	assert_str(hit[0]).contains("(10, 7)")
	assert_array(Array(miss)).is_empty()


func test_loop_closing_segment_is_swept() -> void:
	# Open legs run round the wall block; only the loop's closing leg cuts
	# back through it.
	var path := PackedVector2Array([Vector2(9.5, 6.5), Vector2(12.5, 6.5), Vector2(12.5, 10.5)])
	var pingpong: PackedStringArray = _with_path(path, SymbolBrain.PathMode.PINGPONG)
	var loop: PackedStringArray = _with_path(path, SymbolBrain.PathMode.LOOP)
	assert_array(Array(pingpong)).is_empty()
	assert_int(loop.size()).is_equal(1)
	assert_str(loop[0]).contains("blocked")


## Validates the segment with its first Clerk's patrol replaced by `path`.
func _with_path(path: PackedVector2Array,
		mode: SymbolBrain.PathMode = SymbolBrain.PathMode.PINGPONG) -> PackedStringArray:
	var maps: Dictionary = _maps()
	var sym: EncounterSymbol = (maps[_SEGMENT] as OverworldMap).symbol_markers()[0]
	sym.patrol_path = path
	sym.path_mode = mode
	var errors := PackedStringArray()
	MapStructureValidator._check_patrol_legality(maps[_SEGMENT], OverworldConfig.new(), errors)
	_free(maps)
	return errors


func _validate(maps: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for map: OverworldMap in maps.values():
		MapStructureValidator._check_patrol_legality(map, OverworldConfig.new(), errors)
	return errors


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
