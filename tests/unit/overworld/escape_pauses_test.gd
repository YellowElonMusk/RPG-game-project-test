## Esc (`cancel`) has nothing to cancel while exploring, so it opens the
## Menu like the menu key; with the camp prompt open it still answers No.
extends GdUnitTestSuite


func test_cancel_while_exploring_opens_the_menu() -> void:
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode([]))
	mode.grace_active = false
	var machine: GameStateMachine = mode.get("_machine")

	var consumed: bool = mode.handle_action(InputActions.CANCEL, true)

	assert_bool(consumed).is_true()
	assert_array(machine.overlay_stack).contains([GameStateMachine.OverlayKind.MENU])


func test_cancel_on_the_camp_prompt_closes_it_without_a_menu() -> void:
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode([ProbeFixture.camp(
			ProbeFixture.OPEN_SPOT + Vector2(0.0, -1.0))]))
	mode.grace_active = false
	ProbeFixture.stand(mode, ProbeFixture.OPEN_SPOT, Vector2.UP)
	var machine: GameStateMachine = mode.get("_machine")
	mode.handle_action(InputActions.CONFIRM, true)
	mode.handle_action(InputActions.CONFIRM, false)

	mode.handle_action(InputActions.CANCEL, true)

	assert_array(machine.overlay_stack).is_empty()
