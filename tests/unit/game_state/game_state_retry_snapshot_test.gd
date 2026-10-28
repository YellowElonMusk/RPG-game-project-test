## Story 017, AC-15: Defeat opens the Defeat Prompt; Retry restores the
## battle's starting snapshot on the same instance, with zero scene loads.
## Written to the QA Test Cases in
## `production/epics/game-state-scene-flow/story-017-defeat-prompt-and-retry-snapshot.md`
## -- no new cases invented. The test mutates every snapshot component before
## Defeat (QA fix) so "equals the starting snapshot" cannot pass vacuously.
extends GdUnitTestSuite

const _SIGNAL_EVENTS: Array[StringName] = [
	&"transition_started", &"mode_exited", &"mode_entered", &"transition_finished",
	&"overlay_opened", &"overlay_closed",
]


func test_defeat_opens_prompt_and_retry_restores() -> void:
	# Arrange: a machine in OVERWORLD, then entered into BATTLE with a stub
	# Battle mode whose capture_start_snapshot() hands back a deep copy of
	# the fixture battle-start state.
	var recorder := SequenceRecorder.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder)
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]

	var battle_stub: StubBattleMode = auto_free(StubBattleMode.new())
	battle_stub.battle_state = GameStateFixtures.battle_start_state()
	var snapshot := BattleStateSnapshot.new()
	snapshot.state = battle_stub.battle_state.duplicate(true)
	battle_stub.snapshot_to_return = snapshot
	battle_stub.set_recorder(recorder)
	loader.current_mode_node_value = battle_stub

	var result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
	assert_int(result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)

	var loads_before_retry: int = loader.begin_swap_count
	recorder.clear()

	# The test mutates every snapshot component before Defeat (QA fix): hp
	# -10, one item consumed, a state added, one enemy removed.
	battle_stub.battle_state["party_hp"]["hero"] -= 10
	battle_stub.battle_state["items"].pop_back()
	battle_stub.battle_state["states"].append("poisoned")
	battle_stub.battle_state["enemy_group"].pop_back()

	# Act: Defeat opens the prompt, then Retry runs Battle -> Battle.
	var outcome_result: GameStateMachine.RequestResult = machine.report_battle_outcome(
			GameStateMachine.BattleResult.DEFEAT)
	assert_int(outcome_result).is_equal(GameStateMachine.RequestResult.OK)
	var expected_stack: Array[GameStateMachine.OverlayKind] = [GameStateMachine.OverlayKind.DEFEAT_PROMPT]
	assert_array(machine.overlay_stack).is_equal(expected_stack)

	var retry_result: GameStateMachine.RequestResult = machine.choose_retry()
	assert_int(retry_result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)

	# Assert: restored on the same instance, zero loads, state matches the
	# original fixture (not the mutated state).
	assert_int(loader.begin_swap_count).is_equal(loads_before_retry)
	assert_object(battle_stub.restored_snapshot).is_same(snapshot)
	assert_bool(battle_stub.battle_state == GameStateFixtures.battle_start_state()) \
			.override_failure_message("restored battle_state did not deep-equal the starting fixture").is_true()

	# overlay_opened(DEFEAT_PROMPT) happened before this scenario's recorder
	# window (it fired on report_battle_outcome, before clear()); confirm
	# overlay_closed(DEFEAT_PROMPT) is first in this window, before
	# transition_started(BATTLE, BATTLE).
	var close_index: int = recorder.index_of(&"overlay_closed")
	var started_index: int = recorder.index_of(&"transition_started")
	assert_int(close_index).is_greater_equal(0)
	assert_int(started_index).is_greater(close_index)
	var expected_close_args: Array[GameStateMachine.OverlayKind] = [GameStateMachine.OverlayKind.DEFEAT_PROMPT]
	assert_array(recorder.events[close_index]["args"]).is_equal(expected_close_args)

	# restore_start_snapshot called exactly once this window.
	var restore_calls: Array[Dictionary] = recorder.events.filter(
			func(e: Dictionary) -> bool: return e["event"] == &"restore_start_snapshot")
	assert_int(restore_calls.size()).is_equal(1)

	# Four transition signals, from == to == BATTLE, in order (overlay_opened
	# and overlay_closed are asserted separately above).
	var transition_events: Array[StringName] = [
		&"transition_started", &"mode_exited", &"mode_entered", &"transition_finished",
	]
	var signal_events: Array[Dictionary] = recorder.events.filter(
			func(e: Dictionary) -> bool: return transition_events.has(e["event"]))
	assert_array(signal_events.map(func(e: Dictionary) -> StringName: return e["event"])).is_equal([
		&"transition_started", &"mode_exited", &"mode_entered", &"transition_finished",
	])
	for e: Dictionary in signal_events:
		for arg: Variant in e["args"]:
			assert_int(arg).is_equal(GameStateMachine.Mode.BATTLE)


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()
