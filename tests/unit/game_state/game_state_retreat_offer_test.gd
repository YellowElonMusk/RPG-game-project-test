## Story 018, AC-16: the Defeat Prompt offers Retreat only when the stored
## `EncounterDescriptor.retreat_allowed` is true, computed fresh on every
## Defeat -- never cached across a Retry. Written to the QA Test Cases in
## `production/epics/game-state-scene-flow/story-018-retreat-offer-no-stale-flag.md`
## -- no new cases invented.
extends GdUnitTestSuite

## register_camp("camp_a") is called in Arrange below even though this
## story's offer computation does not consult it yet -- story 020/021 add
## camp-availability and the region-default fallback on top of
## `retreat_allowed`, and registering a camp here keeps this fixture valid
## once those stories land (QA RC-2, qa-lead GAPS fix).
const _RETREAT_CASES: Array = [[false, false], [true, true]]


func test_offer_follows_descriptor(retreat_allowed: bool, expect_offer: bool,
		test_parameters := _RETREAT_CASES) -> void:
	# Arrange: BATTLE entered with a descriptor whose retreat_allowed is the
	# case under test; a camp is registered first (QA RC-2, see note above).
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]

	machine.register_camp("camp_a")

	var battle_stub: StubBattleMode = auto_free(StubBattleMode.new())
	battle_stub.snapshot_to_return = GameStateFixtures.make_overworld_snapshot()
	loader.current_mode_node_value = battle_stub

	var payload := BattleEntryPayload.new()
	var descriptor: EncounterDescriptor = GameStateFixtures.make_encounter_descriptor()
	descriptor.retreat_allowed = retreat_allowed
	payload.descriptor = descriptor
	payload.party = []

	var entry_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, payload)
	assert_int(entry_result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)

	# Act: report_battle_outcome(DEFEAT).
	var outcome_result: GameStateMachine.RequestResult = machine.report_battle_outcome(
			GameStateMachine.BattleResult.DEFEAT)

	# Assert: the DefeatPromptPayload passed to the loader carries the
	# expected offers_retreat.
	assert_int(outcome_result).is_equal(GameStateMachine.RequestResult.OK)
	var prompt_payload: DefeatPromptPayload = (
			loader.last_push_overlay_payload as DefeatPromptPayload)
	assert_object(prompt_payload).is_not_null()
	assert_bool(prompt_payload.offers_retreat).is_equal(expect_offer)

	# Assert (case a only): choose_retreat() is rejected, debug state unchanged.
	if not expect_offer:
		var probe_before: Dictionary = machine.get_debug_state()
		var retreat_result: GameStateMachine.RequestResult = machine.choose_retreat()
		assert_int(retreat_result).is_equal(GameStateMachine.RequestResult.REJECTED_INVALID_PAYLOAD)
		assert_bool(GameStateProbe.states_equal(probe_before, machine.get_debug_state())) \
				.override_failure_message("debug state changed after a rejected Retreat").is_true()


func test_no_stale_flag_after_retry() -> void:
	# Arrange: case (b) -- BATTLE entered with retreat_allowed = true, camp
	# registered first (QA RC-2, see note above).
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]

	machine.register_camp("camp_a")

	var battle_stub: StubBattleMode = auto_free(StubBattleMode.new())
	battle_stub.snapshot_to_return = GameStateFixtures.make_overworld_snapshot()
	loader.current_mode_node_value = battle_stub

	var payload := BattleEntryPayload.new()
	var descriptor: EncounterDescriptor = GameStateFixtures.make_encounter_descriptor()
	descriptor.retreat_allowed = true
	payload.descriptor = descriptor
	payload.party = []

	var entry_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, payload)
	assert_int(entry_result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)

	# Act: Defeat -> choose_retry() -> run to IDLE -> Defeat again.
	var first_outcome: GameStateMachine.RequestResult = machine.report_battle_outcome(
			GameStateMachine.BattleResult.DEFEAT)
	assert_int(first_outcome).is_equal(GameStateMachine.RequestResult.OK)
	var first_payload: DefeatPromptPayload = (
			loader.last_push_overlay_payload as DefeatPromptPayload)
	assert_object(first_payload).is_not_null()
	assert_bool(first_payload.offers_retreat).is_true()

	var retry_result: GameStateMachine.RequestResult = machine.choose_retry()
	assert_int(retry_result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)

	var second_outcome: GameStateMachine.RequestResult = machine.report_battle_outcome(
			GameStateMachine.BattleResult.DEFEAT)
	assert_int(second_outcome).is_equal(GameStateMachine.RequestResult.OK)
	var second_payload: DefeatPromptPayload = (
			loader.last_push_overlay_payload as DefeatPromptPayload)

	# Assert: offers_retreat true both times, and the payload is a new
	# object on each Defeat (not the same instance).
	assert_object(second_payload).is_not_null()
	assert_bool(second_payload.offers_retreat).is_true()
	assert_bool(is_same(second_payload, first_payload)) \
			.override_failure_message("DefeatPromptPayload was reused across Defeats, not rebuilt") \
			.is_false()


## Bounded 1/60s-tick loop until the transition reaches IDLE.
func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()
