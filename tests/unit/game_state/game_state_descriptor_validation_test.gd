## Story 013, AC-14: an invalid Encounter descriptor (unknown enemy ID) keeps
## the mode in Overworld and logs an error, never reaching the loader. Written
## to the QA Test Cases in
## `production/epics/game-state-scene-flow/story-013-invalid-descriptor-stays-in-overworld.md`
## -- no new cases invented.
extends GdUnitTestSuite


func test_unknown_enemy_rejected_when_flag_on() -> void:
	# Arrange: flag on, catalog knows the faction but not "enemy_ghost".
	var recorder := SequenceRecorder.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder)
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var config: TransitionConfig = env["config"]
	var catalog: StubCatalog = env["catalog"]
	var log_sink: SpyGameStateLog = env["log"]
	config.validate_enemy_ids_against_catalog = true
	catalog.set_known(&"enemy", "enemy_ghost", false)

	var payload := BattleEntryPayload.new()
	var descriptor: EncounterDescriptor = GameStateFixtures.make_encounter_descriptor()
	descriptor.enemy_ids = PackedStringArray(["enemy_ghost"])
	payload.descriptor = descriptor
	payload.party = []

	recorder.clear()
	var probe_before: Dictionary = machine.get_debug_state()
	# begin_swap_count is already 2 at this point (Boot->Title, Title->Overworld
	# in the fixture's own setup) -- the assertion below checks it does not
	# move from here, not that it is zero.
	var begin_swap_before: int = loader.begin_swap_count

	# Act
	var result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, payload)

	# Assert: rejected, error logged against enemy_ids, no signal, no loader
	# call, probe unchanged, mode still OVERWORLD.
	assert_int(result).is_equal(GameStateMachine.RequestResult.REJECTED_INVALID_PAYLOAD)
	assert_int(log_sink.entries.size()).is_equal(1)
	var entry: Dictionary = log_sink.entries[0]
	assert_bool(entry["code"] == &"descriptor_invalid_runtime").override_failure_message(
			"expected code descriptor_invalid_runtime, got %s" % [entry.get("code")]).is_true()
	assert_bool(entry["context"]["field"] == &"enemy_ids").override_failure_message(
			"expected field enemy_ids, got %s" % [entry["context"].get("field")]).is_true()
	assert_bool(recorder.events.is_empty()).override_failure_message(
			"a signal fired for a rejected request").is_true()
	assert_int(loader.begin_swap_count).is_equal(begin_swap_before)
	assert_bool(GameStateProbe.states_equal(probe_before, machine.get_debug_state())) \
			.override_failure_message("debug state changed after a rejected request").is_true()
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.OVERWORLD)
	assert_int(machine.phase).is_equal(GameStateMachine.Phase.IDLE)


func test_other_fields_checked_when_flag_off() -> void:
	# Arrange: flag off for every sub-case below.
	var recorder := SequenceRecorder.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder)
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var config: TransitionConfig = env["config"]
	var catalog: StubCatalog = env["catalog"]
	var log_sink: SpyGameStateLog = env["log"]
	config.validate_enemy_ids_against_catalog = false
	recorder.clear()

	# Sub-case: empty encounter_id -> rejected.
	var empty_encounter: BattleEntryPayload = _valid_payload()
	empty_encounter.descriptor.encounter_id = ""
	_assert_rejected(machine, loader, log_sink, empty_encounter, &"encounter_id")

	# Sub-case: empty enemy_ids -> rejected.
	var empty_enemies: BattleEntryPayload = _valid_payload()
	empty_enemies.descriptor.enemy_ids = PackedStringArray()
	_assert_rejected(machine, loader, log_sink, empty_enemies, &"enemy_ids")

	# Sub-case: unknown faction_id -> rejected.
	catalog.set_known(&"faction", "unknown_faction", false)
	var unknown_faction: BattleEntryPayload = _valid_payload()
	unknown_faction.descriptor.faction_id = "unknown_faction"
	_assert_rejected(machine, loader, log_sink, unknown_faction, &"faction_id")

	# Edge case: null payload -> rejected, no crash.
	_assert_rejected(machine, loader, log_sink, null, &"payload")

	# Edge case: null descriptor -> rejected, no crash.
	var null_descriptor := BattleEntryPayload.new()
	null_descriptor.descriptor = null
	null_descriptor.party = []
	_assert_rejected(machine, loader, log_sink, null_descriptor, &"descriptor")

	# Sub-case: unknown enemy with the flag false -> accepted (documents the
	# interim flag). Run last: unlike the rejections above, this one starts
	# a real transition.
	assert_bool(recorder.events.is_empty()).override_failure_message(
			"a signal fired before the accepted request").is_true()
	var begin_swap_before: int = loader.begin_swap_count
	var unknown_enemy: BattleEntryPayload = _valid_payload()
	unknown_enemy.descriptor.enemy_ids = PackedStringArray(["enemy_ghost"])
	var accepted_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, unknown_enemy)
	assert_int(accepted_result).is_equal(GameStateMachine.RequestResult.OK)
	# OUT has started but SWAP (and so begin_swap()) has not -- that only
	# happens once OUT's duration elapses via tick().
	assert_int(loader.begin_swap_count).is_equal(begin_swap_before)
	assert_int(machine.phase).is_equal(GameStateMachine.Phase.OUT)


## A fresh, fully-valid `BattleEntryPayload` (encounter_id, enemy_ids and
## faction_id all known), for a sub-case to mutate exactly one field.
func _valid_payload() -> BattleEntryPayload:
	var payload := BattleEntryPayload.new()
	payload.descriptor = GameStateFixtures.make_encounter_descriptor()
	payload.party = []
	return payload


## Issues `request_transition(BATTLE, payload)` and asserts it is rejected
## with `REJECTED_INVALID_PAYLOAD`, logs `descriptor_invalid_runtime` naming
## `expected_field`, makes no loader call, and leaves the machine IDLE in
## OVERWORLD.
func _assert_rejected(machine: GameStateMachine, loader: StubSceneLoader,
		log_sink: SpyGameStateLog, payload: RefCounted, expected_field: StringName) -> void:
	var probe_before: Dictionary = machine.get_debug_state()
	var entries_before: int = log_sink.entries.size()
	var begin_swap_before: int = loader.begin_swap_count

	var result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, payload)

	assert_int(result).is_equal(GameStateMachine.RequestResult.REJECTED_INVALID_PAYLOAD)
	assert_int(log_sink.entries.size()).is_equal(entries_before + 1)
	var entry: Dictionary = log_sink.entries[entries_before]
	assert_bool(entry["code"] == &"descriptor_invalid_runtime").override_failure_message(
			"expected code descriptor_invalid_runtime, got %s" % [entry.get("code")]).is_true()
	assert_bool(entry["context"]["field"] == expected_field).override_failure_message(
			"expected field %s, got %s" % [expected_field, entry["context"].get("field")]).is_true()
	assert_int(loader.begin_swap_count).is_equal(begin_swap_before)
	assert_bool(GameStateProbe.states_equal(probe_before, machine.get_debug_state())) \
			.override_failure_message("debug state changed after a rejected request").is_true()
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.OVERWORLD)
	assert_int(machine.phase).is_equal(GameStateMachine.Phase.IDLE)
