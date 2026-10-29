## Story 012, AC-7b (GDD rule 3 "Nothing in reach"): with nothing in reach,
## `confirm` opens nothing (no line, no overlay, no request). Pointer input
## never reaches `handle_action()`: the input system drops it before
## routing (input-system rule 3), so an action that is not `confirm` starts
## nothing here either. No audio system exists yet, so the AC's audio spy
## has no events to count (TODO(audio): assert zero events once the Audio
## Manager exists).
extends GdUnitTestSuite


func test_confirm_with_nothing_in_reach_opens_nothing() -> void:
	var machine: GameStateMachine = ProbeFixture.GameStateFixtures.make_machine_in_overworld()["machine"]
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode([], machine))
	ProbeFixture.stand(mode, ProbeFixture.OPEN_SPOT, Vector2.RIGHT)
	assert_object(mode.probe()).is_null()
	assert_bool(mode.handle_action(InputActions.CONFIRM, true)).is_true()
	assert_array(mode.lines_said).is_empty()
	assert_array(machine.overlay_stack).is_empty()
	assert_int(machine.phase).is_equal(GameStateMachine.Phase.IDLE)
	assert_int(mode.encounter_requests).is_equal(0)


func test_other_actions_start_nothing() -> void:
	var machine: GameStateMachine = ProbeFixture.GameStateFixtures.make_machine_in_overworld()["machine"]
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode(
			[ProbeFixture.npc(ProbeFixture.OPEN_SPOT + Vector2(1.0, 0.0))], machine))
	ProbeFixture.stand(mode, ProbeFixture.OPEN_SPOT, Vector2.RIGHT)
	for action: StringName in [InputActions.CANCEL, InputActions.INSPECT, &"pointer_click"]:
		assert_bool(mode.handle_action(action, true)).is_false()
	assert_array(mode.lines_said).is_empty()
	assert_array(machine.overlay_stack).is_empty()
