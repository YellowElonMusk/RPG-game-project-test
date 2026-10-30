## Story 028, AC-27: the in-mode fade (rule 2, ADR-0002 §11) -- only
## `transition_started(OVERWORLD, OVERWORLD)` and `transition_finished`, the
## callback once at a zero-length SWAP with no loader call, input locked,
## `is_save_safe()` false throughout; rejected elsewhere. Written to the QA
## Test Cases in `production/epics/game-state-scene-flow/story-028-in-mode-fade.md`.
extends GdUnitTestSuite

const _SIGNAL_EVENTS: Array[StringName] = [
	&"transition_started", &"mode_exited", &"mode_entered", &"transition_finished",
	&"overlay_opened", &"overlay_closed",
]


func test_fade_signals_and_callback() -> void:
	# Arrange
	var recorder := SequenceRecorder.new()
	var gate := StubFlashGate.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder, gate)
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var mode_node: StubOverworldMode = auto_free(StubOverworldMode.new())
	loader.current_mode_node_value = mode_node
	var source := SyntheticActionSource.new()
	machine.bind_action_source(source)
	var swaps_before: int = loader.begin_swap_count
	var calls: Array = [0]
	var callback := func() -> void:
		calls[0] += 1
		recorder.record(&"callback", [])
	recorder.clear()

	# Act
	assert_int(machine.request_in_mode_fade(callback)).is_equal(GameStateMachine.RequestResult.OK)
	var phases_seen: Dictionary = {}
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		phases_seen[machine.phase] = true
		assert_bool(machine.is_in_mode_fade()).is_true()
		assert_bool(machine.is_save_safe()).is_false()
		source.press(InputActions.CONFIRM)
		machine.tick(1.0 / 60.0)
		ticks += 1

	# Assert
	assert_bool(phases_seen.has(GameStateMachine.Phase.OUT)).is_true()
	assert_bool(phases_seen.has(GameStateMachine.Phase.IN)).is_true()
	var signals: Array = recorder.events.filter(
			func(e: Dictionary) -> bool: return _SIGNAL_EVENTS.has(e["event"]))
	assert_int(signals.size()).is_equal(2)
	assert_str(String(signals[0]["event"])).is_equal("transition_started")
	assert_array(signals[0]["args"]).is_equal(
			[GameStateMachine.Mode.OVERWORLD, GameStateMachine.Mode.OVERWORLD])
	assert_str(String(signals[1]["event"])).is_equal("transition_finished")
	assert_array(signals[1]["args"]).is_equal([GameStateMachine.Mode.OVERWORLD])
	assert_int(calls[0]).is_equal(1)
	var cb_index: int = recorder.index_of(&"callback")
	assert_int(cb_index).is_greater(recorder.index_of(&"transition_started"))
	assert_int(cb_index).is_less(recorder.index_of(&"transition_finished"))
	assert_int(loader.begin_swap_count).is_equal(swaps_before)
	assert_int(mode_node.handle_action_count).is_equal(0)
	assert_bool(machine.is_in_mode_fade()).is_false()
	assert_array(gate.requests).is_empty()
	assert_bool(is_same(loader.current_mode_node(), mode_node)).is_true()


## (case, expected) -- every source where the fade is illegal.
const _REJECT_CASES: Array = [
	[&"battle", GameStateMachine.RequestResult.REJECTED_INVALID_PAIR],
	[&"camp", GameStateMachine.RequestResult.REJECTED_INVALID_PAIR],
	[&"overworld_dialogue", GameStateMachine.RequestResult.REJECTED_OVERLAY_BLOCKS],
	[&"overworld_menu", GameStateMachine.RequestResult.REJECTED_OVERLAY_BLOCKS],
	[&"overworld_out", GameStateMachine.RequestResult.REJECTED_BUSY],
]


func test_fade_rejected_elsewhere(source_case: StringName, expected: int,
		test_parameters := _REJECT_CASES) -> void:
	var machine: GameStateMachine = _machine_for(source_case)
	var calls: Array = [0]
	var probe_before: Dictionary = machine.get_debug_state()

	var result: GameStateMachine.RequestResult = machine.request_in_mode_fade(
			func() -> void: calls[0] += 1)

	assert_int(result).is_equal(expected)
	assert_bool(GameStateProbe.states_equal(probe_before, machine.get_debug_state())).is_true()
	_run_to_idle(machine)
	assert_int(calls[0]).is_equal(0)


## (case, expected is_save_safe)
const _SAVE_SAFE_CASES: Array = [
	[&"overworld", true],
	[&"camp", true],
	[&"overworld_menu", true],
	[&"overworld_dialogue", false],
	[&"battle", false],
	[&"title", false],
	[&"overworld_out", false],
]


func test_is_save_safe_table(source_case: StringName, expected: bool,
		test_parameters := _SAVE_SAFE_CASES) -> void:
	var machine: GameStateMachine = _machine_for(source_case)
	assert_bool(machine.is_save_safe()).is_equal(expected)


func test_invalid_callable_rejected() -> void:
	var machine: GameStateMachine = GameStateFixtures.make_machine_in_overworld()["machine"]
	var probe_before: Dictionary = machine.get_debug_state()
	assert_int(machine.request_in_mode_fade(Callable())).is_equal(
			GameStateMachine.RequestResult.REJECTED_INVALID_PAYLOAD)
	assert_bool(GameStateProbe.states_equal(probe_before, machine.get_debug_state())).is_true()


func test_freed_callback_logs_and_in_still_plays() -> void:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var presenter: StubTransitionPresenter = env["presenter"]
	var game_log: SpyGameStateLog = env["log"]
	var target := Node.new()
	assert_int(machine.request_in_mode_fade(Callable(target, "get_child_count"))).is_equal(
			GameStateMachine.RequestResult.OK)
	target.free()   # freed before SWAP
	var play_in_before: int = presenter.play_in_calls.size()

	_run_to_idle(machine)

	assert_int(game_log.entries.filter(func(e: Dictionary) -> bool:
		return e["code"] == &"in_mode_fade_callback_invalid").size()).is_equal(1)
	assert_int(presenter.play_in_calls.size()).is_equal(play_in_before + 1)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.OVERWORLD)


func test_focus_lost_during_fade_opens_menu_after_finish() -> void:
	var recorder := SequenceRecorder.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder)
	var machine: GameStateMachine = env["machine"]
	var source := SyntheticActionSource.new()
	machine.bind_action_source(source)
	recorder.clear()
	machine.request_in_mode_fade(func() -> void: pass)

	source.lose_focus()
	assert_array(machine.overlay_stack).is_empty()
	_run_to_idle(machine)

	assert_array(machine.overlay_stack).is_equal([GameStateMachine.OverlayKind.MENU])
	assert_int(recorder.index_of(&"overlay_opened")).is_greater(
			recorder.index_of(&"transition_finished"))


func test_quit_during_fade_waits_for_finish() -> void:
	var recorder := SequenceRecorder.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder)
	var machine: GameStateMachine = env["machine"]
	var quit_spy: QuitSpy = env["quit_spy"]
	recorder.clear()
	machine.request_in_mode_fade(func() -> void: pass)

	machine.request_quit()
	assert_int(quit_spy.call_count).is_equal(0)
	_run_to_idle(machine)

	assert_int(quit_spy.call_count).is_equal(1)
	assert_int(recorder.index_of(&"quit")).is_greater(recorder.index_of(&"transition_finished"))


func _machine_for(source_case: StringName) -> GameStateMachine:
	if source_case == &"title":
		var machine_title := GameStateMachine.new(StubSceneLoader.new(),
				StubTransitionPresenter.new(), GameStateFixtures.make_transition_config(),
				GameStateFixtures.make_ready_catalog(), QuitSpy.new().as_callable(),
				SpyGameStateLog.new())
		machine_title.tick(0.0)
		_run_to_idle(machine_title)
		return machine_title
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	match source_case:
		&"battle":
			var loader: StubSceneLoader = env["loader"]
			var battle_stub: StubBattleMode = auto_free(StubBattleMode.new())
			battle_stub.snapshot_to_return = GameStateFixtures.make_overworld_snapshot()
			loader.current_mode_node_value = battle_stub
			machine.request_transition(GameStateMachine.Mode.BATTLE,
					GameStateFixtures.valid_battle_entry())
			_run_to_idle(machine)
		&"camp":
			var payload := CampEntryPayload.new()
			payload.camp_id = "camp_a"
			machine.request_transition(GameStateMachine.Mode.CAMP, payload)
			_run_to_idle(machine)
		&"overworld_dialogue":
			machine.open_overlay(GameStateMachine.OverlayKind.DIALOGUE)
		&"overworld_menu":
			machine.open_overlay(GameStateMachine.OverlayKind.MENU)
		&"overworld_out":
			machine.request_transition(GameStateMachine.Mode.OVERWORLD, null)
			assert_int(machine.phase).is_equal(GameStateMachine.Phase.OUT)
	return machine


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).is_true()
