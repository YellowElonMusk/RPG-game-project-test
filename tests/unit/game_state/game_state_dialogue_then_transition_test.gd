## Story 027, AC-32 (rule 11): a Dialogue line that requests a transition
## closes its overlay first, so `overlay_closed(DIALOGUE)` precedes
## `transition_started`; a request without closing is rejected. Written to the
## QA Test Cases in
## `production/epics/game-state-scene-flow/story-027-dialogue-closes-before-transition.md`.
## The "line" stands in for the future Dialogue system (ADR-0002 §11).
extends GdUnitTestSuite


func test_close_then_request_same_frame() -> void:
	# Arrange: OVERWORLD with a stub Dialogue overlay open.
	var recorder := SequenceRecorder.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder)
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	loader.current_overlay_node_value = auto_free(StubOverlay.new())
	assert_int(machine.open_overlay(GameStateMachine.OverlayKind.DIALOGUE)).is_equal(
			GameStateMachine.RequestResult.OK)
	recorder.clear()

	# Act: the line closes then requests, with no tick between.
	var results: Array = _dialogue_line(machine)

	# Assert
	assert_int(results[0]).is_equal(GameStateMachine.RequestResult.OK)
	assert_int(results[1]).is_equal(GameStateMachine.RequestResult.OK)
	var closed_index: int = _index_of(recorder, &"overlay_closed",
			[GameStateMachine.OverlayKind.DIALOGUE])
	var started_index: int = _index_of(recorder, &"transition_started",
			[GameStateMachine.Mode.OVERWORLD, GameStateMachine.Mode.CAMP])
	assert_int(closed_index).is_greater_equal(0)
	assert_int(started_index).is_greater(closed_index)


func test_request_without_close_rejected() -> void:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	assert_int(machine.open_overlay(GameStateMachine.OverlayKind.DIALOGUE)).is_equal(
			GameStateMachine.RequestResult.OK)
	var probe_before: Dictionary = machine.get_debug_state()

	var result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.CAMP, _camp_payload())

	assert_int(result).is_equal(GameStateMachine.RequestResult.REJECTED_OVERLAY_BLOCKS)
	assert_bool(GameStateProbe.states_equal(probe_before, machine.get_debug_state())).is_true()


## The stub Dialogue line: requester closes first (ADR-0002 §11).
func _dialogue_line(machine: GameStateMachine) -> Array:
	var close_result: GameStateMachine.RequestResult = machine.close_overlay()
	var request_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.CAMP, _camp_payload())
	return [close_result, request_result]


func _camp_payload() -> CampEntryPayload:
	var payload := CampEntryPayload.new()
	payload.camp_id = "camp_a"
	return payload


func _index_of(recorder: SequenceRecorder, event: StringName, args: Array) -> int:
	for i in range(recorder.events.size()):
		if recorder.events[i]["event"] == event and recorder.events[i]["args"] == args:
			return i
	return -1
