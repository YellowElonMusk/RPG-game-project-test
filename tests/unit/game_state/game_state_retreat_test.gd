## Story 021, AC-17: Retreat goes to the last registered camp, else the
## region's default camp, else is not offered (content-bug error). Written to
## the QA Test Cases in
## `production/epics/game-state-scene-flow/story-021-retreat-region-default-and-no-camp.md`.
## The restore itself is Camp's (DEFERRED); here only `full_restore` is pinned.
extends GdUnitTestSuite


func test_registered_camp_wins() -> void:
	var env: Dictionary = _defeated_in_battle("camp_a", "camp_default")
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var free_before: int = loader.free_frozen_overworld_count

	assert_int(machine.choose_retreat()).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)

	var payload: CampEntryPayload = loader.last_begin_swap_args[2]
	assert_str(payload.camp_id).is_equal("camp_a")
	assert_bool(payload.full_restore).is_true()
	assert_int(loader.free_frozen_overworld_count - free_before).is_equal(1)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.CAMP)
	assert_int(machine.get_debug_state()["frozen_overworld_id"]).is_equal(0)


func test_region_default_used() -> void:
	var env: Dictionary = _defeated_in_battle("", "camp_default")
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var prompt_payload: DefeatPromptPayload = loader.last_push_overlay_payload
	assert_bool(prompt_payload.offers_retreat).is_true()

	assert_int(machine.choose_retreat()).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)

	var payload: CampEntryPayload = loader.last_begin_swap_args[2]
	assert_str(payload.camp_id).is_equal("camp_default")
	assert_bool(payload.full_restore).is_true()
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.CAMP)
	assert_int(_count(env["log"], &"no_camp_for_retreat")).is_equal(0)


func test_no_camp_not_offered() -> void:
	var env: Dictionary = _defeated_in_battle("", "")
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var prompt_payload: DefeatPromptPayload = loader.last_push_overlay_payload
	assert_bool(prompt_payload.offers_retreat).is_false()
	assert_int(_count(env["log"], &"no_camp_for_retreat")).is_equal(1)

	var probe_before: Dictionary = machine.get_debug_state()
	assert_int(machine.choose_retreat()).is_not_equal(GameStateMachine.RequestResult.OK)
	assert_bool(GameStateProbe.states_equal(probe_before, machine.get_debug_state())).is_true()


func test_overworld_to_camp_entry_not_full_restore() -> void:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var payload := CampEntryPayload.new()
	payload.camp_id = "camp_a"
	machine.request_transition(GameStateMachine.Mode.CAMP, payload)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.CAMP)
	assert_bool((loader.last_begin_swap_args[2] as CampEntryPayload).full_restore).is_false()


## OVERWORLD (optionally registering `registered`), into BATTLE with
## `retreat_allowed = true`, the stub loader reporting a frozen Overworld whose
## region default is `region_default`, then Defeat.
func _defeated_in_battle(registered: String, region_default: String) -> Dictionary:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	if not registered.is_empty():
		machine.register_camp(registered)
	var frozen: StubOverworldMode = auto_free(StubOverworldMode.new())
	frozen.region_default_camp_id = region_default
	loader.frozen_overworld_node_value = frozen
	var battle_stub: StubBattleMode = auto_free(StubBattleMode.new())
	battle_stub.snapshot_to_return = GameStateFixtures.make_overworld_snapshot()
	loader.current_mode_node_value = battle_stub
	var entry: BattleEntryPayload = GameStateFixtures.valid_battle_entry()
	entry.descriptor.retreat_allowed = true
	machine.request_transition(GameStateMachine.Mode.BATTLE, entry)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)
	assert_int(machine.report_battle_outcome(GameStateMachine.BattleResult.DEFEAT)).is_equal(
			GameStateMachine.RequestResult.OK)
	return env


func _count(game_log: SpyGameStateLog, code: StringName) -> int:
	return game_log.entries.filter(func(entry: Dictionary) -> bool: return entry["code"] == code).size()


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).is_true()
