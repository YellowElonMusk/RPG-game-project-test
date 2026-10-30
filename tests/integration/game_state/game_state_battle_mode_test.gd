## QA Test Cases 1-4 (game-state-scene-flow story 034): the real
## GameStateMachine + production ModeHostSceneLoader + battle_mode.tscn, so
## the production wiring between Game State and the Battle mode is what is
## under test (same choice as game_state_defeat_prompt_focus_test.gd, story
## 030). Written to the QA Test Cases in
## production/epics/game-state-scene-flow/story-034-battle-mode-wraps-battle-core.md
## -- no new cases invented.
extends GdUnitTestSuite


## The real roster factories read the shipped catalog (content-migration story
## 024), so boot it once for this suite (the machine itself uses a stub).
func before() -> void:
	BattleContentSeam.ensure_catalog()

const _FIXTURES_DIR: String = "res://tests/unit/game_state/fixtures/"
const _BATTLE_MODE_SCENE: String = "res://src/battle/battle_mode.tscn"


func test_entry_builds_and_snapshots() -> void:
	var env: Dictionary = _build_env()
	var machine: GameStateMachine = env["machine"]
	var loader: ModeHostSceneLoader = env["loader"]
	var squad: Array[Combatant] = env["squad"]
	squad[1].is_stunned = true
	squad[1].vulnerable_rounds_left = 2

	_enter_battle(machine, squad, false)

	var battle_mode: BattleMode = loader.current_mode_node() as BattleMode
	assert_object(battle_mode).is_not_null()
	assert_object(battle_mode.battle).override_failure_message(
			"BattleCore was not built via BattleFactory").is_not_null()
	assert_int(battle_mode.battle.enemies.size()).is_equal(1)
	assert_str(battle_mode.battle.enemies[0].display_name).is_equal("Clerk")

	# Party transients cleared before start (ADR-0010 §5 step 2).
	assert_bool(squad[1].is_stunned).override_failure_message(
			"is_stunned was not cleared before start").is_false()
	assert_int(squad[1].vulnerable_rounds_left).override_failure_message(
			"vulnerable_rounds_left was not cleared before start").is_equal(0)

	var snapshot: RefCounted = battle_mode.capture_start_snapshot()
	assert_object(snapshot).override_failure_message(
			"capture_start_snapshot() returned null after a valid entry").is_not_null()

	# This test never leaves BATTLE, so the frozen Overworld instance
	# (detached, not destroyed, on Overworld -> Battle -- ADR-0002 §4) is
	# never reattached by a round trip. Free it explicitly, as Retreat/Quit
	# to Title do in production, so it is not an orphan at teardown.
	loader.free_frozen_overworld()


func test_retry_restores() -> void:
	var env: Dictionary = _build_env()
	var machine: GameStateMachine = env["machine"]
	var loader: ModeHostSceneLoader = env["loader"]
	var squad: Array[Combatant] = env["squad"]

	_enter_battle(machine, squad, false)
	var battle_mode: BattleMode = loader.current_mode_node() as BattleMode
	var battle_before: BattleCore = battle_mode.battle
	var hp_before: int = squad[0].hp
	var mp_before: int = squad[0].mp

	# Damage the party and kill one enemy mid-fight.
	squad[0].hp -= 10
	squad[0].mp -= 2
	battle_mode.battle.enemies[0].hp = 0

	var outcome_result: GameStateMachine.RequestResult = machine.report_battle_outcome(
			GameStateMachine.BattleResult.DEFEAT)
	assert_int(outcome_result).is_equal(GameStateMachine.RequestResult.OK)

	var retry_result: GameStateMachine.RequestResult = machine.choose_retry()
	assert_int(retry_result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)

	assert_int(squad[0].hp).is_equal(hp_before)
	assert_int(squad[0].mp).is_equal(mp_before)
	for enemy: Combatant in battle_mode.battle.enemies:
		assert_int(enemy.hp).override_failure_message(
				"%s was not reset to full hp on retry" % enemy.display_name).is_equal(enemy.max_hp)
	assert_bool(is_same(battle_mode.battle, battle_before)).override_failure_message(
			"BattleCore was rebuilt instead of reused on Retry").is_true()
	assert_object(loader.current_mode_node()).is_same(battle_mode)

	# This test never leaves BATTLE either (see test_entry_builds_and_snapshots).
	loader.free_frozen_overworld()


func test_victory_carryover_and_report_order() -> void:
	var env: Dictionary = _build_env()
	var machine: GameStateMachine = env["machine"]
	var loader: ModeHostSceneLoader = env["loader"]
	var source: SyntheticActionSource = env["source"]
	var squad: Array[Combatant] = env["squad"]

	_enter_battle(machine, squad, false)
	var battle_mode: BattleMode = loader.current_mode_node() as BattleMode
	var battle: BattleCore = battle_mode.battle
	var hp_total_before: int = squad[0].hp + squad[1].hp

	# Deterministic win: attack the lone Clerk until it is knocked out.
	var rounds: int = 0
	while battle.state == BattleCore.State.SQUAD_TURN and rounds < 100:
		var target: Combatant = battle.get_living_enemies()[0]
		battle.submit_action(Move.make_attack(), target)
		rounds += 1
	assert_int(battle.state).is_equal(BattleCore.State.WON)
	battle_mode.settle_replay()

	# report_battle_outcome(VICTORY) is recorded as soon as the fight ends --
	# battle_mode connects its own battle_ended handler before calling
	# hud.setup() in setup(), so this always runs, and therefore reports,
	# before the HUD's own battle_ended handler repaints the end banner.
	assert_int(machine.get_debug_state()["pending_outcome"]).is_equal(
			GameStateMachine.BattleResult.VICTORY)
	assert_int(machine.current_mode).override_failure_message(
			"left BATTLE before the end banner was confirmed").is_equal(
			GameStateMachine.Mode.BATTLE)

	# report_results_done() only fires once the player confirms the banner.
	source.press(InputActions.CONFIRM)
	_run_to_idle(machine)

	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.OVERWORLD)
	var hp_total_after: int = squad[0].hp + squad[1].hp
	assert_int(hp_total_after).override_failure_message(
			"damage taken during the fight did not persist on the requester's own Combatants") \
			.is_less(hp_total_before)


func test_boss_count_failure_rolls_back() -> void:
	var env: Dictionary = _build_env()
	var machine: GameStateMachine = env["machine"]
	var loader: ModeHostSceneLoader = env["loader"]
	var squad: Array[Combatant] = env["squad"]
	var original: Node = loader.current_mode_node()

	# A boss fight whose single enemy is not a boss: 0 boss enemies.
	_enter_battle(machine, squad, true)

	assert_int(machine.current_mode).override_failure_message(
			"a bad boss count did not roll back to OVERWORLD").is_equal(
			GameStateMachine.Mode.OVERWORLD)
	assert_bool(is_same(loader.current_mode_node(), original)).override_failure_message(
			"rollback did not reattach the original Overworld instance").is_true()


## Builds a machine with the real `ModeHostSceneLoader` (OVERWORLD mapped to
## the plain stub, BATTLE mapped to the real `battle_mode.tscn` -- same split
## as `game_state_overworld_freeze_test.gd`'s round trip), drives it from
## `BOOT` to an idle `OVERWORLD`, and binds a synthetic action source.
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
	var presenter := StubTransitionPresenter.new(recorder)
	var machine := GameStateMachine.new(
			loader, presenter, cfg, catalog, quit_spy.as_callable(), game_log)
	machine_box[0] = machine
	loader.set_machine(machine)
	machine.mode_entered.connect(loader.on_mode_entered)

	var source := SyntheticActionSource.new()
	machine.bind_action_source(source)

	machine.tick(0.0)
	_run_to_idle(machine)
	machine.request_transition(GameStateMachine.Mode.OVERWORLD, null)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.OVERWORLD)

	var squad: Array[Combatant] = [
		Combatant.new("Hero A", 30, 10, 12, 8, 10, false),
		Combatant.new("Hero B", 30, 10, 12, 8, 10, false),
	]
	return {"machine": machine, "loader": loader, "source": source, "squad": squad}


## Requests Battle with a fixture descriptor (the interim `enemy_clerk` id,
## Bureaucratia) and runs to idle. `is_boss` with a non-boss enemy roster
## exercises Check 4's bad boss count (0 boss enemies).
func _enter_battle(machine: GameStateMachine, squad: Array[Combatant], is_boss: bool) -> void:
	var descriptor := EncounterDescriptor.new()
	descriptor.encounter_id = "bureaucratia_fight_0"
	descriptor.enemy_ids = PackedStringArray(["enemy_clerk"])
	descriptor.faction_id = "faction_bureaucratia"
	descriptor.is_boss = is_boss
	descriptor.can_flee = true
	var payload := BattleEntryPayload.new()
	payload.descriptor = descriptor
	payload.party = squad
	var result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, payload)
	assert_int(result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()
