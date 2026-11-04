## Faction Reputation & Endings (2026-11-04): Yes at the café on the last
## chapter's final step plays the ending the squad's reputation earned,
## then fades to Title, which rolls the credits before its buttons. Drives a
## real GameRoot on a one-chapter campaign (Paris), so it holds whichever
## chapter the shipped campaign ends on.
extends GdUnitTestSuite

const _GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const _SAVE_DIR: String = "user://test_saves_campaign_ending"
const _PARIS_TOWN: String = "map_paris_town_placeholder"
const _DT: float = 1.0 / 60.0


func before_test() -> void:
	_clear_saves()


func after_test() -> void:
	_clear_saves()


func test_human_lean_plays_the_human_ending_then_credits_then_title() -> void:
	var root: GameRoot = _new_game_paris_only()
	root.world_state.street_cred = 2
	root.world_state.alien_points = 1
	var town: OverworldMode = _to_paris_final_step(root)
	_say_yes_at_cafe(town)
	assert_str(root.ending.id).is_equal(EndingRules.HUMAN)
	var line: InterimLineDialogue = root.current_overlay_node() as InterimLineDialogue
	assert_object(line).is_not_null()
	assert_str(line.text).contains("chose the street")
	line.advance_guard(0.2)
	line.skip_to_end()
	root._try_finish_campaign()
	_run_to_idle(root.machine)
	assert_int(root.machine.current_mode).is_equal(GameStateMachine.Mode.TITLE)
	var title: TitleMode = root.current_mode_node() as TitleMode
	assert_object(title.credits_panel).is_not_null()
	assert_str(title.credits_panel.text()).contains("Ending: Street Legends")
	title.credits_panel.advance(2.0)
	title.handle_action(InputActions.CONFIRM, true)
	assert_object(title.credits_panel).is_null()


func test_alien_lean_plays_the_true_ending() -> void:
	var root: GameRoot = _new_game_paris_only()
	root.world_state.alien_points = 1
	_say_yes_at_cafe(_to_paris_final_step(root))
	assert_str(root.ending.id).is_equal(EndingRules.ALIEN)
	assert_str((root.current_overlay_node() as InterimLineDialogue).text).contains("let them go")


func test_an_even_record_plays_the_split_ending() -> void:
	var root: GameRoot = _new_game_paris_only()
	_say_yes_at_cafe(_to_paris_final_step(root))
	assert_str(root.ending.id).is_equal(EndingRules.SPLIT)


func _new_game_paris_only() -> GameRoot:
	var root: GameRoot = _boot()
	(root.current_mode_node() as TitleMode)._on_new_game_pressed()
	_run_to_idle(root.machine)
	(root.current_mode_node() as OverworldMode).set_process(false)
	var only_paris := Campaign.new()
	only_paris.chapters.append(root.campaign.chapters[0])
	root.campaign = only_paris
	return root


func _to_paris_final_step(root: GameRoot) -> OverworldMode:
	root.world_state.chapter_step = "step_walk_home_b"
	assert_int(root.machine.request_transition(GameStateMachine.Mode.OVERWORLD,
			MapEntryPayload.new(_PARIS_TOWN, &"from_segment"))).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(root.machine)
	var town: OverworldMode = root.current_mode_node() as OverworldMode
	town.set_process(false)
	town.tick_timed_text(60.0)
	return town


func _say_yes_at_cafe(town: OverworldMode) -> void:
	var cafe: Vector2 = town.get_map().camp_spots()[0].ground_position(town.get_map())
	town.set_leader_position(cafe + Vector2(0.0, 1.0))
	town.set_leader_facing(Vector2.UP)
	town.handle_action(InputActions.CONFIRM, true)
	assert_bool(town.camp_prompt_is_chapter_end).is_true()
	town.handle_action(InputActions.MOVE_LEFT, true)
	town.handle_action(InputActions.CONFIRM, true)
	assert_int(town.chapter_end_calls).is_equal(1)


func _boot() -> GameRoot:
	var root: GameRoot = preload(_GAME_ROOT_SCENE).instantiate()
	root.tutorial_hints_enabled = false  # onboarding cards would gate round 1
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
