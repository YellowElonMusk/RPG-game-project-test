## Story 015, AC-12: Victory records the outcome and starts nothing; the
## Battle -> Overworld `battle_wipe_reverse` starts only once the Battle mode
## reports its results screen done. Written to the QA Test Cases in
## `production/epics/game-state-scene-flow/story-015-victory-waits-for-results.md`
## -- no new cases invented.
extends GdUnitTestSuite


func test_return_starts_only_after_results_done() -> void:
	# Arrange: a machine in BATTLE (entered from Overworld).
	var recorder := SequenceRecorder.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder)
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var presenter: StubTransitionPresenter = env["presenter"]

	var battle_stub: StubBattleMode = auto_free(StubBattleMode.new())
	battle_stub.snapshot_to_return = GameStateFixtures.make_overworld_snapshot()
	loader.current_mode_node_value = battle_stub

	var source := SyntheticActionSource.new()
	machine.bind_action_source(source)

	var entry_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
	assert_int(entry_result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)

	# Act: report_battle_outcome(VICTORY) -> OK; tick 120 x (1/60).
	recorder.clear()
	var outcome_result: GameStateMachine.RequestResult = machine.report_battle_outcome(
			GameStateMachine.BattleResult.VICTORY)
	assert_int(outcome_result).is_equal(GameStateMachine.RequestResult.OK)
	for _i in range(120):
		machine.tick(1.0 / 60.0)

	# Assert: phase == IDLE; no transition_started.
	assert_int(machine.phase).is_equal(GameStateMachine.Phase.IDLE)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)
	assert_int(recorder.index_of(&"transition_started")).is_equal(-1)

	# Assert: a synthetic confirm still reaches the Battle mode (the results
	# screen is not a transition -- input keeps routing normally).
	source.press(&"confirm")
	source.release(&"confirm")
	assert_int(battle_stub.handle_action_count).is_equal(2)
	assert_bool(battle_stub.last_action == &"confirm").is_true()

	# Act: report_results_done() -> OK.
	recorder.clear()
	var done_result: GameStateMachine.RequestResult = machine.report_results_done()
	assert_int(done_result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)

	# Assert: transition_started(BATTLE, OVERWORLD) with battle_wipe_reverse.
	var started_index: int = recorder.index_of(&"transition_started")
	assert_int(started_index).is_greater_equal(0)
	var expected_args: Array[GameStateMachine.Mode] = [
		GameStateMachine.Mode.BATTLE, GameStateMachine.Mode.OVERWORLD,
	]
	assert_array(recorder.events[started_index]["args"]).is_equal(expected_args)
	assert_bool(presenter.play_out_calls.back()["type"] == &"battle_wipe_reverse").is_true()
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.OVERWORLD)


## Edge case: report_results_done() with no pending Victory -> rejected,
## logged, probe equal.
func test_results_done_without_pending_victory_rejected() -> void:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var game_log: SpyGameStateLog = env["log"]

	var battle_stub: StubBattleMode = auto_free(StubBattleMode.new())
	battle_stub.snapshot_to_return = GameStateFixtures.make_overworld_snapshot()
	loader.current_mode_node_value = battle_stub

	var entry_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
	assert_int(entry_result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)

	var probe_before: Dictionary = machine.get_debug_state()
	var result: GameStateMachine.RequestResult = machine.report_results_done()

	assert_int(result).is_equal(GameStateMachine.RequestResult.REJECTED_INVALID_PAIR)
	assert_bool(GameStateProbe.states_equal(probe_before, machine.get_debug_state())) \
			.override_failure_message("debug state changed after a rejected report_results_done").is_true()
	assert_int(game_log.entries.size()).is_equal(1)
	assert_bool(game_log.entries[0]["level"] == &"error").is_true()
	assert_bool(game_log.entries[0]["code"] == &"results_done_no_pending_victory").is_true()


## Edge case: a second report_battle_outcome while Victory is pending ->
## rejected.
func test_second_outcome_while_victory_pending_rejected() -> void:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var game_log: SpyGameStateLog = env["log"]

	var battle_stub: StubBattleMode = auto_free(StubBattleMode.new())
	battle_stub.snapshot_to_return = GameStateFixtures.make_overworld_snapshot()
	loader.current_mode_node_value = battle_stub

	var entry_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
	assert_int(entry_result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)

	var first_result: GameStateMachine.RequestResult = machine.report_battle_outcome(
			GameStateMachine.BattleResult.VICTORY)
	assert_int(first_result).is_equal(GameStateMachine.RequestResult.OK)

	var probe_before: Dictionary = machine.get_debug_state()
	var second_result: GameStateMachine.RequestResult = machine.report_battle_outcome(
			GameStateMachine.BattleResult.VICTORY)

	assert_int(second_result).is_equal(GameStateMachine.RequestResult.REJECTED_BUSY)
	assert_bool(GameStateProbe.states_equal(probe_before, machine.get_debug_state())) \
			.override_failure_message("debug state changed after a rejected second report_battle_outcome").is_true()
	assert_int(game_log.entries.size()).is_equal(1)
	assert_bool(game_log.entries[0]["level"] == &"error").is_true()
	assert_bool(game_log.entries[0]["code"] == &"outcome_already_pending").is_true()


## Bounded 1/60s-tick loop until the transition reaches IDLE.
func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()
