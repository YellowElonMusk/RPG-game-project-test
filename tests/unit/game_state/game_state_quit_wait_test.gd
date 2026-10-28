## Story 011, AC-9: Quit during a running transition is accepted (never
## rejected busy) and the injected quit hook fires exactly once, strictly
## after `transition_finished`. Written to the QA Test Cases in
## `production/epics/game-state-scene-flow/story-011-quit-waits-for-transition.md` --
## no new cases invented.
extends GdUnitTestSuite

## Phase in {OUT, SWAP, IN} -- the three points a running transition can be
## stopped at, per the QA Test Cases.
const _PHASES: Array = [["OUT"], ["SWAP"], ["IN"]]


func test_quit_hook_after_transition_finished(phase_name: String,
		test_parameters := _PHASES) -> void:
	# Arrange: Overworld -> Battle stopped in the given phase; the quit spy
	# writes to the shared sequence recorder.
	var state: Dictionary = _arrange_stopped_in_phase(phase_name)
	var machine: GameStateMachine = state["machine"]
	var recorder: SequenceRecorder = state["recorder"]
	var quit_spy: QuitSpy = state["quit_spy"]

	# Act: request_quit() x3 -- each returns OK, and quit_pending stays set
	# (never stacking) until the transition finishes.
	for i in range(3):
		var result: GameStateMachine.RequestResult = machine.request_quit()
		assert_int(result).is_equal(GameStateMachine.RequestResult.OK)
	assert_bool(machine.get_debug_state()["quit_pending"] as bool) \
			.override_failure_message("quit_pending should be true while the transition runs") \
			.is_true()
	assert_int(quit_spy.call_count).is_equal(0)

	# Act: tick the transition to completion.
	_finish_transition_to_idle(machine)

	# Assert: the hook fired exactly once, and strictly after transition_finished.
	assert_int(quit_spy.call_count).is_equal(1)
	assert_bool(machine.get_debug_state()["quit_pending"] as bool) \
			.override_failure_message("quit_pending should clear once the hook fires").is_false()
	var finished_index: int = recorder.index_of(&"transition_finished")
	var quit_index: int = recorder.index_of(&"quit")
	assert_int(finished_index).is_greater(-1)
	assert_int(quit_index).is_greater(finished_index)


## Drives the Overworld -> Battle transition and stops it in `phase_name`
## (`"OUT"`, `"SWAP"` or `"IN"`), with the stub loader held PENDING for SWAP.
## Copied from `game_state_busy_rejection_test.gd`'s `_arrange_stopped_in_phase`.
func _arrange_stopped_in_phase(phase_name: String) -> Dictionary:
	var recorder := SequenceRecorder.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder)
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var cfg: TransitionConfig = env["config"]
	var quit_spy: QuitSpy = env["quit_spy"]
	recorder.clear()
	loader.script_results([SceneLoader.SwapStatus.PENDING, SceneLoader.SwapStatus.DONE])

	var result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
	assert_int(result).is_equal(GameStateMachine.RequestResult.OK)

	match phase_name:
		"OUT":
			pass   # already stopped at the start of OUT
		"SWAP":
			machine.tick(cfg.t_out[&"battle_wipe"])   # ends OUT -> SWAP
			machine.tick(1.0 / 60.0)                   # poll #1: PENDING, held
		"IN":
			machine.tick(cfg.t_out[&"battle_wipe"])   # ends OUT -> SWAP
			machine.tick(1.0 / 60.0)                   # poll #1: PENDING, held
			machine.tick(1.0 / 60.0)                   # poll #2: DONE -> begins IN
		_:
			assert_bool(false).override_failure_message(
					"unknown phase_name: %s" % phase_name).is_true()

	var expected_phase: GameStateMachine.Phase = GameStateMachine.Phase.OUT
	if phase_name == "SWAP":
		expected_phase = GameStateMachine.Phase.SWAP
	elif phase_name == "IN":
		expected_phase = GameStateMachine.Phase.IN
	assert_int(machine.phase).is_equal(expected_phase)

	return {"machine": machine, "loader": loader, "cfg": cfg, "recorder": recorder, "quit_spy": quit_spy}


## Bounded 1/60s-tick loop (as in the busy-rejection test) until the
## transition that was stopped mid-flight reaches IDLE in BATTLE.
func _finish_transition_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)
