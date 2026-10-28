## Story 001, AC-5: Overworld -> Battle fires exactly the four transition
## signals, once each, in order. Written to the QA Test Cases in
## `production/epics/game-state-scene-flow/story-001-overworld-to-battle-signal-order.md` --
## no new cases invented.
extends GdUnitTestSuite

const _SIGNAL_EVENTS: Array[StringName] = [
	&"transition_started", &"mode_exited", &"mode_entered", &"transition_finished",
	&"overlay_opened", &"overlay_closed",
]


func _signal_events_only(events: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in events:
		if _SIGNAL_EVENTS.has(e["event"]):
			out.append(e)
	return out


func test_overworld_to_battle_fires_four_signals_in_order() -> void:
	# Arrange: a machine in OVERWORLD via the fixture path, then a cleared recorder.
	var recorder := SequenceRecorder.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder)
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var cfg: TransitionConfig = env["config"]
	recorder.clear()
	loader.script_results([SceneLoader.SwapStatus.PENDING, SceneLoader.SwapStatus.DONE])

	# Act
	var result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
	assert_int(result).is_equal(GameStateMachine.RequestResult.OK)
	machine.tick(cfg.t_out[&"battle_wipe"])   # ends OUT
	machine.tick(1.0 / 60.0)                   # SWAP poll #1: PENDING
	machine.tick(1.0 / 60.0)                   # SWAP poll #2: DONE
	machine.tick(cfg.t_in[&"battle_wipe"])     # ends IN

	# Assert: exactly these four signals, once each, in order; no overlay signals.
	var signal_events: Array[Dictionary] = _signal_events_only(recorder.events)
	assert_array(signal_events.map(func(e: Dictionary) -> StringName: return e["event"])) \
			.is_equal([
				&"transition_started", &"mode_exited", &"mode_entered", &"transition_finished",
			])
	assert_array(signal_events[0]["args"]).is_equal(
			[GameStateMachine.Mode.OVERWORLD, GameStateMachine.Mode.BATTLE])
	assert_array(signal_events[1]["args"]).is_equal([GameStateMachine.Mode.OVERWORLD])
	assert_array(signal_events[2]["args"]).is_equal([GameStateMachine.Mode.BATTLE])
	assert_array(signal_events[3]["args"]).is_equal([GameStateMachine.Mode.BATTLE])

	# play_out before mode_exited; play_in after mode_entered (fire-and-forget,
	# never a completion callback -- the stub records only the call itself).
	var mode_exited_index: int = recorder.index_of(&"mode_exited")
	var mode_entered_index: int = recorder.index_of(&"mode_entered")
	var play_out_index: int = recorder.index_of(&"play_out")
	var play_in_index: int = recorder.index_of(&"play_in")
	assert_int(play_out_index).is_greater_equal(0)
	assert_int(play_in_index).is_greater_equal(0)
	assert_bool(play_out_index < mode_exited_index).override_failure_message(
			"expected play_out before mode_exited").is_true()
	assert_bool(play_in_index > mode_entered_index).override_failure_message(
			"expected play_in after mode_entered").is_true()
	assert_array(recorder.events[play_out_index]["args"]).is_equal(
			[&"battle_wipe", cfg.t_out[&"battle_wipe"], false])
	assert_array(recorder.events[play_in_index]["args"]).is_equal(
			[&"battle_wipe", cfg.t_in[&"battle_wipe"], false])

	assert_int(machine.phase).is_equal(GameStateMachine.Phase.IDLE)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)


func test_overworld_to_battle_sequence_holds_with_sixtieth_second_ticks() -> void:
	# Edge case: 1/60s ticks instead of whole-phase ticks give the same
	# sequence (bounded loop, max 600 ticks).
	var recorder := SequenceRecorder.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder)
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	recorder.clear()
	loader.script_results([SceneLoader.SwapStatus.PENDING, SceneLoader.SwapStatus.DONE])

	var result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
	assert_int(result).is_equal(GameStateMachine.RequestResult.OK)

	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()

	var signal_events: Array[Dictionary] = _signal_events_only(recorder.events)
	assert_array(signal_events.map(func(e: Dictionary) -> StringName: return e["event"])) \
			.is_equal([
				&"transition_started", &"mode_exited", &"mode_entered", &"transition_finished",
			])
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)


func test_stub_overworld_mode_is_a_game_mode() -> void:
	# Every double subclasses GameMode: on 4.7.2 `GameMode.new()` is a parser
	# error ("Cannot construct abstract class"), so a test cannot use the base.
	var stub: StubOverworldMode = auto_free(StubOverworldMode.new())
	assert_bool(stub is GameMode).is_true()
