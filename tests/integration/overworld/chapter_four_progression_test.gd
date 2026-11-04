## Chapter 4 (2026-11-04): Yes at the Sydney café on Sydney's final step
## sends the squad to New York's Times Square at its arrival point, in
## chapter_newyork's first step with the anthem live and the New York café
## as the Retreat camp, and says the New York intro. The chapter survives
## Save -> Continue. New York is the campaign's last chapter: its end stays
## in New York and starts the campaign-complete path. Drives real GameRoots.
extends GdUnitTestSuite

const _GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const _SAVE_DIR: String = "user://test_saves_chapter_four"
const _NY_TOWN: String = "map_newyork_town_placeholder"
const _DT: float = 1.0 / 60.0


func before_test() -> void:
	_clear_saves()


func after_test() -> void:
	_clear_saves()


func test_ending_sydney_starts_new_york_at_its_arrival_point() -> void:
	var root: GameRoot = _new_game()
	var ny: OverworldMode = _begin_new_york(root)
	assert_str(ny.get_map().map_id).is_equal(_NY_TOWN)
	var entry: EntryPoint = ny.get_map().find_entry_point(&"from_arrival")
	assert_vector(ny.get_leader_position()).is_equal(entry.ground_position(ny.get_map()))
	assert_str(root.world_state.chapter_id).is_equal("chapter_newyork")
	assert_str(root.world_state.chapter_step).is_equal("newyork_step_leave_town")
	assert_bool(root.world_state.has_flag("newyork_anthem_live")).is_true()
	assert_str(root.machine.last_camp_id).is_equal("camp_newyork_cafe")
	assert_str(ny.objective_line()).contains("Liberty Dome")
	assert_str((root.current_overlay_node() as InterimLineDialogue).text).contains("New York")


func test_new_york_survives_save_and_continue() -> void:
	var root: GameRoot = _new_game()
	var ny: OverworldMode = _begin_new_york(root)
	_close_line(root)
	ny.step_frame(_DT, Vector2.ZERO)
	assert_int(root.save_service().save_to_slot(1)).is_equal(SaveService.SaveResult.OK)
	root.queue_free()
	await get_tree().process_frame
	var again: GameRoot = _boot()
	(again.current_mode_node() as TitleMode)._on_continue_pressed()
	_run_to_idle(again.machine)
	var back: OverworldMode = again.current_mode_node() as OverworldMode
	back.set_process(false)
	assert_str(back.get_map().map_id).is_equal(_NY_TOWN)
	assert_str(again.world_state.chapter_id).is_equal("chapter_newyork")
	assert_str(back.objective_line()).contains("Liberty Dome")


## New York is last: no further chapter, the squad stays in New York.
func test_ending_new_york_finishes_the_campaign_in_new_york() -> void:
	var root: GameRoot = _new_game()
	var ny: OverworldMode = _begin_new_york(root)
	_close_line(root)
	root.world_state.chapter_step = "newyork_step_walk_home_b"
	_say_yes_at_cafe(ny)
	assert_int(ny.chapter_end_calls).is_equal(1)
	assert_str(root.world_state.chapter_id).is_equal("chapter_newyork")
	assert_object(root.current_overlay_node()).is_not_null()


## New Game -> the last step of each of Paris, London and Sydney -> New York.
func _begin_new_york(root: GameRoot) -> OverworldMode:
	root.world_state.chapter_step = "step_walk_home_b"
	assert_int(root.machine.request_transition(GameStateMachine.Mode.OVERWORLD,
			MapEntryPayload.new("map_paris_town_placeholder", &"from_segment"))).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(root.machine)
	var town: OverworldMode = root.current_mode_node() as OverworldMode
	town.set_process(false)
	town.tick_timed_text(60.0)
	for next_final_step: String in ["london_step_walk_home_b", "sydney_step_walk_home_b", ""]:
		_say_yes_at_cafe(town)
		_run_to_idle(root.machine)
		town = root.current_mode_node() as OverworldMode
		town.set_process(false)
		if next_final_step.is_empty():
			break
		_close_line(root)
		root.world_state.chapter_step = next_final_step
	return town


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
