## Story 065 (GDD sprite-camera-presentation AC-60; ADR-0006 §3, §6): a
## press counts only once it begins after the full reveal. Confirm or
## `fast_forward` pressed on any frame while the wipe still covers the
## screen is consumed and latches, submits and carries over nothing; the
## Confirm that submitted a command, held into the replay, never latches
## (a held key sends no new `pressed`); a fresh Confirm tap 5 frames into
## the replay latches it. Driven through the real Battle mode's
## `handle_action()`, with the squad's real sprite wind-ups.
extends GdUnitTestSuite

const TAP_FRAME: int = 5


func before() -> void:
	BattleContentSeam.ensure_catalog()


func after_test() -> void:
	GameStateFixtures.dispose_tracked()


func _harness() -> BattleModeHarness:
	var h := BattleModeHarness.create(self, ChapterFlow.build_squad(BattleCatalog.shipped()))
	auto_free(h.mode)
	return h


## Reveals and plays until the command menu is open on a squad turn.
func _reveal_to_menu(h: BattleModeHarness) -> BattleCommandMenu:
	h.reveal()
	var menu: BattleCommandMenu = h.mode.get_node(^"%BattleCommandMenu")
	var guard: int = 0
	while not menu.visible and guard < 3000:
		h.step()
		guard += 1
	assert_bool(menu.visible).override_failure_message("no command menu after the reveal").is_true()
	return menu


func test_presses_behind_the_wipe_are_consumed_and_do_nothing() -> void:
	var h := _harness()
	assert_int(h.mode.replay.get_state()).is_equal(BattleReplayController.State.GATED)
	var frames: int = 0
	while h.machine.phase != GameStateMachine.Phase.IDLE and frames < 600:
		for action: StringName in [InputActions.CONFIRM, InputActions.FAST_FORWARD]:
			assert_bool(h.press(action)).override_failure_message(
					"%s behind the wipe was not consumed" % action).is_true()
		assert_bool(h.mode.replay.is_latched()).is_false()
		h.machine.tick(BattleModeHarness.DT)
		h.step()
		frames += 1
	assert_int(frames).is_greater(0)
	assert_int(h.mode.battle.outcome_log.size()).is_equal(0)
	assert_array(h.frames_of("latch_on")).is_empty()
	var menu: BattleCommandMenu = _reveal_to_menu(h)
	# Nothing carried over: one fresh Confirm only picks Attack (target
	# selection opens); had a gated press reached the menu, it would submit.
	var submitted: int = h.mode.battle.outcome_log.size()
	h.press(InputActions.CONFIRM)
	assert_int(h.mode.battle.outcome_log.size()).is_equal(submitted)
	assert_bool(menu.visible).is_true()


func test_confirm_held_into_the_replay_never_latches() -> void:
	var h := _harness()
	_reveal_to_menu(h)
	var before: int = h.mode.battle.outcome_log.size()
	h.press(InputActions.CONFIRM)  # Attack
	h.mode.handle_action(InputActions.CONFIRM, true)  # the target; held, never released
	assert_int(h.mode.battle.outcome_log.size()).is_greater(before)
	assert_bool(h.mode.replay.is_replaying() or h.mode.replay.get_state() == BattleReplayController.State.PLAYING).is_true()
	var guard: int = 0
	while h.mode.is_presenting() and guard < 3000:
		h.step()
		assert_bool(h.mode.replay.is_latched()).is_false()
		guard += 1
	assert_array(h.frames_of("latch_on")).is_empty()
	h.mode.handle_action(InputActions.CONFIRM, false)


func test_fresh_tap_five_frames_into_the_replay_latches() -> void:
	var h := _harness()
	_reveal_to_menu(h)
	h.press(InputActions.CONFIRM)  # Attack
	h.press(InputActions.CONFIRM)  # the target
	h.step()
	assert_array(h.frames_of("replay_started")).is_not_empty()
	var started: int = h.frames_of("replay_started")[-1]
	while h.frame < started + TAP_FRAME:
		h.step()
	assert_bool(h.mode.replay.is_press_effective()).override_failure_message(
			"the wind-up is not press-effective 5 frames in (debug path?)").is_true()
	assert_bool(h.press(InputActions.CONFIRM)).is_true()
	assert_bool(h.mode.replay.is_latched()).is_true()
