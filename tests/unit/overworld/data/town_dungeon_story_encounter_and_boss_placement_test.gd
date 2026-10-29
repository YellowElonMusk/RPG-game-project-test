## Story 075, AC-30b (GDD rules 11, 13, 13a): Town has 0 symbols and the
## region default camp; the dungeon's first room holds a CampSpot and the
## story encounter, in front of its checkpoint, telegraphed from the camp's
## safe-zone edge, with its return marker in range on the camp side; the
## boss stands clear of every safe-zone source. `MapStructureValidator`
## passes the shipped maps and names each broken placement.
extends GdUnitTestSuite

const _PATHS: Array[String] = [
	"res://data/maps/paris_town_placeholder.tscn",
	"res://data/maps/paris_segment_placeholder.tscn",
	"res://data/maps/paris_dungeon_placeholder.tscn",
	"res://data/maps/paris_boss_chamber_placeholder.tscn",
]
const _TOWN: String = "map_paris_town_placeholder"
const _DUNGEON: String = "map_paris_dungeon_placeholder"
const _BOSS: String = "map_paris_boss_chamber_placeholder"


func test_shipped_maps_pass_the_structure_rules() -> void:
	var maps: Dictionary = _maps()
	var errors: PackedStringArray = MapStructureValidator.validate(maps, OverworldConfig.new(),
			PresentationConfig.new())
	var town: OverworldMap = maps[_TOWN]
	var dungeon: OverworldMap = maps[_DUNGEON]
	var town_symbols: int = town.symbol_markers().size()
	var town_default: bool = town.camp_spots().size() == 1 and town.camp_spots()[0].is_region_default
	var dungeon_camps: int = dungeon.camp_spots().size()
	var story: EncounterSymbol = _story(maps)
	var story_static: bool = story.is_static and story.start_on == EncounterSymbol.StartOn.CONFIRM
	_free(maps)
	assert_array(Array(errors)).is_empty()
	assert_int(town_symbols).is_equal(0)
	assert_bool(town_default).is_true()
	assert_int(dungeon_camps).is_equal(1)
	assert_bool(story_static).is_true()


func test_town_with_a_symbol_is_reported() -> void:
	var maps: Dictionary = _maps()
	var sym := EncounterSymbol.new()
	sym.encounter_id = "enc_paris_clerks_west"
	sym.patrol_path = PackedVector2Array([Vector2(5.5, 5.5)])
	(maps[_TOWN] as OverworldMap).add_child(sym)
	var errors: PackedStringArray = _validate(maps)
	_free(maps)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains(_TOWN).contains("region default camp")


func test_story_encounter_beyond_story_sight_is_reported() -> void:
	var maps: Dictionary = _maps()
	var cfg := OverworldConfig.new()
	cfg.story_sight_m = 0.5
	var errors: PackedStringArray = MapStructureValidator.validate(maps, cfg, PresentationConfig.new())
	_free(maps)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("story_sight_m").contains("sym_paris_permit_counter")


func test_story_encounter_off_screen_from_the_camp_edge_is_reported() -> void:
	var maps: Dictionary = _maps()
	var low := PresentationConfig.new()
	low.follow_camera_height = 2.0
	var errors: PackedStringArray = MapStructureValidator.validate(maps, OverworldConfig.new(), low)
	_free(maps)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("camera shows")


func test_return_marker_out_of_range_or_on_the_far_side_is_reported() -> void:
	var cfg := OverworldConfig.new()
	var maps: Dictionary = _maps()
	var story: EncounterSymbol = _story(maps)
	var pos: Vector2 = story.patrol_path[0]
	# Just past the far bound, toward the camp.
	story.return_marker = pos + Vector2(0, 1) * (cfg.interact_reach_m * 3.0 + 0.05)
	var too_far: PackedStringArray = _validate(maps)
	# In range, but on the boom side (away from the camp).
	story.return_marker = pos + Vector2(0, -2.0)
	var wrong_side: PackedStringArray = _validate(maps)
	# Just inside the near bound.
	story.return_marker = pos + Vector2(0, 1) * (cfg.return_safe_radius_m + cfg.body_radius - 0.05)
	var too_near: PackedStringArray = _validate(maps)
	_free(maps)
	assert_int(too_far.size()).is_equal(1)
	assert_str(too_far[0]).contains("return marker is")
	assert_bool(wrong_side.size() >= 1).is_true()
	assert_str(", ".join(wrong_side)).contains("not on the camp side")
	assert_int(too_near.size()).is_equal(1)
	assert_str(too_near[0]).contains("return marker is")


func test_story_encounter_not_in_front_of_its_checkpoint_is_reported() -> void:
	var maps: Dictionary = _maps()
	var story: EncounterSymbol = _story(maps)
	story.patrol_path = PackedVector2Array([Vector2(3.5, 15.5)])
	story.return_marker = Vector2(3.5, 18.0)
	var errors: PackedStringArray = _validate(maps)
	_free(maps)
	assert_str(", ".join(errors)).contains("not on a cell in front of checkpoint")


func test_story_encounter_behind_its_checkpoint_is_not_in_the_first_room() -> void:
	var maps: Dictionary = _maps()
	var story: EncounterSymbol = _story(maps)
	story.patrol_path = PackedVector2Array([Vector2(7.5, 10.5)])  # north of the boom
	story.return_marker = Vector2(7.5, 8.0)
	var errors: PackedStringArray = _validate(maps)
	_free(maps)
	assert_str(", ".join(errors)).contains("first room")


func test_boss_too_close_to_a_safe_zone_source_is_reported() -> void:
	var cfg := OverworldConfig.new()
	var maps: Dictionary = _maps()
	var chamber: OverworldMap = maps[_BOSS]
	var entry: Vector2 = chamber.entry_points()[0].ground_position(chamber)
	var boss: EncounterSymbol = chamber.symbol_markers()[0]
	var min_d: float = cfg.safe_radius_m + 2.0 * cfg.body_radius + 1.0
	# Just inside the minimum distance, straight up from the entry.
	boss.patrol_path = PackedVector2Array([entry + Vector2(0, -(min_d - 0.05))])
	var errors: PackedStringArray = _validate(maps)
	_free(maps)
	assert_str(", ".join(errors)).contains("boss 'sym_paris_supervisor'").contains("safe-zone source")


func test_visibility_edge_matches_the_gdd_example() -> void:
	# GDD chase_visibility example: h 10 m, pitch 30, F_v 20, dz 10 %, tau
	# 0.17, walk_speed 3.5 -- the near edge at 16:9 is 5.40 - 0.54 - 0.595.
	var p := PresentationConfig.new()
	p.follow_camera_height = 10.0
	var near: float = ChaseVisibility.edge_reach_at(Vector2(0, 1), p, 3.5, 16.0 / 9.0)
	var far: float = ChaseVisibility.edge_reach_at(Vector2(0, -1), p, 3.5, 16.0 / 9.0)
	assert_float(near).is_equal_approx(4.27, 0.01)
	assert_float(far).is_greater(near)


func _validate(maps: Dictionary) -> PackedStringArray:
	return MapStructureValidator.validate(maps, OverworldConfig.new(), PresentationConfig.new())


func _story(maps: Dictionary) -> EncounterSymbol:
	for sym: EncounterSymbol in (maps[_DUNGEON] as OverworldMap).symbol_markers():
		if sym.is_static:
			return sym
	return null


func _maps() -> Dictionary:
	var maps: Dictionary = {}
	for path: String in _PATHS:
		var map: OverworldMap = (load(path) as PackedScene).instantiate() as OverworldMap
		maps[map.map_id] = map
	return maps


func _free(maps: Dictionary) -> void:
	for map: OverworldMap in maps.values():
		map.free()
