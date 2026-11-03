## The post-alien-boss spare-or-finish choice (narrative bible §6.2, user
## 2026-10-29; game concept MVP item 6): only after an alien boss; "Finish
## him off" gains human street cred, "Let him go" gains alien points; the
## meters are saved with the WorldState.
extends GdUnitTestSuite


func before() -> void:
	BattleContentSeam.ensure_catalog()


func after_test() -> void:
	GameStateFixtures.dispose_tracked()


func _won_harness(is_boss: bool) -> BattleModeHarness:
	var h := BattleModeHarness.create(self, ChapterFlow.build_squad(BattleCatalog.shipped()), is_boss)
	auto_free(h.mode)
	h.mode.world_state = WorldState.new()
	h.reveal()
	h.mode.settle_replay()
	DebugLaunchArgs.force_outcome(h.mode.battle, DebugLaunchArgs.VICTORY)
	h.mode.settle_replay()
	return h


func _continue_results(h: BattleModeHarness) -> void:
	h.mode.step_replay(h.mode.presentation_config.input_guard + 0.05)
	h.mode.handle_action(InputActions.CONFIRM, true)


func test_an_ordinary_fight_ends_with_no_choice() -> void:
	var h := _won_harness(false)
	_continue_results(h)
	assert_bool(h.mode.boss_choice().visible).override_failure_message("a choice after an ordinary fight").is_false()


func test_finishing_the_boss_gains_street_cred() -> void:
	var h := _won_harness(true)
	_continue_results(h)
	var choice: BossChoicePanel = h.mode.boss_choice()
	assert_bool(choice.visible).override_failure_message("no choice after the boss").is_true()
	choice.finish_button().pressed.emit()
	assert_int(h.mode.world_state.street_cred).is_equal(1)
	assert_int(h.mode.world_state.alien_points).is_equal(0)
	assert_str(choice.result_text()).contains("purple goo")


func test_letting_the_boss_go_gains_alien_points() -> void:
	var h := _won_harness(true)
	_continue_results(h)
	h.mode.boss_choice().spare_button().pressed.emit()
	assert_int(h.mode.world_state.alien_points).is_equal(1)
	assert_int(h.mode.world_state.street_cred).is_equal(0)


func test_mashing_confirm_through_the_results_never_picks() -> void:
	var h := _won_harness(true)
	_continue_results(h)
	h.mode.handle_action(InputActions.CONFIRM, true)  # the same instant the choice opens
	assert_int(h.mode.world_state.street_cred + h.mode.world_state.alien_points).override_failure_message(
			"a mashed Confirm made the choice").is_equal(0)


func test_meters_survive_a_save_round_trip() -> void:
	var ws := WorldState.new()
	ws.map_id = "map_paris_town_placeholder"
	ws.street_cred = 2
	ws.alien_points = 3
	# Through the real participant and a JSON round trip, as a save file does.
	var data: Dictionary = JSON.parse_string(JSON.stringify(ws.to_dict()))
	var back := WorldState.new()
	var participant := OverworldSaveParticipant.new(back, null, Callable())
	var staged: SaveStage = participant.stage(data, SaveReader.new(data, BattleCatalog.shipped()))
	participant.commit(staged)
	assert_int(back.street_cred).is_equal(2)
	assert_int(back.alien_points).is_equal(3)
	back.reset_to_new_game()
	assert_int(back.street_cred + back.alien_points).is_equal(0)
