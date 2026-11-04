## Onboarding (systems index #21): the first battle shows "How to fight" and
## the faction's rule card before round 1 (the reveal gate waits behind
## them); a later fight of the same faction shows none; hints switched off in
## Settings show none. Same env as replay_gating_test.gd.
extends GdUnitTestSuite

const _FIXTURES_DIR: String = "res://tests/unit/game_state/fixtures/"
const _BATTLE_MODE_SCENE: String = "res://src/battle/battle_mode.tscn"
const _DT: float = 1.0 / 60.0

var _loaders: Array[ModeHostSceneLoader] = []


func before() -> void:
	BattleContentSeam.ensure_catalog()


func after_test() -> void:
	for loader: ModeHostSceneLoader in _loaders:
		loader.free_frozen_overworld()
	_loaders.clear()
	GameStateFixtures.dispose_tracked()


func test_first_battle_shows_both_cards_before_round_one() -> void:
	var world := WorldState.new()
	var env: Dictionary = _build_env(TutorialHints.new(world))
	var mode: BattleMode = _request_battle(env)
	var menu: BattleCommandMenu = mode.get_node(^"%BattleCommandMenu")
	_run_to_idle(env["machine"])
	var card: TutorialCard = mode.tutorial_card()
	assert_bool(card.visible).is_true()
	assert_str(card.title_text()).is_equal(TutorialHints.FIRST_BATTLE_TITLE)
	assert_bool(menu.visible).override_failure_message("round 1 began behind the card").is_false()
	_ok(card)
	assert_str(card.title_text()).is_equal("Bureaucratia's rule")
	assert_str(card.body_text()).contains("permit")
	assert_bool(menu.visible).is_false()
	_ok(card)
	assert_bool(card.visible).is_false()
	assert_bool(menu.visible).is_true()
	assert_bool(world.has_flag(TutorialHints.PREFIX + TutorialHints.FIRST_BATTLE)).is_true()
	assert_bool(world.has_flag(TutorialHints.PREFIX + TutorialHints.rule_id("faction_bureaucratia"))).is_true()


func test_cards_never_repeat_once_seen() -> void:
	var world := WorldState.new()
	var hints := TutorialHints.new(world)
	hints.mark_seen(TutorialHints.FIRST_BATTLE)
	hints.mark_seen(TutorialHints.rule_id("faction_bureaucratia"))
	var env: Dictionary = _build_env(hints)
	var mode: BattleMode = _request_battle(env)
	_run_to_idle(env["machine"])
	assert_bool(mode.tutorial_card().visible).is_false()
	assert_bool((mode.get_node(^"%BattleCommandMenu") as BattleCommandMenu).visible).is_true()


func test_hints_off_shows_no_card_and_marks_nothing() -> void:
	var world := WorldState.new()
	var env: Dictionary = _build_env(TutorialHints.new(world, func() -> bool: return false))
	var mode: BattleMode = _request_battle(env)
	_run_to_idle(env["machine"])
	assert_bool(mode.tutorial_card().visible).is_false()
	assert_bool((mode.get_node(^"%BattleCommandMenu") as BattleCommandMenu).visible).is_true()
	assert_bool(world.has_flag(TutorialHints.PREFIX + TutorialHints.FIRST_BATTLE)).is_false()


func test_card_swallows_input_while_up() -> void:
	var env: Dictionary = _build_env(TutorialHints.new(WorldState.new()))
	var mode: BattleMode = _request_battle(env)
	_run_to_idle(env["machine"])
	assert_bool(mode.handle_action(InputActions.CANCEL, true)).is_true()
	assert_bool(mode.tutorial_card().visible).is_true()


func _ok(card: TutorialCard) -> void:
	(card.find_children("*", "Button", true, false)[0] as Button).pressed.emit()


func _request_battle(env: Dictionary) -> BattleMode:
	var machine: GameStateMachine = env["machine"]
	var loader: ModeHostSceneLoader = env["loader"]
	var descriptor := EncounterDescriptor.new()
	descriptor.encounter_id = "tutorial_cards_fight"
	descriptor.enemy_ids = PackedStringArray(["enemy_clerk"])
	descriptor.faction_id = "faction_bureaucratia"
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
	mode.set_process(false)
	return mode


func _build_env(hints: TutorialHints) -> Dictionary:
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
		if mode is BattleMode:
			(mode as BattleMode).hints = hints
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
