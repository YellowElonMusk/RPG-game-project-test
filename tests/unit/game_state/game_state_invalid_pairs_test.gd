## Story 003, AC-4: every from -> to pair not in the transitions table is
## rejected with the exact code, one `invalid_pair` error, an unchanged debug
## state and no signal. Written to the QA Test Cases in
## `production/epics/game-state-scene-flow/story-003-invalid-pairs-rejected.md`.
## The complement is generated from `Mode x Mode - _TRANSITION_TYPES` at test
## time, never hand-listed.
extends GdUnitTestSuite


func test_pair_not_in_table_rejected() -> void:
	var modes: Array = GameStateMachine.Mode.values()
	var table_rows: int = 0
	for from_mode: int in GameStateMachine._TRANSITION_TYPES:
		table_rows += (GameStateMachine._TRANSITION_TYPES[from_mode] as Dictionary).size()
	var cases: Array = []
	for from_mode: int in modes:
		var row: Dictionary = GameStateMachine._TRANSITION_TYPES.get(from_mode, {})
		for to_mode: int in modes:
			if not row.has(to_mode):
				cases.append([from_mode, to_mode])

	# An enum change is noticed: 6 modes -> 36 pairs.
	assert_int(modes.size() * modes.size()).is_equal(36)
	assert_int(cases.size()).is_equal(36 - table_rows)

	for case: Array in cases:
		var from_mode: int = case[0]
		var to_mode: int = case[1]
		var expected: GameStateMachine.RequestResult = (
				GameStateMachine.RequestResult.REJECTED_TERMINAL
				if from_mode == GameStateMachine.Mode.CONTENT_ERROR
				else GameStateMachine.RequestResult.REJECTED_INVALID_PAIR)
		_assert_rejected(from_mode, to_mode, expected)


## Edge cases: the outcome-driven Battle rows are in the table but are not
## requestable through `request_transition()` (draft §2 item 7, accepted).
func test_outcome_driven_rows_rejected_when_requested_directly() -> void:
	for to_mode: int in [GameStateMachine.Mode.OVERWORLD, GameStateMachine.Mode.BATTLE,
			GameStateMachine.Mode.CAMP]:
		_assert_rejected(GameStateMachine.Mode.BATTLE, to_mode,
				GameStateMachine.RequestResult.REJECTED_INVALID_PAIR)


func _assert_rejected(from_mode: int, to_mode: int,
		expected: GameStateMachine.RequestResult) -> void:
	var label: String = "%s -> %s" % [
		GameStateMachine.Mode.keys()[from_mode], GameStateMachine.Mode.keys()[to_mode]]
	var env: Dictionary = _machine_in(from_mode)
	var machine: GameStateMachine = env["machine"]
	var game_log: SpyGameStateLog = env["log"]
	assert_int(machine.current_mode).override_failure_message(label + ": fixture").is_equal(from_mode)
	game_log.entries.clear()
	var recorder := SequenceRecorder.new()
	recorder.attach(machine)
	var probe_before: Dictionary = machine.get_debug_state()

	var result: GameStateMachine.RequestResult = machine.request_transition(
			to_mode, _payload_for(to_mode))

	assert_int(result).override_failure_message(label).is_equal(expected)
	var matching: Array = game_log.entries.filter(
			func(entry: Dictionary) -> bool: return entry["code"] == &"invalid_pair")
	assert_int(matching.size()).override_failure_message(label + ": log count").is_equal(1)
	if matching.size() == 1:
		var entry: Dictionary = matching[0]
		assert_str(String(entry["level"])).is_equal("error")
		assert_int(entry["context"]["from"]).override_failure_message(label).is_equal(from_mode)
		assert_int(entry["context"]["to"]).override_failure_message(label).is_equal(to_mode)
	assert_bool(GameStateProbe.states_equal(probe_before, machine.get_debug_state())
			).override_failure_message(label + ": state changed").is_true()
	assert_array(recorder.events).override_failure_message(label + ": signal fired").is_empty()


## A payload valid for `to_mode` where one exists.
func _payload_for(to_mode: int) -> RefCounted:
	match to_mode:
		GameStateMachine.Mode.BATTLE:
			return GameStateFixtures.valid_battle_entry()
		GameStateMachine.Mode.CAMP:
			var payload := CampEntryPayload.new()
			payload.camp_id = "camp_a"
			return payload
	return null


## Places a machine idle in `mode` through real paths only.
func _machine_in(mode: int) -> Dictionary:
	match mode:
		GameStateMachine.Mode.BOOT:
			return _fresh(ContentCatalogService.State.READY)  # never ticked: still BOOT
		GameStateMachine.Mode.CONTENT_ERROR:
			var env_error: Dictionary = _fresh(ContentCatalogService.State.FAILED)
			(env_error["machine"] as GameStateMachine).tick(0.0)
			_run_to_idle(env_error["machine"])
			return env_error
		GameStateMachine.Mode.TITLE:
			var env_title: Dictionary = _fresh(ContentCatalogService.State.READY)
			(env_title["machine"] as GameStateMachine).tick(0.0)
			_run_to_idle(env_title["machine"])
			return env_title
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	if mode == GameStateMachine.Mode.BATTLE:
		var loader: StubSceneLoader = env["loader"]
		var battle_stub: StubBattleMode = auto_free(StubBattleMode.new())
		battle_stub.snapshot_to_return = GameStateFixtures.make_overworld_snapshot()
		loader.current_mode_node_value = battle_stub
		machine.request_transition(GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
		_run_to_idle(machine)
	elif mode == GameStateMachine.Mode.CAMP:
		machine.request_transition(GameStateMachine.Mode.CAMP, _payload_for(GameStateMachine.Mode.CAMP))
		_run_to_idle(machine)
	return env


func _fresh(catalog_state: ContentCatalogService.State) -> Dictionary:
	var catalog := StubCatalog.new()
	catalog.state = catalog_state
	var game_log := SpyGameStateLog.new()
	var machine := GameStateMachine.new(StubSceneLoader.new(), StubTransitionPresenter.new(),
			GameStateFixtures.make_transition_config(), catalog, QuitSpy.new().as_callable(), game_log)
	return {"machine": machine, "log": game_log}


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()
