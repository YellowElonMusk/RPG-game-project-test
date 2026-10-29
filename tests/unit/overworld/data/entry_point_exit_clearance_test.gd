## Story 080, AC-30f (GDD rule 11, map exits): every EntryPoint lies at least
## `body_radius + entry_clearance_m` outside every MapExit rectangle on its
## map and faces into the map, so a held `move` on arrival never bounces the
## leader straight back out. Checked by `MapValidator` (run in CI by
## `tools/ci/validate_maps.gd`); each failure names the map, the EntryPoint
## and the exit.
extends GdUnitTestSuite

const _TOWN: String = "res://data/maps/paris_town_placeholder.tscn"
const _SEG: String = "res://data/maps/paris_segment_placeholder.tscn"
const _SEG_ID: String = "map_paris_segment_placeholder"


func test_shipped_entry_points_clear_every_exit_and_face_in() -> void:
	var cfg := OverworldConfig.new()
	var maps: Dictionary = _maps()
	var checked: int = 0
	for map: OverworldMap in maps.values():
		for entry: EntryPoint in map.entry_points():
			for exit: MapExit in map.map_exits():
				var dist: float = MapValidator.distance_to_rect(entry.ground_position(map), exit.trigger_rect)
				assert_float(dist).override_failure_message("%s: %s is %.2f m from %s"
						% [map.map_id, entry.marker_id, dist, exit.marker_id]) \
						.is_greater_equal(cfg.body_radius + cfg.entry_clearance_m)
				checked += 1
	var errors: PackedStringArray = MapValidator.validate_maps(maps, cfg)
	_free(maps)
	assert_int(checked).is_greater(0)
	assert_array(Array(errors)).is_empty()


func test_entry_exactly_at_clearance_passes() -> void:
	var cfg := OverworldConfig.new()
	var maps: Dictionary = _maps()
	# At the boundary to float precision: `dist - body_radius + body_radius`
	# may round one ulp above `dist`.
	cfg.entry_clearance_m = _seg_entry_distance(maps) - cfg.body_radius - 1e-6
	var errors: PackedStringArray = MapValidator.validate_maps(maps, cfg)
	_free(maps)
	assert_array(Array(errors)).is_empty()


func test_entry_inside_clearance_is_reported_naming_both_markers() -> void:
	var cfg := OverworldConfig.new()
	var maps: Dictionary = _maps()
	var seg: OverworldMap = maps[_SEG_ID]
	var entry_id: StringName = seg.entry_points()[0].marker_id
	var exit_id: StringName = seg.map_exits()[0].marker_id
	# Non-default config: a clearance just past the authored distance fails.
	cfg.entry_clearance_m = _seg_entry_distance(maps) - cfg.body_radius + 0.1
	var errors: PackedStringArray = MapValidator.validate_maps(maps, cfg)
	_free(maps)
	# Other maps' entries may sit at the same authored distance; only the
	# segment's pair is the subject here.
	var named: Array[String] = []
	for err: String in errors:
		if err.begins_with(_SEG_ID) and err.contains("'%s'" % entry_id) \
				and err.contains("'%s'" % exit_id):
			named.append(err)
	assert_int(named.size()).is_equal(1)


func test_entry_inside_a_second_exit_is_reported_against_that_exit() -> void:
	var maps: Dictionary = _maps()
	var seg: OverworldMap = maps[_SEG_ID]
	var pos: Vector2 = seg.entry_points()[0].ground_position(seg)
	var trap := MapExit.new()
	trap.marker_id = &"exit_fixture_trap"
	trap.target_map_id = "map_paris_town_placeholder"
	trap.target_entry_id = (maps["map_paris_town_placeholder"] as OverworldMap).entry_points()[0].marker_id
	trap.trigger_rect = Rect2(pos - Vector2(0.5, 0.5), Vector2(1.0, 1.0))
	seg.add_child(trap)
	var errors: PackedStringArray = MapValidator.validate_maps(maps, OverworldConfig.new())
	_free(maps)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("exit_fixture_trap").contains("0.00 m")


func test_entry_facing_a_wall_is_reported() -> void:
	var maps: Dictionary = _maps()
	var seg: OverworldMap = maps[_SEG_ID]
	seg.entry_points()[0].facing = Vector2.ZERO
	var errors: PackedStringArray = MapValidator.validate_maps(maps, OverworldConfig.new())
	_free(maps)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("does not face")


func test_distance_to_rect_is_zero_inside_and_euclidean_outside() -> void:
	var rect := Rect2(1, 1, 2, 2)
	assert_float(MapValidator.distance_to_rect(Vector2(2, 2), rect)).is_equal(0.0)
	assert_float(MapValidator.distance_to_rect(Vector2(3, 2), rect)).is_equal(0.0)
	assert_float(MapValidator.distance_to_rect(Vector2(6, 7), rect)).is_equal_approx(5.0, 0.0001)


## The segment's first EntryPoint's distance to its first MapExit rectangle.
func _seg_entry_distance(maps: Dictionary) -> float:
	var seg: OverworldMap = maps[_SEG_ID]
	return MapValidator.distance_to_rect(seg.entry_points()[0].ground_position(seg),
			seg.map_exits()[0].trigger_rect)


## Every shipped map: exits are checked against their targets, so the
## segment needs the dungeon, and the dungeon the boss chamber.
func _maps() -> Dictionary:
	var maps: Dictionary = {}
	for path: String in [_TOWN, _SEG, "res://data/maps/paris_dungeon_placeholder.tscn",
			"res://data/maps/paris_boss_chamber_placeholder.tscn"]:
		var map: OverworldMap = (load(path) as PackedScene).instantiate() as OverworldMap
		maps[map.map_id] = map
	return maps


func _free(maps: Dictionary) -> void:
	for map: OverworldMap in maps.values():
		map.free()
