## Story 090, AC-33c (GDD rule 13): after Victory over the boss, then a
## Retreat in a later fight, then a Save, a restart and Continue, the boss
## stays absent, and its chamber loads without it. Drives two real
## `GameRoot`s on one test save folder (the second is the relaunch).
extends GdUnitTestSuite

const _GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const _SAVE_DIR: String = "user://test_saves_090"
const _CHAMBER: String = "map_paris_boss_chamber_placeholder"
const _BOSS: String = "sym_paris_supervisor"
const _DT: float = 1.0 / 60.0


func before_test() -> void:
	_clear_saves()


func after_test() -> void:
	_clear_saves()


func test_boss_stays_absent_through_retreat_save_and_continue() -> void:
	var root: GameRoot = _boot()
	_run_to_idle(root.machine)
	(root.current_mode_node() as TitleMode)._on_new_game_pressed()
	_run_to_idle(root.machine)

	# Victory over the boss.
	var chamber: OverworldMode = _go(root, _CHAMBER, &"from_dungeon")
	_walk_into_first_symbol(root, chamber)
	DebugLaunchArgs.force_outcome((root.current_mode_node() as BattleMode).battle, DebugLaunchArgs.VICTORY)
	assert_int(root.machine.report_results_done()).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(root.machine)
	assert_bool(root.world_state.is_resolved(_CHAMBER, _BOSS)).is_true()
	# Story 068: the post-battle Dialogue, then the walk home to the segment.
	var line: InterimLineDialogue = root.current_overlay_node() as InterimLineDialogue
	line.advance_guard(0.2)
	line.handle_action(InputActions.CONFIRM, true)
	_run_to_idle(root.machine)

	# Beating the boss liberated Paris: every symbol there is now inactive
	# (rule 9), so the later Retreat-able fight is started straight from a
	# record (the Permit Counter's), through Game State as any battle is.
	assert_bool(root.world_state.has_flag("paris_liberated")).is_true()
	var dungeon: OverworldMode = _go(root, "map_paris_dungeon_placeholder", &"from_segment")
	assert_int(dungeon.get_encounter_sources().size()).is_equal(0)
	var payload := BattleEntryPayload.new()
	payload.descriptor = OverworldMode.build_descriptor(
			root.catalog().get_record(&"encounter", "enc_paris_permit_counter") as EncounterData)
	var started: GameStateMachine.RequestResult = root.machine.request_transition(
			GameStateMachine.Mode.BATTLE, payload)
	assert_int(started).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(root.machine)
	assert_object(root.current_mode_node() as BattleMode).is_not_null()
	assert_int(root.machine.report_battle_outcome(GameStateMachine.BattleResult.DEFEAT)) \
			.is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(root.machine)
	assert_int(root.machine.choose_retreat()).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(root.machine)
	var camp: InterimCampMode = root.current_mode_node() as InterimCampMode
	assert_object(camp).is_not_null()
	assert_bool(root.world_state.is_resolved(_CHAMBER, _BOSS)).is_true()

	# Save (setting out from camp autosaves to slot 1).
	camp.handle_action(InputActions.CONFIRM, true)
	assert_int(camp.last_save_result).is_equal(SaveService.SaveResult.OK)
	_run_to_idle(root.machine)

	# Relaunch: a fresh GameRoot on the same folder, Continue.
	root.queue_free()
	await get_tree().process_frame
	var again: GameRoot = _boot()
	_run_to_idle(again.machine)
	var title: TitleMode = again.current_mode_node() as TitleMode
	assert_bool(title.get("_continue_button").disabled).is_false()
	title._on_continue_pressed()
	assert_bool(title.last_load.is_ok()).override_failure_message(", ".join(title.last_load.report)).is_true()
	_run_to_idle(again.machine)
	var back: OverworldMode = again.current_mode_node() as OverworldMode
	assert_object(back).is_not_null()
	assert_bool(again.world_state.is_resolved(_CHAMBER, _BOSS)).is_true()
	# The chamber loads without the boss.
	var reloaded: OverworldMode = _go(again, _CHAMBER, &"from_dungeon")
	assert_int(reloaded.get_encounter_sources().size()).is_equal(0)


func test_continue_lands_at_the_camp_return_point_after_a_camp_save() -> void:
	var root: GameRoot = _boot()
	_run_to_idle(root.machine)
	(root.current_mode_node() as TitleMode)._on_new_game_pressed()
	_run_to_idle(root.machine)
	var p := CampEntryPayload.new()
	p.camp_id = "camp_paris_pre_dungeon"
	assert_int(root.machine.request_transition(GameStateMachine.Mode.CAMP, p)).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(root.machine)
	(root.current_mode_node() as InterimCampMode).handle_action(InputActions.CONFIRM, true)
	_run_to_idle(root.machine)
	root.queue_free()
	await get_tree().process_frame
	var again: GameRoot = _boot()
	_run_to_idle(again.machine)
	(again.current_mode_node() as TitleMode)._on_continue_pressed()
	_run_to_idle(again.machine)
	var back: OverworldMode = again.current_mode_node() as OverworldMode
	assert_str(back.get_map().map_id).is_equal("map_paris_dungeon_placeholder")
	var entry: EntryPoint = back.get_map().find_entry_point(&"from_segment")
	assert_vector(back.get_leader_position()).is_equal(entry.ground_position(back.get_map()))
	assert_str(again.machine.last_camp_id).is_equal("camp_paris_pre_dungeon")


func _walk_into_first_symbol(root: GameRoot, mode: OverworldMode) -> void:
	var source: EncounterSource = mode.get_encounter_sources()[0]
	mode.grace_active = false
	mode.set_leader_position(source.brain.position + Vector2(0.0, 1.0))
	var frames: int = 0
	while root.machine.phase == GameStateMachine.Phase.IDLE and frames < 120:
		mode.step_frame(_DT, Vector2.UP)
		frames += 1
	_run_to_idle(root.machine)
	assert_object(root.current_mode_node() as BattleMode).is_not_null()


func _go(root: GameRoot, map_id: String, entry: StringName) -> OverworldMode:
	assert_int(root.machine.request_transition(GameStateMachine.Mode.OVERWORLD,
			MapEntryPayload.new(map_id, entry))).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(root.machine)
	var mode: OverworldMode = root.current_mode_node() as OverworldMode
	mode.set_process(false)
	return mode


func _boot() -> GameRoot:
	var root: GameRoot = preload(_GAME_ROOT_SCENE).instantiate()
	root.data_root_override = "res://data"
	root.save_dir_override = _SAVE_DIR
	add_child(root)
	auto_free(root)
	return root


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(_DT)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message("transition did not finish").is_true()


func _clear_saves() -> void:
	var dir := DirAccess.open(_SAVE_DIR)
	if dir == null:
		return
	for f: String in dir.get_files():
		dir.remove(f)
