## Story 025, AC-20: the Menu overlay stops `mode_time` by disabling
## `ModeHost` through the injected loader (`set_mode_time_stopped`), never
## through `SceneTree.paused`. Dialogue does not stop it. While the Menu is
## open, every transition is rejected except Quit to Title, which the Menu
## itself may start regardless of what mode is underneath or whether a
## frozen Overworld is waiting to be freed. Written to the QA Test Cases in
## `production/epics/game-state-scene-flow/story-025-menu-stops-time-quit-to-title.md`
## -- no new cases invented.
extends GdUnitTestSuite


func test_menu_stops_mode_time() -> void:
	# Arrange: OVERWORLD, idle, mode_time recorded.
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var mode_time_before: float = machine.mode_time

	# Act: open_overlay(MENU); tick 1.0s in 1/60 steps.
	var open_result: GameStateMachine.RequestResult = machine.open_overlay(
			GameStateMachine.OverlayKind.MENU)
	assert_int(open_result).is_equal(GameStateMachine.RequestResult.OK)
	for i in range(60):
		machine.tick(1.0 / 60.0)

	# Assert: mode_time unchanged while the Menu is open.
	assert_float(machine.mode_time).is_equal_approx(mode_time_before, 1e-6)

	# Act: close_overlay(); tick 0.5s.
	var close_result: GameStateMachine.RequestResult = machine.close_overlay()
	assert_int(close_result).is_equal(GameStateMachine.RequestResult.OK)
	for i in range(30):
		machine.tick(1.0 / 60.0)

	# Assert: +0.5 (within 1e-6) after the Menu closes.
	assert_float(machine.mode_time).is_equal_approx(mode_time_before + 0.5, 1e-6)

	# Assert: loader.set_mode_time_stopped(true) then (false).
	assert_array(loader.set_mode_time_stopped_calls).is_equal([true, false])


func test_dialogue_does_not_stop_time() -> void:
	# Arrange: OVERWORLD, idle, mode_time recorded.
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var mode_time_before: float = machine.mode_time

	# Act: open_overlay(DIALOGUE); tick 0.5s.
	var open_result: GameStateMachine.RequestResult = machine.open_overlay(
			GameStateMachine.OverlayKind.DIALOGUE)
	assert_int(open_result).is_equal(GameStateMachine.RequestResult.OK)
	for i in range(30):
		machine.tick(1.0 / 60.0)

	# Assert: mode_time advances; the loader's time-stop hook is never touched.
	assert_float(machine.mode_time).is_equal_approx(mode_time_before + 0.5, 1e-6)
	assert_array(loader.set_mode_time_stopped_calls).is_equal([])


func test_transition_rejected_quit_to_title_ok_menu_over_overworld() -> void:
	# Arrange: OVERWORLD, idle, Menu open.
	var recorder := SequenceRecorder.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder)
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]

	var open_result: GameStateMachine.RequestResult = machine.open_overlay(
			GameStateMachine.OverlayKind.MENU)
	assert_int(open_result).is_equal(GameStateMachine.RequestResult.OK)
	recorder.clear()

	# Act: request_transition(CAMP) is rejected; debug state unchanged.
	var probe_before: Dictionary = machine.get_debug_state()
	var camp_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.CAMP)
	assert_int(camp_result).is_equal(GameStateMachine.RequestResult.REJECTED_OVERLAY_BLOCKS)
	assert_bool(GameStateProbe.states_equal(probe_before, machine.get_debug_state())) \
			.override_failure_message("debug state changed after a rejected transition").is_true()

	# Act: request_transition(TITLE) succeeds.
	var title_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.TITLE)
	assert_int(title_result).is_equal(GameStateMachine.RequestResult.OK)

	# Assert: overlay_closed(MENU) precedes transition_started(OVERWORLD, TITLE);
	# set_mode_time_stopped(false) called.
	var overlay_closed_index: int = recorder.index_of(&"overlay_closed")
	var transition_started_index: int = recorder.index_of(&"transition_started")
	assert_int(overlay_closed_index).is_greater_equal(0)
	assert_int(transition_started_index).is_greater(overlay_closed_index)
	assert_array(recorder.events[overlay_closed_index]["args"]).is_equal(
			[GameStateMachine.OverlayKind.MENU])
	assert_array(recorder.events[transition_started_index]["args"]).is_equal(
			[GameStateMachine.Mode.OVERWORLD, GameStateMachine.Mode.TITLE])
	assert_array(loader.set_mode_time_stopped_calls).is_equal([true, false])

	# Act: run the transition to IDLE.
	_run_to_idle(machine)

	# Assert: mode TITLE.
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.TITLE)


func test_transition_rejected_quit_to_title_ok_menu_over_dialogue_over_overworld() -> void:
	# Arrange: OVERWORLD, idle, Dialogue open then Menu open over it.
	var recorder := SequenceRecorder.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder)
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]

	var open_dialogue: GameStateMachine.RequestResult = machine.open_overlay(
			GameStateMachine.OverlayKind.DIALOGUE)
	assert_int(open_dialogue).is_equal(GameStateMachine.RequestResult.OK)
	var open_menu: GameStateMachine.RequestResult = machine.open_overlay(
			GameStateMachine.OverlayKind.MENU)
	assert_int(open_menu).is_equal(GameStateMachine.RequestResult.OK)
	recorder.clear()

	# Act: request_transition(CAMP) is rejected; debug state unchanged.
	var probe_before: Dictionary = machine.get_debug_state()
	var camp_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.CAMP)
	assert_int(camp_result).is_equal(GameStateMachine.RequestResult.REJECTED_OVERLAY_BLOCKS)
	assert_bool(GameStateProbe.states_equal(probe_before, machine.get_debug_state())) \
			.override_failure_message("debug state changed after a rejected transition").is_true()

	# Act: request_transition(TITLE) succeeds.
	var title_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.TITLE)
	assert_int(title_result).is_equal(GameStateMachine.RequestResult.OK)

	# Assert: overlay_closed fires top-down (Menu, then Dialogue), both before
	# transition_started; set_mode_time_stopped(false) called exactly once.
	var first_closed_index: int = recorder.index_of(&"overlay_closed")
	var second_closed_index: int = recorder.index_of(&"overlay_closed", first_closed_index + 1)
	var transition_started_index: int = recorder.index_of(&"transition_started")
	assert_int(first_closed_index).is_greater_equal(0)
	assert_int(second_closed_index).is_greater(first_closed_index)
	assert_int(transition_started_index).is_greater(second_closed_index)
	assert_array(recorder.events[first_closed_index]["args"]).is_equal(
			[GameStateMachine.OverlayKind.MENU])
	assert_array(recorder.events[second_closed_index]["args"]).is_equal(
			[GameStateMachine.OverlayKind.DIALOGUE])
	assert_array(recorder.events[transition_started_index]["args"]).is_equal(
			[GameStateMachine.Mode.OVERWORLD, GameStateMachine.Mode.TITLE])
	assert_array(loader.set_mode_time_stopped_calls).is_equal([true, false])

	# Act: run the transition to IDLE.
	_run_to_idle(machine)

	# Assert: mode TITLE.
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.TITLE)


func test_transition_rejected_quit_to_title_ok_menu_over_battle_frees_frozen_overworld() -> void:
	# Arrange: BATTLE (with a conceptually frozen Overworld, ADR-0002 §4),
	# idle, Menu open.
	var recorder := SequenceRecorder.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder)
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]

	var battle_stub: StubBattleMode = auto_free(StubBattleMode.new())
	battle_stub.snapshot_to_return = GameStateFixtures.make_overworld_snapshot()
	loader.current_mode_node_value = battle_stub

	var battle_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
	assert_int(battle_result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)

	var open_menu: GameStateMachine.RequestResult = machine.open_overlay(
			GameStateMachine.OverlayKind.MENU)
	assert_int(open_menu).is_equal(GameStateMachine.RequestResult.OK)
	recorder.clear()
	loader.free_frozen_overworld_count = 0

	# Act: request_transition(CAMP) is rejected; debug state unchanged.
	var probe_before: Dictionary = machine.get_debug_state()
	var camp_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.CAMP)
	assert_int(camp_result).is_equal(GameStateMachine.RequestResult.REJECTED_OVERLAY_BLOCKS)
	assert_bool(GameStateProbe.states_equal(probe_before, machine.get_debug_state())) \
			.override_failure_message("debug state changed after a rejected transition").is_true()

	# Act: request_transition(TITLE) succeeds.
	var title_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.TITLE)
	assert_int(title_result).is_equal(GameStateMachine.RequestResult.OK)

	# Assert: overlay_closed(MENU) precedes transition_started(BATTLE, TITLE);
	# set_mode_time_stopped(false) called; free_frozen_overworld called once.
	var overlay_closed_index: int = recorder.index_of(&"overlay_closed")
	var transition_started_index: int = recorder.index_of(&"transition_started")
	assert_int(overlay_closed_index).is_greater_equal(0)
	assert_int(transition_started_index).is_greater(overlay_closed_index)
	assert_array(recorder.events[transition_started_index]["args"]).is_equal(
			[GameStateMachine.Mode.BATTLE, GameStateMachine.Mode.TITLE])
	assert_array(loader.set_mode_time_stopped_calls).is_equal([true, false])
	assert_int(loader.free_frozen_overworld_count).is_equal(1)

	# Act: run the transition to IDLE.
	_run_to_idle(machine)

	# Assert: mode TITLE.
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.TITLE)


## Bounded 1/60s-tick loop until the transition reaches IDLE.
func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()
