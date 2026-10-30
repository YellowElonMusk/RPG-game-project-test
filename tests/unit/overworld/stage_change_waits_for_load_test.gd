## Story 054, AC-23 (GDD rule 8): a flag set mid-visit leaves the stage
## unchanged until that map's next load. (Active markers follow the stage;
## stage-gated markers arrive with story 058.)
extends GdUnitTestSuite

const _SEGMENT: String = "res://data/maps/paris_segment_placeholder.tscn"


func test_a_mid_visit_flag_waits_for_the_next_load() -> void:
	var mode: OverworldMode = _mode()
	mode.load_map((load(_SEGMENT) as PackedScene).instantiate() as OverworldMap)
	assert_int(mode.current_stage).is_equal(1)
	mode.world_state.set_flag("permits_mandatory")
	for i: int in 30:
		mode.step_frame(1.0 / 60.0, Vector2.RIGHT)
	assert_int(mode.current_stage).is_equal(1)
	# The next load of the map picks it up.
	mode.world_state.on_map_entered("map_paris_town_placeholder", WorldState.EntryKind.MAP_ENTRY)
	mode.load_map((load(_SEGMENT) as PackedScene).instantiate() as OverworldMap)
	assert_int(mode.current_stage).is_equal(2)
	assert_int(mode.world_state.stage_stored("map_paris_segment_placeholder")).is_equal(2)


func test_a_map_with_no_record_reports_no_stage() -> void:
	var mode: OverworldMode = _mode()
	mode.encounter_catalog = RecordCatalogDouble.new()
	mode.load_map((load(_SEGMENT) as PackedScene).instantiate() as OverworldMap)
	assert_int(mode.current_stage).is_equal(0)


func _mode() -> OverworldMode:
	var machine: GameStateMachine = ProbeFixture.GameStateFixtures.make_machine_in_overworld()["machine"]
	var mode := OverworldMode.new()
	mode.config = OverworldConfig.new()
	auto_free(mode)
	mode.setup(machine, null)
	mode.world_state = WorldState.new()
	var catalog := RecordCatalogDouble.new()
	catalog.add(&"map", load("res://data/maps/map_paris_segment_placeholder.tres"))
	mode.encounter_catalog = catalog
	return mode
