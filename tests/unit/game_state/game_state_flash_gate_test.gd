## Story 017, TR-gamestate-007 (supporting; no GDD AC yet): flashing
## transitions book their flash through the injected `FlashGate` once, at
## the start of OUT, and a refused booking plays the capped variant with
## unchanged timing. Written to the QA Test Cases in
## `production/epics/game-state-scene-flow/story-017-defeat-prompt-and-retry-snapshot.md`
## -- no new cases invented.
extends GdUnitTestSuite

## [capped_result] -- each case its own array so gdUnit4's parametrize runs
## instead of hanging.
const _CASES: Array = [[false], [true]]


func test_flash_booked_and_capped(capped_result: bool, test_parameters := _CASES) -> void:
	# Arrange: a machine in OVERWORLD with a scripted flash gate, entered
	# into BATTLE and defeated so choose_retry() can run the retry_flash row.
	var recorder := SequenceRecorder.new()
	var gate := StubFlashGate.new()
	gate.capped_result = capped_result
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder, gate)
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var presenter: StubTransitionPresenter = env["presenter"]

	var battle_stub: StubBattleMode = auto_free(StubBattleMode.new())
	battle_stub.snapshot_to_return = RefCounted.new()
	loader.current_mode_node_value = battle_stub
	machine.request_transition(GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
	_run_to_idle(machine)
	machine.report_battle_outcome(GameStateMachine.BattleResult.DEFEAT)
	# Entry itself books a flash (battle_wipe); only the retry's own booking
	# below is this test's concern.
	gate.requests.clear()

	# Act
	var real_time_at_booking: float = machine.real_time
	var result: GameStateMachine.RequestResult = machine.choose_retry()
	assert_int(result).is_equal(GameStateMachine.RequestResult.OK)

	# Assert: booked exactly once, at the expected clock and source.
	assert_int(gate.requests.size()).is_equal(1)
	assert_bool(gate.requests[0]["source_id"] == GameStateMachine.FLASH_SOURCE_RETRY).is_true()
	assert_float(gate.requests[0]["clock"]).is_equal(real_time_at_booking)
	assert_float(gate.requests[0]["priority"]).is_equal(1.0)

	# capped == (handle == -1), passed to both play_out and play_in; true
	# during the transition in the refusing case, false after IDLE either way.
	assert_bool(machine.is_transition_flash_capped()).is_equal(capped_result)
	_run_to_idle(machine)
	assert_bool(machine.is_transition_flash_capped()).is_false()

	assert_bool(presenter.play_out_calls.back()["capped"]).is_equal(capped_result)
	assert_bool(presenter.play_in_calls.back()["capped"]).is_equal(capped_result)

	# Phase durations are identical regardless of capped.
	assert_float(presenter.play_out_calls.back()["duration"]).is_equal(
			float(env["config"].t_out[&"retry_flash"]))
	assert_float(presenter.play_in_calls.back()["duration"]).is_equal(
			float(env["config"].t_in[&"retry_flash"]))


func test_fade_never_consults_gate() -> void:
	# Arrange: fade (via request_in_mode_fade) never flashes, so the gate is
	# never asked, no matter what it would answer.
	var gate := StubFlashGate.new()
	gate.capped_result = true
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(null, gate)
	var machine: GameStateMachine = env["machine"]

	var result: GameStateMachine.RequestResult = machine.request_in_mode_fade(func() -> void: pass)
	assert_int(result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)

	assert_int(gate.requests.size()).is_equal(0)
	assert_bool(machine.is_transition_flash_capped()).is_false()


func test_null_flash_gate_never_capped() -> void:
	# Arrange: no flash gate injected (the default) -- a flashing transition
	# must still run, always uncapped.
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]

	var battle_stub: StubBattleMode = auto_free(StubBattleMode.new())
	battle_stub.snapshot_to_return = RefCounted.new()
	loader.current_mode_node_value = battle_stub
	machine.request_transition(GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
	_run_to_idle(machine)
	machine.report_battle_outcome(GameStateMachine.BattleResult.DEFEAT)
	machine.choose_retry()

	assert_bool(machine.is_transition_flash_capped()).is_false()
	_run_to_idle(machine)
	assert_bool(machine.is_transition_flash_capped()).is_false()


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()
