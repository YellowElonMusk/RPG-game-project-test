## Story 019, AC-18: repeated Retry inputs during the Retry transition cause
## exactly one restart. Written to the QA Test Cases in
## `production/epics/game-state-scene-flow/story-019-repeated-retry-one-restart.md`.
extends GdUnitTestSuite


func test_one_restart() -> void:
	# Given: the Defeat Prompt open in BATTLE.
	var recorder := SequenceRecorder.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder)
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var battle_stub: StubBattleMode = auto_free(StubBattleMode.new())
	battle_stub.snapshot_to_return = GameStateFixtures.make_overworld_snapshot()
	battle_stub.set_recorder(recorder)
	loader.current_mode_node_value = battle_stub
	machine.request_transition(GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
	_run_to_idle(machine)
	assert_int(machine.report_battle_outcome(GameStateMachine.BattleResult.DEFEAT)).is_equal(
			GameStateMachine.RequestResult.OK)
	var prompt: StubOverlay = auto_free(StubOverlay.new())
	loader.current_overlay_node_value = prompt
	var source := SyntheticActionSource.new()
	machine.bind_action_source(source)
	recorder.clear()

	# When: choose_retry() twice, same frame (no tick between).
	assert_int(machine.choose_retry()).is_equal(GameStateMachine.RequestResult.OK)
	assert_int(machine.choose_retry()).is_equal(GameStateMachine.RequestResult.REJECTED_BUSY)

	# ...then confirm presses and choose_retry() during OUT, SWAP and IN.
	var phases_seen: Dictionary = {}
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		phases_seen[machine.phase] = true
		source.press(InputActions.CONFIRM)
		source.release(InputActions.CONFIRM)
		assert_int(machine.choose_retry()).override_failure_message(
				"phase %d" % machine.phase).is_equal(GameStateMachine.RequestResult.REJECTED_BUSY)
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(phases_seen.has(GameStateMachine.Phase.OUT)).is_true()
	assert_bool(phases_seen.has(GameStateMachine.Phase.IN)).is_true()

	# Then: one restore, one Battle -> Battle transition, nothing routed.
	assert_int(_count(recorder, &"restore_start_snapshot")).is_equal(1)
	var starts: Array = recorder.events.filter(func(e: Dictionary) -> bool:
		return e["event"] == &"transition_started" \
				and e["args"] == [GameStateMachine.Mode.BATTLE, GameStateMachine.Mode.BATTLE])
	assert_int(starts.size()).is_equal(1)
	assert_int(_count(recorder, &"transition_finished")).is_equal(1)
	assert_int(prompt.handle_action_count).is_equal(0)
	assert_int(battle_stub.handle_action_count).is_equal(0)
	# After IDLE, no Defeat is pending, so a further Retry is refused too.
	assert_int(machine.choose_retry()).is_not_equal(GameStateMachine.RequestResult.OK)


func _count(recorder: SequenceRecorder, event: StringName) -> int:
	return recorder.events.filter(func(e: Dictionary) -> bool: return e["event"] == event).size()


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).is_true()
