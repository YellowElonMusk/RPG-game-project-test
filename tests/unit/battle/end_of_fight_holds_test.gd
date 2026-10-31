## Story 067 (GDD sprite-camera-presentation AC-62; ADR-0006 §5, §6): a
## battle won or lost on its last beat reaches Game State only after the
## Battle mode's `victory_hold` / `defeat_hold`, counted on mode time from
## the frame the last beat is released, with the Victory or Defeat blend
## complete by then; a latch set in the final replay doesn't shorten the
## hold; Confirm, Cancel and `fast_forward` during the hold are consumed and
## carry into neither the results screen nor the Defeat Prompt; Quit to
## Title during the hold cancels it and nothing is reported.
extends GdUnitTestSuite

const VICTORY: int = GameStateMachine.BattleResult.VICTORY
const DEFEAT: int = GameStateMachine.BattleResult.DEFEAT


func before() -> void:
	BattleContentSeam.ensure_catalog()


func after_test() -> void:
	GameStateFixtures.dispose_tracked()


func _harness_at_menu() -> BattleModeHarness:
	var h := BattleModeHarness.create(self, ChapterFlow.build_squad(BattleCatalog.shipped()))
	auto_free(h.mode)
	h.reveal()
	var menu: BattleCommandMenu = h.mode.get_node(^"%BattleCommandMenu")
	var guard: int = 0
	while not menu.visible and guard < 3000:
		h.step()
		guard += 1
	assert_bool(menu.visible).is_true()
	return h


## Ends the fight on the next beat: a winning Attack, or every squad
## member down (Defeat).
func _finish(h: BattleModeHarness, won: bool) -> void:
	var battle: BattleCore = h.mode.battle
	if won:
		for e: Combatant in battle.enemies:
			e.hp = 1
		battle.submit_action(Move.make_attack(), battle.get_living_enemies()[0])
		assert_int(battle.state).is_equal(BattleCore.State.WON)
	else:
		DebugLaunchArgs.force_outcome(battle, DebugLaunchArgs.DEFEAT)
		assert_int(battle.state).is_equal(BattleCore.State.LOST)


## Steps until the END marker is released; returns its frame.
func _play_to_end(h: BattleModeHarness) -> int:
	var guard: int = 0
	while h.frames_of("end").is_empty() and guard < 3000:
		h.step()
		guard += 1
	assert_array(h.frames_of("end")).is_not_empty()
	return h.frames_of("end")[0]


## Steps until an outcome is pending; returns that frame.
func _play_to_report(h: BattleModeHarness) -> int:
	var guard: int = 0
	while h.pending_outcome() == -1 and guard < 600:
		h.step()
		guard += 1
	assert_int(h.pending_outcome()).is_not_equal(-1)
	return h.frame


func _hold(h: BattleModeHarness, won: bool) -> float:
	var cfg: PresentationConfig = h.mode.presentation_config
	return cfg.victory_hold if won else cfg.defeat_hold


func test_outcome_reported_after_hold_with_blend_complete() -> void:
	for won: bool in [true, false]:
		var h := _harness_at_menu()
		_finish(h, won)
		var end_frame: int = _play_to_end(h)
		assert_int(h.pending_outcome()).override_failure_message("reported before the hold").is_equal(-1)
		assert_bool(h.mode.is_presenting()).is_true()
		assert_bool(h.profile_requests.has(&"victory" if won else &"defeat")).is_true()
		var report_frame: int = _play_to_report(h)
		assert_int(h.pending_outcome()).is_equal(VICTORY if won else DEFEAT)
		# The hold counts from the END frame itself: reported within one frame
		# of `*_hold` after the last beat is released.
		var held: float = float(report_frame - end_frame + 1) * BattleModeHarness.DT
		assert_float(absf(held - _hold(h, won))).is_less_equal(BattleModeHarness.DT + 1e-6)
		assert_bool(h.stage.is_blending()).override_failure_message("blend unfinished at the report").is_false()
		assert_float(h.stage.blend_p()).is_equal(1.0)


func test_latch_in_final_replay_does_not_shorten_hold() -> void:
	var holds: Array[int] = []
	for latch: bool in [false, true]:
		var h := _harness_at_menu()
		_finish(h, true)
		if latch:
			h.step(2)
			assert_bool(h.press(InputActions.CONFIRM)).is_true()
			assert_bool(h.mode.replay.is_latched()).override_failure_message("final replay not latched").is_true()
		var end_frame: int = _play_to_end(h)
		holds.append(_play_to_report(h) - end_frame)
	assert_int(holds[1]).is_equal(holds[0])


func test_presses_during_hold_are_consumed_and_carry_nowhere() -> void:
	for won: bool in [true, false]:
		var h := _harness_at_menu()
		_finish(h, won)
		_play_to_end(h)
		while h.mode.is_presenting() and h.pending_outcome() == -1:
			for action: StringName in [InputActions.CONFIRM, InputActions.CANCEL, InputActions.FAST_FORWARD]:
				assert_bool(h.press(action)).override_failure_message(
						"%s during the hold was not consumed" % action).is_true()
			h.step()
		assert_int(h.pending_outcome()).is_equal(VICTORY if won else DEFEAT)
		# Victory still waits for its own results Confirm; the Defeat Prompt
		# is open and untouched (no Retry or Retreat chosen).
		assert_int(h.machine.phase).is_equal(GameStateMachine.Phase.IDLE)
		h.step(30)
		assert_int(h.pending_outcome()).is_equal(VICTORY if won else DEFEAT)


func test_quit_to_title_during_hold_cancels_it() -> void:
	var h := _harness_at_menu()
	_finish(h, true)
	_play_to_end(h)
	assert_bool(h.mode.is_presenting()).is_true()
	h.machine.open_overlay(GameStateMachine.OverlayKind.MENU, MenuPayload.new())
	assert_int(h.machine.request_transition(GameStateMachine.Mode.TITLE)).is_equal(
			GameStateMachine.RequestResult.OK)
	assert_bool(h.mode.is_presenting()).is_false()
	h.run_machine_to_idle()
	h.step(120)
	assert_int(h.pending_outcome()).is_equal(-1)
