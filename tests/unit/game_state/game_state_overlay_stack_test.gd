## Story 022, AC-19: with overlays stacked Dialogue then Menu, only the top
## overlay receives input; `close_overlay()` pops the top only, and
## `overlay_opened`/`overlay_closed` fire in stack order. Written to the QA
## Test Cases in
## `production/epics/game-state-scene-flow/story-022-overlay-stack-input-and-order.md`
## -- no new cases invented.
extends GdUnitTestSuite


func test_top_overlay_owns_input() -> void:
	# Arrange: Overworld, idle. A stub mode stands in for ModeHost's live
	# node (any GameMode double works here, same convention as
	# game_state_input_lock_test.gd); separate counting overlays stand in
	# for OverlayHost's top entry, swapped into the stub loader as each
	# push/pop would leave it on top (the real multi-node OverlayHost wiring
	# is story 030's concern, not this one's).
	var recorder := SequenceRecorder.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder)
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]

	var mode: StubBattleMode = auto_free(StubBattleMode.new())
	loader.current_mode_node_value = mode
	var dialogue: StubOverlay = auto_free(StubOverlay.new())
	var menu: StubOverlay = auto_free(StubOverlay.new())

	var source := SyntheticActionSource.new()
	machine.bind_action_source(source)
	recorder.clear()

	# Act: open_overlay(DIALOGUE) then open_overlay(MENU), each OK.
	loader.current_overlay_node_value = dialogue
	var open_dialogue: GameStateMachine.RequestResult = machine.open_overlay(
			GameStateMachine.OverlayKind.DIALOGUE)
	assert_int(open_dialogue).is_equal(GameStateMachine.RequestResult.OK)

	loader.current_overlay_node_value = menu
	var open_menu: GameStateMachine.RequestResult = machine.open_overlay(
			GameStateMachine.OverlayKind.MENU)
	assert_int(open_menu).is_equal(GameStateMachine.RequestResult.OK)

	# Assert: overlay_stack is [DIALOGUE, MENU] bottom first, while both are
	# open; mutating the returned copy leaves the machine's own state alone.
	var expected_both: Array[GameStateMachine.OverlayKind] = [
		GameStateMachine.OverlayKind.DIALOGUE, GameStateMachine.OverlayKind.MENU]
	assert_array(machine.overlay_stack).is_equal(expected_both)
	var stack_copy: Array = machine.overlay_stack
	stack_copy.clear()
	assert_array(machine.get_debug_state()["overlay_stack"]).is_equal(expected_both)

	# Assert: is_input_owner(mode) is false while any overlay is open.
	assert_bool(machine.is_input_owner(mode)).is_false()

	# Act: two synthetic confirms, routed to the top (Menu) only.
	source.press(&"confirm")
	source.press(&"confirm")

	# Assert (before the first close): Menu got both, Dialogue and the mode
	# got none.
	assert_int(menu.handle_action_count).is_equal(2)
	assert_int(dialogue.handle_action_count).is_equal(0)
	assert_int(mode.handle_action_count).is_equal(0)

	# Act: close_overlay() pops the top (Menu) only. The stub loader is
	# re-armed to report Dialogue as current -- what pop leaves on top in
	# the real OverlayHost (story 030).
	loader.current_overlay_node_value = dialogue
	var close_menu: GameStateMachine.RequestResult = machine.close_overlay()
	assert_int(close_menu).is_equal(GameStateMachine.RequestResult.OK)
	var expected_dialogue_only: Array[GameStateMachine.OverlayKind] = [
		GameStateMachine.OverlayKind.DIALOGUE]
	assert_array(machine.overlay_stack).is_equal(expected_dialogue_only)

	# Act: one more synthetic confirm, now routed to Dialogue.
	source.press(&"confirm")

	# Assert (after the first close): Dialogue got exactly one; Menu's count
	# is unchanged; the mode still got none.
	assert_int(dialogue.handle_action_count).is_equal(1)
	assert_int(menu.handle_action_count).is_equal(2)
	assert_int(mode.handle_action_count).is_equal(0)

	# Act: close_overlay() again, popping Dialogue, leaving no overlay open.
	var close_dialogue: GameStateMachine.RequestResult = machine.close_overlay()
	assert_int(close_dialogue).is_equal(GameStateMachine.RequestResult.OK)
	var expected_empty: Array[GameStateMachine.OverlayKind] = []
	assert_array(machine.overlay_stack).is_equal(expected_empty)

	# Assert: overlay_opened/overlay_closed fired in stack order.
	var overlay_signal_events: Array[Dictionary] = recorder.events.filter(
			func(e: Dictionary) -> bool:
				return e["event"] == &"overlay_opened" or e["event"] == &"overlay_closed")
	assert_array(overlay_signal_events.map(func(e: Dictionary) -> StringName: return e["event"])) \
			.is_equal([&"overlay_opened", &"overlay_opened", &"overlay_closed", &"overlay_closed"])
	assert_array(overlay_signal_events[0]["args"]).is_equal([GameStateMachine.OverlayKind.DIALOGUE])
	assert_array(overlay_signal_events[1]["args"]).is_equal([GameStateMachine.OverlayKind.MENU])
	assert_array(overlay_signal_events[2]["args"]).is_equal([GameStateMachine.OverlayKind.MENU])
	assert_array(overlay_signal_events[3]["args"]).is_equal([GameStateMachine.OverlayKind.DIALOGUE])

	# Edge case: the stub loader recorded push/pop in the same order.
	var overlay_loader_events: Array[Dictionary] = recorder.events.filter(
			func(e: Dictionary) -> bool:
				return e["event"] == &"push_overlay" or e["event"] == &"pop_overlay")
	assert_array(overlay_loader_events.map(func(e: Dictionary) -> StringName: return e["event"])) \
			.is_equal([&"push_overlay", &"push_overlay", &"pop_overlay", &"pop_overlay"])
