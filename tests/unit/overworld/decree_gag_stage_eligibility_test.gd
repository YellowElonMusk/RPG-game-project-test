## Story 056, AC-23c (GDD rule 8): a decree gag is active only at or above
## its stage, never blocks a cell, is eligible for `confirm` (and repeats its
## text), and is inactive once the map's `region_liberation_flag` is set. A
## first-sight decree (rule 13a) turns on when its symbol is first on screen.
## Stage caps do not exist yet (story 058), so "not counted against any cap"
## has nothing to count against.
extends GdUnitTestSuite

const _SEGMENT: String = "res://data/maps/paris_segment_placeholder.tscn"
const _DUNGEON: String = "res://data/maps/paris_dungeon_placeholder.tscn"


func test_inactive_below_its_stage() -> void:
	var mode: OverworldMode = _mode(_SEGMENT, [])
	assert_int(mode.current_stage).is_equal(1)
	var decree: GagInteractable = _decree(mode)
	assert_bool(mode.is_gag_active(decree)).is_false()
	_stand_at(mode, decree)
	assert_bool(mode.probe() == decree).is_false()


func test_active_at_its_stage_eligible_and_repeating() -> void:
	var mode: OverworldMode = _mode(_SEGMENT, ["permits_mandatory"])
	assert_int(mode.current_stage).is_equal(2)
	var decree: GagInteractable = _decree(mode)
	assert_bool(mode.is_gag_active(decree)).is_true()
	_stand_at(mode, decree)
	assert_bool(mode.probe() == decree).is_true()
	mode.handle_action(InputActions.CONFIRM, true)
	(mode.get("_machine") as GameStateMachine).close_overlay()
	mode.handle_action(InputActions.CONFIRM, true)
	assert_array(mode.lines_said).is_equal([decree.text, decree.text])


func test_never_blocks_a_cell() -> void:
	var mode: OverworldMode = _mode(_SEGMENT, ["permits_mandatory"])
	for decree: GagInteractable in mode.get_map().gags():
		if not decree.is_decree():
			continue
		var cell: Vector2i = mode.get_walk_grid().cell_of(decree.ground_position(mode.get_map()))
		var baked: WalkGrid = mode.get_map().bake_walk_grid(mode.config)
		assert_bool(mode.get_walk_grid().is_walkable(cell)).is_equal(baked.is_walkable(cell))


func test_inactive_once_the_region_is_liberated() -> void:
	var mode: OverworldMode = _mode(_SEGMENT, ["permits_mandatory", "paris_liberated"], "paris_liberated")
	assert_bool(mode.is_gag_active(_decree(mode))).is_false()


func test_first_sight_decree_turns_on_when_the_counter_is_seen() -> void:
	var mode: OverworldMode = _mode(_DUNGEON, [])
	var decree: GagInteractable = null
	for gag: GagInteractable in mode.get_map().gags():
		if not gag.decree_first_sight.is_empty():
			decree = gag
	assert_bool(mode.is_gag_active(decree)).is_false()
	var camp: Vector2 = mode.get_map().camp_spots()[0].ground_position(mode.get_map())
	var counter: Vector2 = mode.get_encounter_sources()[0].brain.position
	mode.set_leader_position(camp + (counter - camp).normalized() * (mode.config.safe_radius_m - 0.2))
	mode.step_frame(1.0 / 60.0, Vector2.ZERO)
	assert_bool(mode.is_gag_active(decree)).is_true()


func _decree(mode: OverworldMode) -> GagInteractable:
	for gag: GagInteractable in mode.get_map().gags():
		if gag.decree_stage > 0:
			return gag
	return null


func _stand_at(mode: OverworldMode, gag: GagInteractable) -> void:
	mode.set_leader_position(gag.ground_position(mode.get_map()) + Vector2(0.0, 1.0))
	mode.set_leader_facing(Vector2.UP)


func _mode(scene: String, flags: Array, liberation_flag: String = "") -> OverworldMode:
	var machine: GameStateMachine = ProbeFixture.GameStateFixtures.make_machine_in_overworld()["machine"]
	var mode := OverworldMode.new()
	mode.config = OverworldConfig.new()
	auto_free(mode)
	mode.setup(machine, null)
	mode.world_state = WorldState.new()
	for f: String in flags:
		mode.world_state.set_flag(f)
	var catalog := RecordCatalogDouble.new()
	for name: String in ["segment", "dungeon"]:
		var rec: MapData = (load("res://data/maps/map_paris_%s_placeholder.tres" % name) as MapData).duplicate()
		rec.region_liberation_flag = liberation_flag
		catalog.add(&"map", rec)
	catalog.add(&"encounter", load("res://data/encounters/enc_paris_permit_counter.tres"))
	mode.encounter_catalog = catalog
	mode.load_map((load(scene) as PackedScene).instantiate() as OverworldMap)
	mode.tick_timed_text(60.0)
	return mode
