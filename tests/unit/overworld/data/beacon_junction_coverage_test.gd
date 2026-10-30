## Story 110, AC-45f (GDD rule 19 "Junctions" and the beacon chain): every
## leg's junction nodes (its start EntryPoint, one per room it crosses, one
## at every branch cell toward another end) cover its `L_crit` path at every
## reachable configuration derived from the step list; every leg ends in a
## beacon; I18 holds for the shipped config.
extends GdUnitTestSuite

const _MAPS: Array[String] = ["town", "segment", "dungeon", "boss_chamber"]
const _DUNGEON: String = "map_paris_dungeon_placeholder"


func test_shipped_maps_cover_every_leg_at_every_reachable_stage() -> void:
	var maps: Dictionary = _maps()
	var steps: ChapterSteps = _steps()
	var out: Dictionary = BeaconJunctions.check(steps, _records(), maps, OverworldConfig.new())
	_free(maps)
	# O-04 denominator guard: an empty population is NOT ASSESSED, never a pass.
	var legs: Dictionary = {}
	for step: ChapterStep in steps.steps:
		legs["%s:%s" % [step.map_id, step.leg_id]] = true
	assert_int(legs.size()).is_greater_equal(7)
	assert_int((out["assessed"] as Array).size()).is_equal(steps.steps.size())
	for key: String in legs:
		var found: bool = false
		for a: String in out["assessed"]:
			found = found or a.begins_with(key + "@")
		assert_bool(found).override_failure_message("NOT ASSESSED: " + key).is_true()
	assert_array(Array(out["errors"])).is_empty()


func test_reachable_configs_come_from_the_step_list() -> void:
	var steps: ChapterSteps = _steps()
	var records: Dictionary = _records()
	var configs: Dictionary = BeaconJunctions.reachable_configs(steps, records)
	var flags: Array = []
	var last_act: bool = false
	for step: ChapterStep in steps.steps:
		for f: String in step.flags_on_enter:
			if not flags.has(f):
				flags.append(f)
		last_act = last_act or step.id == steps.last_act_from
		var key: String = "%s:%s" % [step.map_id, step.leg_id]
		assert_bool(configs.has(key)).is_true()
		var lib: String = (records[step.map_id] as MapData).region_liberation_flag
		var expect_lib: bool = last_act and not lib.is_empty()
		var any_match: bool = false
		for on: Array in configs[key]:
			var ok: bool = on.has(lib) == expect_lib
			for f: String in flags:
				ok = ok and on.has(f)
			any_match = any_match or ok
		assert_bool(any_match).override_failure_message(key).is_true()
	var empty := ChapterSteps.new()
	assert_dict(BeaconJunctions.reachable_configs(empty, records)).is_empty()


func test_empty_step_list_assesses_nothing() -> void:
	var maps: Dictionary = _maps()
	var out: Dictionary = BeaconJunctions.check(ChapterSteps.new(), _records(), maps, OverworldConfig.new())
	_free(maps)
	assert_array(out["assessed"] as Array).is_empty()


func test_branch_cell_without_junction_names_map_leg_and_cell() -> void:
	var maps: Dictionary = _maps()
	var dungeon: OverworldMap = maps[_DUNGEON]
	_remove(dungeon, "JunctionCounterFork")
	var errors: PackedStringArray = BeaconJunctions.check(_steps(), _records(), maps, OverworldConfig.new())["errors"]
	_free(maps)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains(_DUNGEON).contains("dungeon_to_boss") \
			.contains("(17, 25)").contains("sym_paris_permit_counter")


func test_room_without_junction_is_reported() -> void:
	var maps: Dictionary = _maps()
	_remove(maps[_DUNGEON], "JunctionBeyondBoom")
	var errors: PackedStringArray = BeaconJunctions.check(_steps(), _records(), maps, OverworldConfig.new())["errors"]
	_free(maps)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains(_DUNGEON).contains("dungeon_to_boss").contains("room at cell")


func test_leg_without_beacon_is_reported() -> void:
	var maps: Dictionary = _maps()
	_remove(maps["map_paris_town_placeholder"], "BeaconTownOut")
	var errors: PackedStringArray = BeaconJunctions.check(_steps(), _records(), maps, OverworldConfig.new())["errors"]
	_free(maps)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("map_paris_town_placeholder").contains("town_out").contains("no beacon")


func test_last_beacon_off_the_leg_end_is_reported() -> void:
	var maps: Dictionary = _maps()
	var town: OverworldMap = maps["map_paris_town_placeholder"]
	var beacon: WaypointBeacon = town.get_node(^"BeaconTownOut") as WaypointBeacon
	beacon.position = Vector3(10.5, 0.0, 5.5)
	var errors: PackedStringArray = BeaconJunctions.check(_steps(), _records(), maps, OverworldConfig.new())["errors"]
	_free(maps)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("town_out").contains("(10, 5)").contains("exit_to_segment")


func test_junction_cover_radius_follows_config() -> void:
	# The counter fork junction moved one cell east of its branch cell.
	for cover_cells: float in [1.5, 0.5]:
		var cfg := OverworldConfig.new()
		cfg.junction_cover_m = cover_cells * cfg.cell_m
		var maps: Dictionary = _maps()
		var jn: JunctionNode = (maps[_DUNGEON] as OverworldMap).get_node(^"JunctionCounterFork") as JunctionNode
		jn.position.x += cfg.cell_m
		var errors: PackedStringArray = BeaconJunctions.check(_steps(), _records(), maps, cfg)["errors"]
		_free(maps)
		var offset: float = cfg.cell_m
		assert_int(errors.size()).is_equal(0 if offset <= cfg.junction_cover_m else 1)


func test_marker_naming_unknown_leg_is_reported() -> void:
	var maps: Dictionary = _maps()
	var jn: JunctionNode = (maps[_DUNGEON] as OverworldMap).get_node(^"JunctionCounterFork") as JunctionNode
	jn.leg_id = "no_such_leg"
	var errors: PackedStringArray = BeaconJunctions.check_marker_legs(_records()[_DUNGEON], maps[_DUNGEON])
	_free(maps)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("jn_dungeon_counter_fork").contains("no_such_leg")


func test_i18_holds_for_shipped_config_and_fixture_breaks_it() -> void:
	var cfg := OverworldConfig.new()
	assert_bool(cfg.beacon_h_m >= cfg.wall_h_max + 0.5).is_true()
	for err: String in cfg.validate():
		assert_str(err).not_contains("I18")
	var bad := OverworldConfig.new()
	bad.beacon_h_m = 3.0
	bad.wall_h_max = 3.0
	var found: bool = false
	for err: String in bad.validate():
		found = found or err.contains("I18")
	assert_bool(found).is_true()


func _steps() -> ChapterSteps:
	return load(OverworldConfig.new().chapter_steps_path) as ChapterSteps


func _records() -> Dictionary:
	var out: Dictionary = {}
	for n: String in _MAPS:
		var rec: MapData = load("res://data/maps/map_paris_%s_placeholder.tres" % n) as MapData
		out[rec.id] = rec
	return out


func _maps() -> Dictionary:
	var out: Dictionary = {}
	for n: String in _MAPS:
		var map: OverworldMap = (load("res://data/maps/paris_%s_placeholder.tscn" % n) as PackedScene) \
				.instantiate() as OverworldMap
		out[map.map_id] = map
	return out


func _remove(map: OverworldMap, node_name: String) -> void:
	var node: Node = map.get_node(NodePath(node_name))
	map.remove_child(node)
	node.free()


func _free(maps: Dictionary) -> void:
	for map: OverworldMap in maps.values():
		map.free()
