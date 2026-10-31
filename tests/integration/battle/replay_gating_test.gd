## Sprite-camera story 033 (GDD sprite-camera-presentation AC-29; ADR-0006
## §3-§5): with a real, seeded `BattleCore` built by the real Battle mode,
## the real GameStateMachine and production ModeHostSceneLoader (stub
## catalog/presenter, as in game_state_battle_mode_test.gd), the command menu,
## the outcome report and the Defeat Prompt open only after the replay.
extends GdUnitTestSuite

const _FIXTURES_DIR: String = "res://tests/unit/game_state/fixtures/"
const _BATTLE_MODE_SCENE: String = "res://src/battle/battle_mode.tscn"
const _DT: float = 1.0 / 60.0
## `pending_outcome` when nothing has been reported (GameStateMachine's sentinel).
const _NO_OUTCOME: int = -1

## Loaders built this test. The Overworld frozen on Overworld -> Battle is
## detached, not destroyed (ADR-0002 §4), so teardown frees it the way Quit
## to Title does in production; otherwise it is an orphan.
var _loaders: Array[ModeHostSceneLoader] = []


func before() -> void:
	BattleContentSeam.ensure_catalog()


func after_test() -> void:
	for loader: ModeHostSceneLoader in _loaders:
		loader.free_frozen_overworld()
	_loaders.clear()
	GameStateFixtures.dispose_tracked()


func test_first_entry_menu_opens_only_after_reveal() -> void:
	var env: Dictionary = _build_env()
	var machine: GameStateMachine = env["machine"]
	var mode: BattleMode = _request_battle(machine, env, false)
	var menu: BattleCommandMenu = mode.get_node(^"%BattleCommandMenu")
	assert_bool(menu.visible).override_failure_message("menu open before the reveal").is_false()
	assert_int(mode.replay.get_state()).is_equal(BattleReplayController.State.GATED)
	_run_to_idle(machine)  # transition_finished(BATTLE) opens the reveal gate
	assert_bool(menu.visible).is_true()


func test_boss_entry_menu_waits_behind_takeover() -> void:
	var env: Dictionary = _build_env()
	var machine: GameStateMachine = env["machine"]
	var mode: BattleMode = _request_battle(machine, env, true)
	var menu: BattleCommandMenu = mode.get_node(^"%BattleCommandMenu")
	_run_to_idle(machine)
	var cfg: PresentationConfig = mode.presentation_config
	var takeover: float = cfg.blend_boss + cfg.boss_hold
	var dt: float = cfg.follow_camera_dt_max
	var played: float = 0.0
	while played + dt < takeover - dt:
		mode.step_replay(dt)
		played += dt
		assert_bool(menu.visible).override_failure_message(
				"menu open %.2fs into a %.2fs takeover" % [played, takeover]).is_false()
	mode.settle_replay()
	assert_bool(menu.visible).is_true()


func test_non_ending_command_reopens_menu_only_on_next_turn() -> void:
	var env: Dictionary = _build_env()
	var machine: GameStateMachine = env["machine"]
	var mode: BattleMode = _request_battle(machine, env, false)
	_run_to_idle(machine)
	var menu: BattleCommandMenu = mode.get_node(^"%BattleCommandMenu")
	var opened: Array = [0]
	mode.replay.turn_started_after_replay.connect(func(_c: Combatant) -> void: opened[0] += 1)
	menu._submit(Move.make_defend(), null)
	assert_int(mode.battle.state).is_equal(BattleCore.State.SQUAD_TURN)
	assert_bool(menu.visible).override_failure_message("menu open during the replay").is_false()
	assert_bool(mode.is_presenting()).is_true()
	mode.settle_replay()
	assert_int(opened[0]).is_equal(1)
	assert_bool(menu.visible).is_true()


func test_winning_command_reports_after_last_beat_and_hold() -> void:
	var env: Dictionary = _build_env()
	var machine: GameStateMachine = env["machine"]
	var mode: BattleMode = _request_battle(machine, env, false)
	_run_to_idle(machine)
	var released: Array = [false]
	mode.replay.battle_ended_after_replay.connect(func(_w: bool) -> void: released[0] = true)
	var battle: BattleCore = mode.battle
	for enemy: Combatant in battle.enemies:
		enemy.hp = 1
	battle.submit_action(Move.make_attack(), battle.get_living_enemies()[0])
	assert_int(battle.state).is_equal(BattleCore.State.WON)
	assert_int(_pending(machine)).override_failure_message("reported before the replay").is_equal(
			_NO_OUTCOME)
	var dt: float = mode.presentation_config.follow_camera_dt_max
	var guard: int = 0
	while not released[0] and guard < 1000:
		mode.step_replay(dt)
		guard += 1
	assert_bool(released[0]).is_true()
	assert_int(_pending(machine)).override_failure_message("reported before the end hold").is_equal(
			_NO_OUTCOME)
	mode.step_replay(mode.presentation_config.victory_hold)
	assert_int(_pending(machine)).is_equal(GameStateMachine.BattleResult.VICTORY)


func test_losing_command_opens_defeat_prompt_after_hold() -> void:
	var env: Dictionary = _build_env()
	var machine: GameStateMachine = env["machine"]
	var mode: BattleMode = _request_battle(machine, env, false)
	_run_to_idle(machine)
	var prompts: Array = [0]
	machine.overlay_opened.connect(func(kind: GameStateMachine.OverlayKind) -> void:
		if kind == GameStateMachine.OverlayKind.DEFEAT_PROMPT:
			prompts[0] += 1)
	DebugLaunchArgs.force_outcome(mode.battle, DebugLaunchArgs.DEFEAT)
	assert_int(mode.battle.state).is_equal(BattleCore.State.LOST)
	_tick_machine(machine, 3)
	assert_int(prompts[0]).override_failure_message("Defeat Prompt before the replay").is_equal(0)
	assert_int(_pending(machine)).is_equal(_NO_OUTCOME)
	mode.settle_replay()
	_run_to_idle(machine)
	assert_int(prompts[0]).is_equal(1)


func test_hud_and_menu_have_no_battle_core_turn_round_end_connections() -> void:
	var env: Dictionary = _build_env()
	var machine: GameStateMachine = env["machine"]
	var mode: BattleMode = _request_battle(machine, env, false)
	_run_to_idle(machine)
	var hud: Node = mode.get_node(^"%BattleHud")
	var menu: Node = mode.get_node(^"%BattleCommandMenu")
	var core: BattleCore = mode.battle
	for sig: Signal in [core.turn_started, core.round_advanced, core.battle_ended, core.action_resolved]:
		for conn: Dictionary in sig.get_connections():
			var target: Object = (conn["callable"] as Callable).get_object()
			assert_bool(target == hud or target == menu or target == mode).override_failure_message(
					"%s is connected to BattleCore.%s" % [target, sig.get_name()]).is_false()


# --- helpers -----------------------------------------------------------------

func _pending(machine: GameStateMachine) -> int:
	return int(machine.get_debug_state()["pending_outcome"])


func _tick_machine(machine: GameStateMachine, ticks: int) -> void:
	for i: int in ticks:
		machine.tick(_DT)


## Requests Battle and ticks only until the Battle mode exists (the swap's IN
## half, and therefore `transition_finished`, has not necessarily run yet).
func _request_battle(machine: GameStateMachine, env: Dictionary, is_boss: bool) -> BattleMode:
	var loader: ModeHostSceneLoader = env["loader"]
	var descriptor := EncounterDescriptor.new()
	descriptor.encounter_id = "replay_gating_fight"
	descriptor.enemy_ids = PackedStringArray(["enemy_supervisor", "enemy_clerk"]) if is_boss \
			else PackedStringArray(["enemy_clerk"])
	descriptor.faction_id = "faction_bureaucratia"
	descriptor.is_boss = is_boss
	descriptor.can_flee = true
	var payload := BattleEntryPayload.new()
	payload.descriptor = descriptor
	payload.party = env["squad"]
	assert_int(machine.request_transition(GameStateMachine.Mode.BATTLE, payload)).is_equal(
			GameStateMachine.RequestResult.OK)
	var ticks: int = 0
	while not (loader.current_mode_node() is BattleMode) and ticks < 600:
		machine.tick(_DT)
		ticks += 1
	var mode: BattleMode = loader.current_mode_node() as BattleMode
	assert_object(mode).is_not_null()
	mode.set_process(false)  # the test drives the replay clock itself
	return mode


func _build_env() -> Dictionary:
	var mode_host := Node.new()
	add_child(mode_host)
	auto_free(mode_host)
	var cfg: TransitionConfig = GameStateFixtures.make_transition_config()
	cfg.mode_scene_paths = {
		GameStateMachine.Mode.OVERWORLD: _FIXTURES_DIR + "stub_overworld_mode.tscn",
		GameStateMachine.Mode.BATTLE: _BATTLE_MODE_SCENE,
	}
	var catalog: StubCatalog = GameStateFixtures.make_ready_catalog()
	var recorder := SequenceRecorder.new()
	var quit_spy := QuitSpy.new(recorder)
	var game_log := SpyGameStateLog.new()
	var machine_box: Array = [null]
	var pre_setup := func(mode: GameMode, payload: RefCounted) -> void:
		mode.setup(machine_box[0], payload)
	var loader := ModeHostSceneLoader.new(mode_host, cfg, game_log, pre_setup)
	_loaders.append(loader)
	var presenter := StubTransitionPresenter.new(recorder)
	var machine := GameStateMachine.new(
			loader, presenter, cfg, catalog, quit_spy.as_callable(), game_log)
	machine_box[0] = machine
	loader.set_machine(machine)
	GameStateFixtures.track(machine)
	machine.mode_entered.connect(loader.on_mode_entered)
	machine.bind_action_source(SyntheticActionSource.new())
	machine.tick(0.0)
	_run_to_idle(machine)
	machine.request_transition(GameStateMachine.Mode.OVERWORLD, null)
	_run_to_idle(machine)
	var squad: Array[Combatant] = [
		Combatant.new("Hero A", 30, 10, 12, 8, 10, false),
		Combatant.new("Hero B", 30, 10, 12, 8, 10, false),
	]
	return {"machine": machine, "loader": loader, "squad": squad}


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(_DT)
		ticks += 1
	assert_bool(ticks < 600).is_true()
