## Story 016 (GDD sprite-camera-presentation AC-14; ADR-0006 §2, §8): a
## replay never mutates `BattleCore`, and on every released turn and when
## the queue drains the displayed HP, MP, Defend, stun and Viral Stunt equal
## every combatant's live values — including after Family Meal, MegaCorp's
## per-round bill, a Defend wearing off, and a stunned enemy's skipped turn.
## Drives a real, seeded `BattleCore` built through `BattleContentSeam`.
extends GdUnitTestSuite


func _squad_member(block: Dictionary) -> Combatant:
	return Combatant.new(block["name"], block["max_hp"], block["max_mp"],
			block["attack"], block["defense"], block["speed"], false)


func _live_state(battle: BattleCore) -> Array:
	var out: Array = [battle.round_number, battle.state, battle.outcome_log.size()]
	for c: Combatant in battle.squad + battle.enemies:
		out.append([c.hp, c.mp, c.is_defending, c.is_stunned, c.vulnerable_rounds_left])
	return out


func _assert_display_matches_live(controller: BattleReplayController, battle: BattleCore) -> void:
	for c: Combatant in battle.squad + battle.enemies:
		assert_bool(controller.get_display(c).matches(c)).override_failure_message(
				"display of %s differs from live" % c.display_name).is_true()
	assert_int(controller.get_display_round()).is_equal(battle.round_number)


func _choose(battle: BattleCore, actor: Combatant, karen: Combatant, chef: Combatant) -> Array:
	var plan: Array = []
	if actor == karen:
		plan = [BattleContentSeam.move("move_speak_to_the_manager"), battle.get_living_enemies()[0]] \
				if battle.round_number == 2 else [Move.make_defend(), null]
	elif actor == chef and battle.round_number >= 2:
		plan = [BattleContentSeam.move("move_family_meal"), null]
	if plan.is_empty() or not actor.can_afford((plan[0] as Move).mp_cost) \
			or not battle.faction_rule.move_allowed(actor, plan[0]):
		plan = [Move.make_attack(), battle.get_living_enemies()[0]]
	return plan


func test_replay_never_mutates_battlecore_and_display_equals_live_on_every_turn() -> void:
	var karen: Combatant = _squad_member(CharacterizationExpected.SQUAD_KAREN)
	var chef: Combatant = _squad_member(CharacterizationExpected.SQUAD_CHEF)
	var enemies: Array[Combatant] = [BattleContentSeam.enemy("enemy_security_drone")]
	var rng := RandomNumberGenerator.new()
	rng.seed = CharacterizationExpected.SEED_A
	var battle := BattleCore.new([karen, chef], enemies, rng,
			BattleContentSeam.rule("rule_megacorp_billing"))
	var controller := BattleReplayController.new(battle, func(_p: BeatPlan) -> float: return 0.3,
			func(_c: Combatant) -> float: return 0.0, PresentationConfig.new())
	var turn_checks: Array[int] = [0]
	controller.turn_started_after_replay.connect(func(_c: Combatant) -> void:
		turn_checks[0] += 1
		_assert_display_matches_live(controller, battle))
	controller.enqueue_reveal_gate()
	battle.start_battle(false)
	controller.resync()
	controller.open_reveal_gate()
	var guard: int = 0
	while battle.state == BattleCore.State.SQUAD_TURN and guard < 30:
		guard += 1
		var actor: Combatant = battle.get_active_combatant()
		var choice: Array = _choose(battle, actor, karen, chef)
		var target: Combatant = choice[1]
		var hp_before: int = target.hp if target != null else 0
		battle.submit_action(choice[0], target)
		var live: Array = _live_state(battle)
		if target != null and target.hp != hp_before:
			# Mid-replay the HUD still shows the old value.
			assert_int(controller.get_display_hp(target)).is_equal(hp_before)
		var frames: int = 0
		while controller.get_state() != BattleReplayController.State.IDLE and frames < 5000:
			controller.advance(1.0 / 60.0)
			frames += 1
		assert_array(_live_state(battle)).is_equal(live)
		_assert_display_matches_live(controller, battle)
	assert_int(battle.round_number).is_greater_equal(3)
	assert_int(turn_checks[0]).is_greater(3)
