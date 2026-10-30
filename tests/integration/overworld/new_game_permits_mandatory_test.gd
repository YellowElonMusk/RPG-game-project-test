## Story 057, AC-23d (GDD rule 8): on a New Game, `permits_mandatory` is
## set before the first input is accepted, and the overworld segment's first
## load is at stage 2, with its decree gag up at both EntryPoints, whatever
## route the player takes. Beating a symbol, entering a map or registering a
## camp sets no stage-raising flag.
extends GdUnitTestSuite

const _GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const _DT: float = 1.0 / 60.0


func test_new_game_sets_the_flag_before_input_and_the_segment_loads_at_stage_2() -> void:
	var root: GameRoot = _boot()
	(root.current_mode_node() as TitleMode)._on_new_game_pressed()
	# Mid-transition, before any input reaches the Overworld.
	assert_bool(root.world_state.has_flag("permits_mandatory")).is_false()
	root.machine.tick(_DT)
	_run_to_idle(root.machine)
	assert_bool(root.world_state.has_flag("permits_mandatory")).is_true()
	var town: OverworldMode = root.current_mode_node() as OverworldMode
	assert_int(town.current_stage).is_equal(1)
	for entry: StringName in [&"from_town", &"from_dungeon"]:
		root.machine.request_transition(GameStateMachine.Mode.OVERWORLD,
				MapEntryPayload.new("map_paris_segment_placeholder", entry))
		_run_to_idle(root.machine)
		var seg: OverworldMode = root.current_mode_node() as OverworldMode
		assert_int(seg.current_stage).is_equal(2)
		# Its decree is up at both EntryPoints (story 056).
		var active: int = 0
		for gag: GagInteractable in seg.get_map().gags():
			if gag.decree_stage > 0 and seg.is_gag_active(gag):
				active += 1
		assert_int(active).is_equal(2)


func test_play_sets_no_stage_raising_flag() -> void:
	var root: GameRoot = _boot()
	(root.current_mode_node() as TitleMode)._on_new_game_pressed()
	_run_to_idle(root.machine)
	var raising: Array[String] = []
	for name: String in ["town", "segment", "dungeon", "boss_chamber"]:
		var rec: MapData = load("res://data/maps/map_paris_%s_placeholder.tres" % name)
		for f: String in rec.stage_table:
			raising.append(f)
	var before: Array = root.world_state.to_dict()["flags"]
	# Enter a map, register a camp, beat a symbol.
	root.machine.request_transition(GameStateMachine.Mode.OVERWORLD,
			MapEntryPayload.new("map_paris_dungeon_placeholder", &"from_segment"))
	_run_to_idle(root.machine)
	var dungeon: OverworldMode = root.current_mode_node() as OverworldMode
	dungeon.set_process(false)
	var camp: Vector2 = dungeon.get_map().camp_spots()[0].ground_position(dungeon.get_map())
	dungeon.set_leader_position(camp + Vector2(0.0, 1.0))
	dungeon.step_frame(_DT, Vector2.ZERO)
	var counter: EncounterSource = dungeon.get_encounter_sources()[0]
	dungeon.set_leader_position(counter.brain.position + Vector2(0.0, 1.0))
	dungeon.set_leader_facing(Vector2.UP)
	dungeon.handle_action(InputActions.CONFIRM, true)
	_run_to_idle(root.machine)
	DebugLaunchArgs.force_outcome((root.current_mode_node() as BattleMode).battle, DebugLaunchArgs.VICTORY)
	(root.current_mode_node() as BattleMode).settle_replay()
	root.machine.report_results_done()
	_run_to_idle(root.machine)
	var after: Array = root.world_state.to_dict()["flags"]
	for f: String in after:
		if not before.has(f):
			assert_bool(raising.has(f)).override_failure_message("play set raising flag %s" % f).is_false()


func _boot() -> GameRoot:
	var root: GameRoot = preload(_GAME_ROOT_SCENE).instantiate()
	root.data_root_override = "res://data"
	root.save_dir_override = "user://test_saves_057"
	add_child(root)
	auto_free(root)
	_run_to_idle(root.machine)
	return root


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(_DT)
		ticks += 1
