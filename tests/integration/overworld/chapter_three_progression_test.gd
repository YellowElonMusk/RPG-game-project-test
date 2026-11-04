## Chapter 3 (2026-11-04): Yes at the London café on London's final step
## sends the squad to Sydney's Circular Quay at its arrival point, in
## chapter_sydney's first step with the feed live and the Sydney café as the
## Retreat camp, and says the Sydney intro. The chapter survives Save ->
## Continue. Sydney, now the last chapter, says the end line and goes
## nowhere. Drives real GameRoots.
extends GdUnitTestSuite

const _GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const _SAVE_DIR: String = "user://test_saves_chapter_three"
const _PARIS_TOWN: String = "map_paris_town_placeholder"
const _SYDNEY_TOWN: String = "map_sydney_town_placeholder"
const _DT: float = 1.0 / 60.0


func before_test() -> void:
	_clear_saves()


func after_test() -> void:
	_clear_saves()


func test_ending_london_starts_sydney() -> void:
	var root: GameRoot = _new_game()
	var sydney: OverworldMode = _end_london(root)
	assert_str(sydney.get_map().map_id).is_equal(_SYDNEY_TOWN)
	var entry: EntryPoint = sydney.get_map().find_entry_point(&"from_arrival")
	assert_vector(sydney.get_leader_position()).is_equal(entry.ground_position(sydney.get_map()))
	assert_str(root.world_state.chapter_id).is_equal("chapter_sydney")
	assert_str(root.world_state.chapter_step).is_equal("sydney_step_leave_town")
	assert_bool(root.world_state.has_flag("sydney_feed_live")).is_true()
	assert_str(root.machine.last_camp_id).is_equal("camp_sydney_cafe")
	assert_str(sydney.objective_line()).contains("Content House")
	assert_str((root.current_overlay_node() as InterimLineDialogue).text).contains("Sydney")


func test_sydney_survives_save_and_continue() -> void:
	var root: GameRoot = _new_game()
	var sydney: OverworldMode = _end_london(root)
	_close_line(root)
	sydney.step_frame(_DT, Vector2.ZERO)
	assert_int(root.save_service().save_to_slot(1)).is_equal(SaveService.SaveResult.OK)
	root.queue_free()
	await get_tree().process_frame
	var again: GameRoot = _boot()
	(again.current_mode_node() as TitleMode)._on_continue_pressed()
	_run_to_idle(again.machine)
	var back: OverworldMode = again.current_mode_node() as OverworldMode
	back.set_process(false)
	assert_str(back.get_map().map_id).is_equal(_SYDNEY_TOWN)
	assert_str(again.world_state.chapter_id).is_equal("chapter_sydney")
	assert_str(back.objective_line()).contains("Content House")


func test_ending_sydney_says_the_end_line_and_stays() -> void:
	var root: GameRoot = _new_game()
	var sydney: OverworldMode = _end_london(root)
	_close_line(root)
	root.world_state.chapter_step = "sydney_step_walk_home_b"
	_say_yes_at_cafe(sydney)
	assert_int(sydney.chapter_end_calls).is_equal(1)
	assert_int(root.machine.phase).is_equal(GameStateMachine.Phase.IDLE)
	assert_str(root.world_state.chapter_id).is_equal("chapter_sydney")
	assert_str((root.current_overlay_node() as InterimLineDialogue).text).contains("To be continued")


## New Game -> Paris end -> London -> London end -> Sydney.
func _end_london(root: GameRoot) -> OverworldMode:
	root.world_state.chapter_step = "step_walk_home_b"
	assert_int(root.machine.request_transition(GameStateMachine.Mode.OVERWORLD,
			MapEntryPayload.new(_PARIS_TOWN, &"from_segment"))).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(root.machine)
	var town: OverworldMode = root.current_mode_node() as OverworldMode
	town.set_process(false)
	town.tick_timed_text(60.0)
	_say_yes_at_cafe(town)
	_run_to_idle(root.machine)
	var london: OverworldMode = root.current_mode_node() as OverworldMode
	london.set_process(false)
	_close_line(root)
	root.world_state.chapter_step = "london_step_walk_home_b"
	_say_yes_at_cafe(london)
	assert_int(london.chapter_end_calls).is_equal(1)
	_run_to_idle(root.machine)
	var sydney: OverworldMode = root.current_mode_node() as OverworldMode
	sydney.set_process(false)
	return sydney


func _say_yes_at_cafe(town: OverworldMode) -> void:
	var cafe: Vector2 = town.get_map().camp_spots()[0].ground_position(town.get_map())
	town.set_leader_position(cafe + Vector2(0.0, 1.0))
	town.set_leader_facing(Vector2.UP)
	town.handle_action(InputActions.CONFIRM, true)
	assert_bool(town.camp_prompt_is_chapter_end).is_true()
	town.handle_action(InputActions.MOVE_LEFT, true)
	town.handle_action(InputActions.CONFIRM, true)


func _close_line(root: GameRoot) -> void:
	var line: InterimLineDialogue = root.current_overlay_node() as InterimLineDialogue
	if line == null:
		return
	line.advance_guard(0.2)
	line.skip_to_end()


func _new_game() -> GameRoot:
	var root: GameRoot = _boot()
	(root.current_mode_node() as TitleMode)._on_new_game_pressed()
	_run_to_idle(root.machine)
	(root.current_mode_node() as OverworldMode).set_process(false)
	return root


func _boot() -> GameRoot:
	var root: GameRoot = preload(_GAME_ROOT_SCENE).instantiate()
	root.data_root_override = "res://data"
	root.save_dir_override = _SAVE_DIR
	add_child(root)
	auto_free(root)
	_run_to_idle(root.machine)
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
