## Story 029, AC-31: in Battle (including Battle with the Defeat Prompt on
## top) the Menu offers only settings and quit; Overworld and Camp offer the
## full menu. Written to the QA Test Cases in
## `production/epics/game-state-scene-flow/story-029-battle-menu-system-entries.md`
## -- no new cases invented.
extends GdUnitTestSuite

const _BATTLE_ENTRIES: Array[StringName] = [&"settings", &"quit"]
const _FULL_ENTRIES: Array[StringName] = [
	&"pause", &"party", &"codex", &"settings", &"quit"]

const _CASES: Array = [
	["battle", false], ["battle_with_defeat_prompt", true],
	["overworld", false], ["camp", false],
]


func test_menu_entries_per_mode(case_name: String, with_defeat_prompt: bool,
		test_parameters := _CASES) -> void:
	# Arrange: a machine parked in the mode under test, idle, a synthetic
	# action source bound.
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var source := SyntheticActionSource.new()
	machine.bind_action_source(source)
	var expected_entries: Array[StringName] = _FULL_ENTRIES

	if case_name == "battle" or case_name == "battle_with_defeat_prompt":
		var battle_stub: StubBattleMode = auto_free(StubBattleMode.new())
		battle_stub.snapshot_to_return = GameStateFixtures.make_overworld_snapshot()
		loader.current_mode_node_value = battle_stub
		var entry_result: GameStateMachine.RequestResult = machine.request_transition(
				GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
		assert_int(entry_result).is_equal(GameStateMachine.RequestResult.OK)
		_run_to_idle(machine)
		assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)
		if with_defeat_prompt:
			var outcome_result: GameStateMachine.RequestResult = machine.report_battle_outcome(
					GameStateMachine.BattleResult.DEFEAT)
			assert_int(outcome_result).is_equal(GameStateMachine.RequestResult.OK)
		expected_entries = _BATTLE_ENTRIES
	elif case_name == "camp":
		var camp_result: GameStateMachine.RequestResult = machine.request_transition(
				GameStateMachine.Mode.CAMP, null)
		assert_int(camp_result).is_equal(GameStateMachine.RequestResult.OK)
		_run_to_idle(machine)
		assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.CAMP)
	# else "overworld": already idle in OVERWORLD from the fixture.

	# Act: a synthetic menu press.
	source.press(InputActions.MENU)

	# Assert: the payload passed to open_overlay(MENU, ...) carries the
	# expected entries, in order -- no &"party" or &"codex" in a Battle case
	# -- and is plain data (MenuPayload has no Callable field).
	var menu_payload: MenuPayload = loader.last_push_overlay_payload as MenuPayload
	assert_object(menu_payload).override_failure_message(
			case_name + ": no MenuPayload reached the loader").is_not_null()
	assert_array(menu_payload.entries).override_failure_message(
			case_name + ": entries mismatch").is_equal(expected_entries)


## Bounded 1/60s-tick loop until the transition reaches IDLE, as in every
## other test in this suite.
func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()
