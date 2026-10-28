## Story 012, AC-10: a swap failure returns to the source mode with its
## frozen state restored, input unlocked, and an error logged. Written to
## the QA Test Cases in
## `production/epics/game-state-scene-flow/story-012-failed-swap-rolls-back.md`
## -- no new cases invented. Parametrized over the three failure sources the
## machine can see; `loader_failed` and `payload_commit_false` are
## mechanically identical at the machine level (both are a scripted
## `poll_swap() == FAILED`), so they share `&"loader_failed"` as their cause.
extends GdUnitTestSuite

const _SIGNAL_EVENTS: Array[StringName] = [
	&"transition_started", &"mode_exited", &"mode_entered", &"transition_finished",
	&"overlay_opened", &"overlay_closed",
]

## [source_key, expected_cause] -- each case wrapped in its own array so
## gdUnit4's parametrize runs instead of hanging.
const _FAILURE_SOURCES: Array = [
	["loader_failed", &"loader_failed"],
	["capture_null", &"capture_snapshot_null"],
	["payload_commit_false", &"loader_failed"],
]


func test_failure_rolls_back(source_key: String, expected_cause: StringName,
		test_parameters := _FAILURE_SOURCES) -> void:
	# Arrange: a machine in OVERWORLD, with a stub Overworld node that
	# `current_mode_node()` resolves to once `mode_entered(OVERWORLD)` fires --
	# the stub-loader stand-in for `ModeHostSceneLoader.rollback_swap()`'s
	# real re-attach.
	var recorder := SequenceRecorder.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder)
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var game_log: SpyGameStateLog = env["log"]
	var overworld_stub: StubOverworldMode = auto_free(StubOverworldMode.new())
	machine.mode_entered.connect(
			func(to: GameStateMachine.Mode) -> void:
				if to == GameStateMachine.Mode.OVERWORLD:
					loader.current_mode_node_value = overworld_stub)
	var source := SyntheticActionSource.new()
	machine.bind_action_source(source)

	match source_key:
		"loader_failed", "payload_commit_false":
			loader.script_results([SceneLoader.SwapStatus.PENDING, SceneLoader.SwapStatus.FAILED])
		"capture_null":
			# Base GameMode.capture_start_snapshot() returns null by default --
			# a stub battle mode that never sets snapshot_to_return fails loudly.
			var battle_stub: StubBattleMode = auto_free(StubBattleMode.new())
			loader.current_mode_node_value = battle_stub
			loader.script_results([SceneLoader.SwapStatus.DONE])
		_:
			assert_bool(false).override_failure_message(
					"unknown source_key: %s" % source_key).is_true()

	recorder.clear()
	var probe_before: Dictionary = machine.get_debug_state()

	# Act
	var result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
	assert_int(result).is_equal(GameStateMachine.RequestResult.OK)
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()

	# Assert: rolled back to the source mode, idle, no retained battle handle.
	assert_int(loader.rollback_count).is_equal(1)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.OVERWORLD)
	assert_int(machine.phase).is_equal(GameStateMachine.Phase.IDLE)
	assert_int(machine.get_debug_state()["battle_snapshot_id"]).is_equal(0)
	assert_bool(GameStateProbe.states_equal(probe_before, machine.get_debug_state())) \
			.override_failure_message("debug state did not match pre-transition state after rollback").is_true()

	# Exactly one error entry: swap_failed, cause names the source.
	assert_int(game_log.entries.size()).is_equal(1)
	var entry: Dictionary = game_log.entries[0]
	assert_bool(entry["code"] == &"swap_failed").override_failure_message(
			"expected code swap_failed, got %s" % [entry.get("code")]).is_true()
	assert_bool(entry["context"]["cause"] == expected_cause).override_failure_message(
			"expected cause %s, got %s" % [expected_cause, entry["context"].get("cause")]).is_true()

	# Pinned rollback signal sequence (ADR-0002, ruling 2026-10-23):
	# transition_started(OW, BATTLE) -> mode_exited(OW) -> mode_entered(OW) -> transition_finished(OW).
	var signal_events: Array[Dictionary] = recorder.events.filter(
			func(e: Dictionary) -> bool: return _SIGNAL_EVENTS.has(e["event"]))
	assert_array(signal_events.map(func(e: Dictionary) -> StringName: return e["event"])).is_equal([
		&"transition_started", &"mode_exited", &"mode_entered", &"transition_finished",
	])
	assert_array(signal_events[0]["args"]).is_equal(
			[GameStateMachine.Mode.OVERWORLD, GameStateMachine.Mode.BATTLE])
	assert_array(signal_events[1]["args"]).is_equal([GameStateMachine.Mode.OVERWORLD])
	assert_array(signal_events[2]["args"]).is_equal([GameStateMachine.Mode.OVERWORLD])
	assert_array(signal_events[3]["args"]).is_equal([GameStateMachine.Mode.OVERWORLD])

	# Input unlocked: the next synthetic action reaches the Overworld mode.
	source.press(&"confirm")
	assert_int(overworld_stub.handle_action_count).is_equal(1)
