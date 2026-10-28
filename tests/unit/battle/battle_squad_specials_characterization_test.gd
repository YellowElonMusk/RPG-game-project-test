## Story 002 (ADR-0001 Migration Step 0; ADR-0007 Migration Step 0; ADR-0010
## §7): pins the five squad specials' Move fields and effects against today's
## `SquadSpecials` (src/battle/squad/specials.gd), observed only through
## `BattleCore` (ADR-0007 deletes the heal helpers) and the seam from story
## 001. Damaged/knocked-out states are arranged only through
## `BattleContentSeam.arrange_vitals` — never a direct `hp` write. Pinned
## numbers (heal amounts, damage, `rng.state`) are literal copies read once
## from today's code, never a reference to a `SquadSpecials` or
## `DamageCalculator` const (both are deleted or changed by ADR-0007).
extends GdUnitTestSuite

## Per-special pinned numbers not already in `CharacterizationExpected.SPECIALS`
## (which holds only Move fields). Local to this test file, the same pattern
## story 001's test used for `_ENEMY_DISPLAY_NAMES`/`_MOVE_DISPLAY_NAMES`.
const _FAMILY_MEAL_HP_DELTA: int = 9
const _FAMILY_MEAL_M1_HP: int = 16
const _FAMILY_MEAL_M2_HP: int = 30
const _APPETIZER_HEAL: int = 12
const _VIRAL_BOOSTED_ATTACK_DAMAGE: int = 9
## The two `rng.state` pins depend on Godot's RandomNumberGenerator (PCG32);
## an engine upgrade that changes it means re-pinning them, not a regression.
const _VIRAL_BOOSTED_ATTACK_RNG_STATE: int = -6618438155849649559
## Home Run damage against each of `CharacterizationExpected.ENEMY_IDS`, in
## that same order (Clerk, Supervisor, Security Drone, Middle Manager, CEO).
const _HOME_RUN_DAMAGE: Array[int] = [20, 16, 17, 21, 15]
const _HOME_RUN_RNG_STATE: int = 9033400586920292166


## Builds a squad member from one of `CharacterizationExpected`'s `SQUAD_*`
## blocks.
func _squad_member(block: Dictionary) -> Combatant:
	return Combatant.new(block["name"], block["max_hp"], block["max_mp"],
			block["attack"], block["defense"], block["speed"], false)


## Every battle gets a seeded RNG, including those that draw nothing today,
## so extending a test can't make it silently non-deterministic.
func _seeded_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = CharacterizationExpected.SEED_A
	return rng


# --- Test: Move fields ---

func test_move_fields_equal_the_pin_for_every_special() -> void:
	for id: String in CharacterizationExpected.SPECIALS:
		var pin: Dictionary = CharacterizationExpected.SPECIALS[id]
		var built_move: Move = BattleContentSeam.move(id)
		assert_str(built_move.display_name).override_failure_message(id).is_equal(pin["display_name"])
		assert_int(built_move.category).override_failure_message(id).is_equal(pin["category"])
		assert_int(built_move.mp_cost).override_failure_message(id).is_equal(pin["mp_cost"])
		assert_int(built_move.power).override_failure_message(id).is_equal(pin["power"])
		assert_int(built_move.target_type).override_failure_message(id).is_equal(pin["target_type"])
		assert_int(built_move.special_effect).override_failure_message(id).is_equal(pin["special_effect"])
		assert_int(built_move.effect_rounds).override_failure_message(id).is_equal(pin["effect_rounds"])


## Edge case: Home Run's name is "Home Run" (not "Baguette Home Run" — the
## prototype's name; today's factory renamed it, and that is what is pinned).
func test_home_run_display_name_is_home_run() -> void:
	assert_str(BattleContentSeam.move("move_home_run").display_name).is_equal("Home Run")


# --- Test: stun (Karen's Speak to the Manager) ---

func test_speak_to_the_manager_stuns_a_clerk_and_skips_its_next_turn() -> void:
	var karen: Combatant = _squad_member(CharacterizationExpected.SQUAD_KAREN)
	var second: Combatant = Combatant.new("Second", 30, 10, 12, 8, 10, false)
	var clerk: Combatant = BattleContentSeam.enemy("enemy_clerk")
	var battle := BattleCore.new([karen, second], [clerk],
			_seeded_rng(), BattleContentSeam.scripted_rule([]))
	battle.start_battle()

	var outcome: BattleOutcome = battle.submit_action(BattleContentSeam.move("move_speak_to_the_manager"), clerk)

	assert_int(outcome.mp_delta).is_equal(-4)
	assert_bool(clerk.is_stunned).is_true()

	# Second's turn completes the round; the Clerk's own turn is skipped and
	# logs no outcome for it (the stunned flag is also cleared there).
	battle.submit_action(Move.make_defend())
	for logged: BattleOutcome in battle.outcome_log:
		assert_object(logged.actor).override_failure_message(
				"outcome_log: %s" % [battle.outcome_log]).is_not_same(clerk)
	assert_bool(clerk.is_stunned).is_false()


## Edge case: the Supervisor (Bureaucratia's boss) is immune, after the
## permit gate (round 4) under the real rule. MP is still spent.
func test_speak_to_the_manager_has_no_effect_on_the_supervisor() -> void:
	var karen: Combatant = _squad_member(CharacterizationExpected.SQUAD_KAREN)
	var supervisor: Combatant = BattleContentSeam.enemy("enemy_supervisor")
	var rng := RandomNumberGenerator.new()
	rng.seed = CharacterizationExpected.SEED_A
	var battle := BattleCore.new([karen], [supervisor], rng, BureaucratiaRule.new())
	battle.start_battle()

	# Rounds 1-3: specials are banned under the real rule, so Karen Defends to
	# reach round 4, where the permit gate opens.
	for _i: int in 3:
		battle.submit_action(Move.make_defend())
	assert_int(battle.round_number).override_failure_message("did not reach round 4").is_equal(4)

	var outcome: BattleOutcome = battle.submit_action(BattleContentSeam.move("move_speak_to_the_manager"), supervisor)

	assert_int(outcome.mp_delta).is_equal(-4)
	assert_bool(supervisor.is_stunned).is_false()


## Edge case: the CEO (MegaCorp's boss) is immune too, from round 1 (MegaCorp
## bans nothing). Karen's MP is >= 4 going in (fresh fixture MP is 12).
func test_speak_to_the_manager_has_no_effect_on_the_ceo() -> void:
	var karen: Combatant = _squad_member(CharacterizationExpected.SQUAD_KAREN)
	var ceo: Combatant = BattleContentSeam.enemy("enemy_ceo")
	var rng := RandomNumberGenerator.new()
	rng.seed = CharacterizationExpected.SEED_A
	var battle := BattleCore.new([karen], [ceo], rng, MegaCorpRule.new())
	battle.start_battle()

	var outcome: BattleOutcome = battle.submit_action(BattleContentSeam.move("move_speak_to_the_manager"), ceo)

	assert_int(outcome.mp_delta).is_equal(-4)
	assert_bool(ceo.is_stunned).is_false()


# --- Test: Family Meal (the Michelin Chef) ---

## GIVEN the Chef plus 3 members arranged to the fixture HPs (one at 0, one
## at full — the clamp edge case), WHEN Family Meal is submitted, THEN
## hp_delta is the pinned total, each living member's hp is its pin, and the
## knocked-out member stays 0.
func test_family_meal_heals_living_members_and_skips_the_knocked_out_one() -> void:
	var chef: Combatant = _squad_member(CharacterizationExpected.SQUAD_CHEF)
	var m1 := Combatant.new("Member 1", 30, 10, 12, 8, 10, false)
	var m2 := Combatant.new("Member 2", 30, 10, 12, 8, 10, false)
	var m3 := Combatant.new("Member 3", 30, 10, 12, 8, 10, false)
	var clerk: Combatant = BattleContentSeam.enemy("enemy_clerk")
	var battle := BattleCore.new([chef, m1, m2, m3], [clerk],
			_seeded_rng(), BattleContentSeam.scripted_rule([]))
	battle.start_battle()
	# Chef stays at full HP (the clamp edge case: a member at full HP gains 0).
	BattleContentSeam.arrange_vitals(m1, 10, m1.mp)
	BattleContentSeam.arrange_vitals(m2, 27, m2.mp)
	BattleContentSeam.arrange_vitals(m3, 0, 0)

	var outcome: BattleOutcome = battle.submit_action(BattleContentSeam.move("move_family_meal"))

	assert_int(outcome.mp_delta).is_equal(-5)
	assert_int(outcome.hp_delta).is_equal(_FAMILY_MEAL_HP_DELTA)
	assert_int(chef.hp).is_equal(chef.max_hp)
	assert_int(m1.hp).is_equal(_FAMILY_MEAL_M1_HP)
	assert_int(m2.hp).is_equal(_FAMILY_MEAL_M2_HP)
	assert_int(m3.hp).is_equal(0)


# --- Test: Appetizer (the Michelin Chef) ---

func test_appetizer_heals_one_damaged_ally_for_the_pin() -> void:
	var chef: Combatant = _squad_member(CharacterizationExpected.SQUAD_CHEF)
	var ally := Combatant.new("Ally", 30, 10, 12, 8, 10, false)
	var clerk: Combatant = BattleContentSeam.enemy("enemy_clerk")
	var battle := BattleCore.new([chef, ally], [clerk],
			_seeded_rng(), BattleContentSeam.scripted_rule([]))
	battle.start_battle()
	BattleContentSeam.arrange_vitals(ally, 10, ally.mp)

	var outcome: BattleOutcome = battle.submit_action(BattleContentSeam.move("move_appetizer"), ally)

	assert_int(outcome.mp_delta).is_equal(-3)
	assert_int(outcome.hp_delta).is_equal(_APPETIZER_HEAL)
	assert_int(ally.hp).is_equal(10 + _APPETIZER_HEAL)


## Edge case: submitting against a knocked-out ally is rejected at submit
## (returns null), and hp/mp are unchanged (ADR-0010 relies on this).
func test_appetizer_on_a_knocked_out_ally_is_rejected() -> void:
	var chef: Combatant = _squad_member(CharacterizationExpected.SQUAD_CHEF)
	var ko_ally := Combatant.new("KO Ally", 30, 10, 12, 8, 10, false)
	var clerk: Combatant = BattleContentSeam.enemy("enemy_clerk")
	var battle := BattleCore.new([chef, ko_ally], [clerk],
			_seeded_rng(), BattleContentSeam.scripted_rule([]))
	battle.start_battle()
	BattleContentSeam.arrange_vitals(ko_ally, 0, 0)

	var result: BattleOutcome = battle.submit_action(BattleContentSeam.move("move_appetizer"), ko_ally)

	assert_object(result).is_null()
	assert_int(ko_ally.hp).is_equal(0)
	assert_int(chef.mp).is_equal(chef.max_mp)


# --- Test: Viral Stunt (Florida Man) ---

## `vulnerable_rounds_left` is 2 straight after the stunt, 1 after the first
## round tick, 0 after the second.
func test_viral_stunt_sets_vulnerable_rounds_and_ticks_down_each_round() -> void:
	var florida_man: Combatant = _squad_member(CharacterizationExpected.SQUAD_FLORIDA_MAN)
	var second: Combatant = Combatant.new("Second", 30, 10, 12, 8, 10, false)
	var clerk: Combatant = BattleContentSeam.enemy("enemy_clerk")
	var battle := BattleCore.new([florida_man, second], [clerk],
			_seeded_rng(), BattleContentSeam.scripted_rule([]))
	battle.start_battle()

	var outcome: BattleOutcome = battle.submit_action(BattleContentSeam.move("move_viral_stunt"), clerk)
	assert_int(outcome.mp_delta).is_equal(-3)
	assert_int(outcome.hp_delta).is_equal(0)
	assert_int(clerk.vulnerable_rounds_left).is_equal(2)

	battle.submit_action(Move.make_defend())  # Second's turn: completes round 1's tick.
	assert_int(clerk.vulnerable_rounds_left).is_equal(1)

	battle.submit_action(Move.make_defend())  # Florida Man, round 2.
	battle.submit_action(Move.make_defend())  # Second, round 2: completes the tick.
	assert_int(clerk.vulnerable_rounds_left).is_equal(0)


## One Attack while Viral Stunt is active deals the pinned (+50%) damage, and
## `rng.state` afterward is pinned too (SEED_A, the only draw this battle makes).
func test_attack_on_a_vulnerable_target_deals_the_boosted_pinned_damage() -> void:
	var florida_man: Combatant = _squad_member(CharacterizationExpected.SQUAD_FLORIDA_MAN)
	var attacker := Combatant.new("Attacker", 30, 10, 10, 8, 10, false)
	var clerk: Combatant = BattleContentSeam.enemy("enemy_clerk")
	var rng := RandomNumberGenerator.new()
	rng.seed = CharacterizationExpected.SEED_A
	var battle := BattleCore.new([florida_man, attacker], [clerk], rng,
			BattleContentSeam.scripted_rule([]))
	battle.start_battle()
	battle.submit_action(BattleContentSeam.move("move_viral_stunt"), clerk)

	var outcome: BattleOutcome = battle.submit_action(Move.make_attack(), clerk)

	assert_int(-outcome.hp_delta).is_equal(_VIRAL_BOOSTED_ATTACK_DAMAGE)
	assert_int(rng.state).is_equal(_VIRAL_BOOSTED_ATTACK_RNG_STATE)


# --- Test: Home Run (the Baguette Thrower) ---

## GIVEN the Baguette Thrower against each of the 5 enemies (scripted rule,
## SEED_B), THEN hp_delta and the final rng.state equal the pins.
func test_home_run_damage_against_each_enemy_equals_the_pin() -> void:
	var baguette: Combatant = _squad_member(CharacterizationExpected.SQUAD_BAGUETTE_THROWER)
	var enemy_list: Array[Combatant] = []
	for id: String in CharacterizationExpected.ENEMY_IDS:
		enemy_list.append(BattleContentSeam.enemy(id))
	var rng := RandomNumberGenerator.new()
	rng.seed = CharacterizationExpected.SEED_B
	var battle := BattleCore.new([baguette], enemy_list, rng, BattleContentSeam.scripted_rule([]))
	battle.start_battle()

	for i: int in enemy_list.size():
		# 12 MP covers only three 4-MP throws; refill through the seam (no RNG draw).
		BattleContentSeam.arrange_vitals(baguette, baguette.hp, baguette.max_mp)
		var outcome: BattleOutcome = battle.submit_action(BattleContentSeam.move("move_home_run"), enemy_list[i])
		assert_object(outcome).override_failure_message("throw %d rejected" % i).is_not_null()
		if outcome == null:
			return
		assert_int(outcome.mp_delta).override_failure_message("throw %d" % i).is_equal(-4)
		assert_int(-outcome.hp_delta).override_failure_message(
				"enemy %d (%s)" % [i, CharacterizationExpected.ENEMY_IDS[i]]).is_equal(_HOME_RUN_DAMAGE[i])

	assert_int(rng.state).is_equal(_HOME_RUN_RNG_STATE)
