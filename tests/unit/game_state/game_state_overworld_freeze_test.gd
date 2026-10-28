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
	# Story 012: the Battle mode must return a non-null capture_start_snapshot()
	# or the swap rolls back, so this round trip's pre_setup gives the real
	# StubBattleMode instance a fixture snapshot to return.
	var pre_setup := func(mode: GameMode, _payload: RefCounted) -> void:
		if mode is StubBattleMode:
			(mode as StubBattleMode).snapshot_to_return = GameStateFixtures.make_overworld_snapshot()
	var loader := ModeHostSceneLoader.new(mode_host, cfg, game_log, pre_setup,
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


## Story 012, AC-10 (loader level): a swap failure after detach re-attaches
## the same frozen instance. No `pre_setup` is given, so the real
## `stub_battle_mode.tscn` instance's `capture_start_snapshot()` stays null
## (its default) -- the machine's own post-swap check (ADR-0002 §7) fails it,
## which exercises `ModeHostSceneLoader.rollback_swap()` after a real
## `on_freezing()` + `remove_child()`.
func test_failure_after_detach_reattaches_same_instance() -> void:
	# Arrange: a machine in OVERWORLD with the real ModeHostSceneLoader.
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
	var loader := ModeHostSceneLoader.new(mode_host, cfg, game_log)
	var presenter := StubTransitionPresenter.new(recorder)
	var machine := GameStateMachine.new(
			loader, presenter, cfg, catalog, quit_spy.as_callable(), game_log)
	recorder.attach(machine)
	machine.mode_entered.connect(loader.on_mode_entered)

	# Boot -> Title -> Overworld, as in the round trip above.
	machine.tick(0.0)
	machine.tick(cfg.t_out[&"fade"])
	machine.tick(0.0)
	machine.tick(cfg.t_in[&"fade"])
	machine.request_transition(GameStateMachine.Mode.OVERWORLD, null)
	machine.tick(cfg.t_out[&"fade"])
	machine.tick(0.0)
	machine.tick(cfg.t_in[&"fade"])

	var original: StubOverworldMode = loader.current_mode_node() as StubOverworldMode
	assert_object(original).is_not_null()
	var fixture: Dictionary = original.snapshot_fields()

	var descriptor: EncounterDescriptor = GameStateFixtures.make_encounter_descriptor()
	var payload := BattleEntryPayload.new()
	payload.descriptor = descriptor
	payload.party = []

	# Act: Overworld -> Battle. The loader detaches the Overworld, loads and
	# adds the Battle scene (poll_swap DONE on first poll), and the machine's
	# capture check then fails it and rolls back -- all inside this one tick.
	var swap_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, payload)
	assert_int(swap_result).is_equal(GameStateMachine.RequestResult.OK)
	machine.tick(cfg.t_out[&"battle_wipe"])   # ends OUT -> SWAP
	machine.tick(1.0 / 60.0)                   # SWAP: loader DONE, capture null -> rollback

	# Assert: the same instance is back, re-attached, before IN even starts.
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.OVERWORLD)
	var reattached: Node = loader.current_mode_node()
	assert_bool(is_same(reattached, original)).is_true()
	assert_bool(original.is_inside_tree()).is_true()
	assert_bool(GameStateProbe.states_equal(fixture, original.snapshot_fields())).override_failure_message(
			"snapshot fields changed across the failed swap").is_true()

	var error_entry: Dictionary = game_log.entries[game_log.entries.size() - 1]
	assert_bool(error_entry["code"] == &"swap_failed").is_true()
	assert_bool(error_entry["context"]["cause"] == &"capture_snapshot_null").is_true()

	# Drain IN to IDLE; no orphan nodes left behind (gdUnit4 exit 101).
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.OVERWORLD)
	assert_int(mode_host.get_child_count()).is_equal(1)
