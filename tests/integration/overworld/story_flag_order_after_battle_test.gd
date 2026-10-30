## Story 092, AC-34 (GDD rule 14): a Victory that sets a liberation and a
## story flag applies them in a fixed order. 1. The liberation state is
## written in `on_thawed`. 2. The on-screen removal starts on
## `transition_finished`. 3. The battle's Dialogue opens after the removal
## ends. 4. The stage effect appears only on the next load. The fixture map
## record raises the stage on the Victory's clue flag so step 4 is
## observable.
extends GdUnitTestSuite

const GameStateFixtures := preload("res://tests/unit/game_state/doubles/game_state_fixtures.gd")
const _CLERK: String = "enc_paris_clerks_east"
const _SEGMENT_ID: String = "map_paris_segment_placeholder"
const _STORY_FLAG: String = "rumour:permit_binds_both_sides"
## Beside the segment queue (19.5, 10.5): it is on screen.
const _LEADER: Vector2 = Vector2(17.5, 10.5)
const _DT: float = 1.0 / 60.0


func test_liberation_removal_dialogue_and_stage_happen_in_order() -> void:
	var machine: GameStateMachine = GameStateFixtures.make_machine_in_overworld()["machine"]
	var catalog: RecordCatalogDouble = _catalog()
	var mode: OverworldMode = _mode(machine, catalog)
	mode.config.liberation_duration_s = 30.0  # outlasts the payoff card
	var queue: GagInteractable = _queue(mode)
	assert_int(mode.current_stage).is_equal(2)

	# 1. on_thawed writes the liberation (and the story flag); nothing plays.
	mode.on_thawed(_CLERK, GameStateMachine.BattleResult.VICTORY)
	assert_bool(mode.world_state.is_liberated(_SEGMENT_ID, &"poster_permit_queue")).is_true()
	assert_bool(mode.world_state.has_flag(_STORY_FLAG)).is_true()
	assert_bool(mode.is_removing(queue)).is_true()
	mode.tick_timed_text(60.0)  # time before the reveal does not run the removal
	assert_bool(mode.is_removing(queue)).is_true()
	assert_array(mode.lines_said).is_empty()

	# 2. The removal starts on transition_finished.
	machine.transition_finished.emit(GameStateMachine.Mode.OVERWORLD)
	mode.tick_timed_text(mode.config.liberation_duration_s - _DT)
	assert_bool(mode.is_removing(queue)).is_true()
	# 3. The Dialogue waits for the removal's end.
	assert_array(mode.lines_said).is_empty()
	mode.tick_timed_text(2.0 * _DT)
	assert_bool(mode.is_removing(queue)).is_false()
	assert_int(mode.lines_said.size()).is_equal(1)
	assert_str(mode.lines_said[0]).contains("binds the Clerks too")

	# 4. The stage is unchanged this visit; the next load raises it.
	assert_int(mode.current_stage).is_equal(2)
	var next: OverworldMode = _mode(machine, catalog, mode.world_state)
	assert_int(next.current_stage).is_equal(3)


func _queue(mode: OverworldMode) -> GagInteractable:
	for gag: GagInteractable in mode.get_map().gags():
		if gag.marker_id == &"poster_permit_queue":
			return gag
	return null


func _catalog() -> RecordCatalogDouble:
	var catalog := RecordCatalogDouble.new()
	var rec: MapData = (load("res://data/maps/%s.tres" % _SEGMENT_ID) as MapData).duplicate()
	rec.stage_table = {"permits_mandatory": 2, _STORY_FLAG: 3}
	catalog.add(&"map", rec)
	for f: String in DirAccess.get_files_at("res://data/encounters"):
		if f.ends_with(".tres"):
			catalog.add(&"encounter", load("res://data/encounters/" + f))
	# The east Clerk's shipped payoff is now `open` (story 051); this test needs
	# a Victory that sets a story flag with a Dialogue, so its copy is a clue.
	var east: EncounterData = (catalog.get_record(&"encounter", _CLERK) as EncounterData).duplicate()
	east.victory_payoff = {"type": "clue", "facet": "permit_binds_both_sides",
			"text": "Rumour: the Permit Ban binds the Clerks too. They wait, same as you."}
	catalog.add(&"encounter", east)
	return catalog


func _mode(machine: GameStateMachine, catalog: RecordCatalogDouble, ws: WorldState = null) -> OverworldMode:
	var mode := OverworldMode.new()
	mode.config = OverworldConfig.new()
	mode.setup(machine, null)
	if ws == null:
		ws = WorldState.new()
		ws.set_flag("permits_mandatory")
	else:
		ws.on_map_entered("map_paris_town_placeholder", WorldState.EntryKind.MAP_ENTRY)
	mode.world_state = ws
	mode.encounter_catalog = catalog
	auto_free(mode)
	mode.load_map((load(ProbeFixture.SEGMENT) as PackedScene).instantiate() as OverworldMap)
	mode.tick_timed_text(60.0)  # let the name card clear
	mode.set_leader_position(_LEADER)
	return mode
