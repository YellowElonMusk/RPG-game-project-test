## Story 014, AC-11: Overworld -> Battle -> Overworld restores every field
## of the Overworld snapshot, for both Victory and Fled. Written to the QA
## Test Cases in
## `production/epics/game-state-scene-flow/story-014-overworld-snapshot-exact-restore.md`
## -- no new cases invented. Uses the real `ModeHostSceneLoader` with a
## plain `Node` `ModeHost`, never `GameRoot` (ADR-0002 §3, §4).
extends GdUnitTestSuite

const _FIXTURES_DIR: String = "res://tests/unit/game_state/fixtures/"


func test_round_trip_restores_snapshot_victory() -> void:
	await _run_round_trip(GameStateMachine.BattleResult.VICTORY, false)


func test_round_trip_restores_snapshot_fled() -> void:
	await _run_round_trip(GameStateMachine.BattleResult.FLED, true)


func _run_round_trip(outcome: GameStateMachine.BattleResult, can_flee: bool) -> void:
	# Arrange: a machine in OVERWORLD, driven through the real Boot -> Title
	# -> Overworld path with the real ModeHostSceneLoader, so
	# stub_overworld_mode.tscn is actually instantiated under ModeHost.
	var recorder := SequenceRecorder.new()
	var mode_host := Node.new()
	add_child(mode_host)
	auto_free(mode_host)

	var cfg: TransitionConfig = GameStateFixtures.make_transition_config()
	cfg.mode_scene_paths = {
		GameStateMachine.Mode.OVERWORLD: _FIXTURES_DIR + "stub_overworld_mode.tscn",
		GameStateMachine.Mode.BATTLE: _FIXTURES_DIR + "stub_battle_mode.tscn",
	}
	var catalog: StubCatalog = GameStateFixtures.make_ready_catalog()
	var quit_spy := QuitSpy.new(recorder)
	var game_log := SpyGameStateLog.new()
	var outcome_box: Array = [-1]
	var loader := ModeHostSceneLoader.new(mode_host, cfg, game_log, Callable(),
			func() -> int: return outcome_box[0])
	var presenter := StubTransitionPresenter.new(recorder)
	var machine := GameStateMachine.new(
			loader, presenter, cfg, catalog, quit_spy.as_callable(), game_log)
	recorder.attach(machine)
	machine.mode_entered.connect(loader.on_mode_entered)

	# Boot -> Title (fade): no scene configured for Title, so the loader
	# no-ops the swap (no node to add/remove).
	machine.tick(0.0)
	machine.tick(cfg.t_out[&"fade"])
	machine.tick(0.0)
	machine.tick(cfg.t_in[&"fade"])

	# Title -> Overworld (fade): the one legal request_transition() pair
	# from Title; instantiates stub_overworld_mode.tscn for real.
	machine.request_transition(GameStateMachine.Mode.OVERWORLD, null)
	machine.tick(cfg.t_out[&"fade"])
	machine.tick(0.0)
	machine.tick(cfg.t_in[&"fade"])

	var original: StubOverworldMode = loader.current_mode_node() as StubOverworldMode
	assert_object(original).is_not_null()
	original.set_recorder(recorder)
	var fixture: Dictionary = original.snapshot_fields()
	var timer_before: float = original.get_timer_time_left()
	var tween_before: float = original.get_tween_elapsed()

	var descriptor: EncounterDescriptor = GameStateFixtures.make_encounter_descriptor()
	descriptor.can_flee = can_flee
	var payload := BattleEntryPayload.new()
	payload.descriptor = descriptor
	payload.party = []

	recorder.clear()

	# Act: Overworld -> Battle.
	var swap_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, payload)
	assert_int(swap_result).is_equal(GameStateMachine.RequestResult.OK)
	machine.tick(cfg.t_out[&"battle_wipe"])
	machine.tick(1.0 / 60.0)
	machine.tick(cfg.t_in[&"battle_wipe"])
	assert_int(machine.phase).is_equal(GameStateMachine.Phase.IDLE)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)

	# The detached instance is never in the tree during Battle.
	assert_bool(original.is_inside_tree()).is_false()

	var battle_node: Node = loader.current_mode_node()
	assert_object(battle_node).is_not_null()

	# 10 frames in Battle: the frozen Overworld's Timer/Tween must not move.
	for i in range(10):
		await get_tree().process_frame
	assert_float(original.get_timer_time_left()).is_equal(timer_before)
	assert_float(original.get_tween_elapsed()).is_equal(tween_before)

	# Act: outcome, then run to IDLE.
	outcome_box[0] = outcome
	if outcome == GameStateMachine.BattleResult.VICTORY:
		var r1: GameStateMachine.RequestResult = machine.report_battle_outcome(
				GameStateMachine.BattleResult.VICTORY)
		assert_int(r1).is_equal(GameStateMachine.RequestResult.OK)
		var r2: GameStateMachine.RequestResult = machine.report_results_done()
		assert_int(r2).is_equal(GameStateMachine.RequestResult.OK)
	else:
		var r1: GameStateMachine.RequestResult = machine.report_battle_outcome(
				GameStateMachine.BattleResult.FLED)
		assert_int(r1).is_equal(GameStateMachine.RequestResult.OK)

	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		await get_tree().process_frame
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()
	await get_tree().process_frame

	# Assert: same instance, every field restored exactly.
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.OVERWORLD)
	var restored: Node = loader.current_mode_node()
	assert_bool(is_same(restored, original)).is_true()
	assert_bool(GameStateProbe.states_equal(fixture, original.thaw_snapshot)).override_failure_message(
			"thaw_snapshot did not match the pre-freeze fixture").is_true()
	assert_bool(GameStateProbe.states_equal(fixture, original.snapshot_fields())).override_failure_message(
			"live fields did not match the pre-freeze fixture").is_true()

	# _ready once in total; _enter_tree/_exit_tree once per move (2/1).
	assert_int(original.ready_count).is_equal(1)
	assert_int(original.enter_tree_count).is_equal(2)
	assert_int(original.exit_tree_count).is_equal(1)

	# on_thawed(id, result) runs after mode_entered(OVERWORLD).
	var mode_entered_overworld_index: int = _index_of_mode_entered(
			recorder, GameStateMachine.Mode.OVERWORLD)
	var on_thawed_index: int = recorder.index_of(&"on_thawed")
	assert_int(mode_entered_overworld_index).is_greater_equal(0)
	assert_int(on_thawed_index).is_greater(mode_entered_overworld_index)
	assert_array(recorder.events[on_thawed_index]["args"]).is_equal(
			[descriptor.encounter_id, outcome])

	# Edge case: the Battle node is freed after return.
	assert_bool(is_instance_valid(battle_node)).is_false()


## Index of the first `mode_entered` event whose argument is `mode`
## (`SequenceRecorder.index_of` only matches by event name).
func _index_of_mode_entered(recorder: SequenceRecorder, mode: GameStateMachine.Mode) -> int:
	for i in range(recorder.events.size()):
		var e: Dictionary = recorder.events[i]
		if e["event"] == &"mode_entered" and e["args"][0] == mode:
			return i
	return -1
