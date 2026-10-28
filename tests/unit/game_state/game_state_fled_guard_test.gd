## Story 016, AC-13: Fled on a descriptor with `can_flee = false` is rejected
## as a Turn Battle bug -- nothing changes and the battle continues. Written
## to the QA Test Cases in
## `production/epics/game-state-scene-flow/story-016-fled-rejected-when-not-allowed.md`
## -- no new cases invented.
extends GdUnitTestSuite


func test_fled_rejected_when_not_allowed() -> void:
	# Arrange: BATTLE entered with descriptor can_flee = false.
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var game_log: SpyGameStateLog = env["log"]

	var battle_stub: StubBattleMode = auto_free(StubBattleMode.new())
	battle_stub.snapshot_to_return = GameStateFixtures.make_overworld_snapshot()
	loader.current_mode_node_value = battle_stub

	var payload := BattleEntryPayload.new()
	var descriptor: EncounterDescriptor = GameStateFixtures.make_encounter_descriptor()
	descriptor.can_flee = false
	payload.descriptor = descriptor
	payload.party = []

	var entry_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, payload)
	assert_int(entry_result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)

	# Act: report_battle_outcome(FLED).
	var probe_before: Dictionary = machine.get_debug_state()
	var fled_result: GameStateMachine.RequestResult = machine.report_battle_outcome(
			GameStateMachine.BattleResult.FLED)

	# Assert: REJECTED_INVALID_PAYLOAD; error logged; mode BATTLE; probe equal.
	assert_int(fled_result).is_equal(GameStateMachine.RequestResult.REJECTED_INVALID_PAYLOAD)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)
	assert_bool(GameStateProbe.states_equal(probe_before, machine.get_debug_state())) \
			.override_failure_message("debug state changed after a rejected Fled").is_true()
	assert_int(game_log.entries.size()).is_equal(1)
	assert_bool(game_log.entries[0]["level"] == &"error").is_true()
	assert_bool(game_log.entries[0]["code"] == &"fled_not_allowed").is_true()
	assert_str(game_log.entries[0]["context"]["encounter_id"]).is_equal(descriptor.encounter_id)

	# Assert: a later report_battle_outcome(VICTORY) is still accepted.
	var victory_result: GameStateMachine.RequestResult = machine.report_battle_outcome(
			GameStateMachine.BattleResult.VICTORY)
	assert_int(victory_result).is_equal(GameStateMachine.RequestResult.OK)


## Edge case: can_flee = true -> Fled starts Battle -> Overworld immediately,
## no report_results_done() needed.
func test_fled_allowed_starts_return_immediately() -> void:
	var recorder := SequenceRecorder.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder)
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var presenter: StubTransitionPresenter = env["presenter"]

	var battle_stub: StubBattleMode = auto_free(StubBattleMode.new())
	battle_stub.snapshot_to_return = GameStateFixtures.make_overworld_snapshot()
	loader.current_mode_node_value = battle_stub

	var entry_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
	assert_int(entry_result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)

	recorder.clear()
	var fled_result: GameStateMachine.RequestResult = machine.report_battle_outcome(
			GameStateMachine.BattleResult.FLED)
	assert_int(fled_result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)

	var started_index: int = recorder.index_of(&"transition_started")
	assert_int(started_index).is_greater_equal(0)
	var expected_args: Array[GameStateMachine.Mode] = [
		GameStateMachine.Mode.BATTLE, GameStateMachine.Mode.OVERWORLD,
	]
	assert_array(recorder.events[started_index]["args"]).is_equal(expected_args)
	assert_bool(presenter.play_out_calls.back()["type"] == &"battle_wipe_reverse").is_true()
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.OVERWORLD)


## Bounded 1/60s-tick loop until the transition reaches IDLE.
func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()
