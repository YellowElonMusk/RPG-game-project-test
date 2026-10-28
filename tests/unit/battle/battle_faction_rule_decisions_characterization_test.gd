## Story 006 (ADR-0011 Migration Step 1; ADR-0001 Migration Step 0): pins both
## shipped faction rules' decisions -- the permit round, the AI's picks
## before and after it, MegaCorp's per-enemy move choice, billing and
## suspension -- by calling each rule's methods directly (they are pure:
## `specials_allowed`/`move_allowed` take no RNG at all, and
## `choose_enemy_action`/`apply_round_upkeep` only touch the `living_squad`
## and `rng` passed in). No `BattleCore` is needed anywhere in this file.
## Low-HP/MP states are arranged only through `BattleContentSeam.
## arrange_vitals`. Pinned numbers are literal copies read once from today's
## code, never a reference to `BureaucratiaRule`/`MegaCorpRule` constants.
extends GdUnitTestSuite


func _squad_member(block: Dictionary) -> Combatant:
	return Combatant.new(block["name"], block["max_hp"], block["max_mp"],
			block["attack"], block["defense"], block["speed"], false)


## The 4-member fixture squad, in the fixed order `RULE_SEED`'s pins assume:
## karen, chef, florida_man, baguette_thrower.
func _fixture_squad() -> Array[Combatant]:
	var squad: Array[Combatant] = []
	for block: Dictionary in [
		CharacterizationExpected.SQUAD_KAREN, CharacterizationExpected.SQUAD_CHEF,
		CharacterizationExpected.SQUAD_FLORIDA_MAN, CharacterizationExpected.SQUAD_BAGUETTE_THROWER]:
		squad.append(_squad_member(block))
	return squad


## Every call gets a seeded RNG, including branches that draw nothing today,
## so extending a test can't make it silently non-deterministic (same reason
## as story 002's `_seeded_rng()`).
func _seeded_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = CharacterizationExpected.RULE_SEED
	return rng


# --- Test: permit boundary ---

func test_specials_allowed_permit_boundary() -> void:
	var rule := BureaucratiaRule.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = CharacterizationExpected.RULE_SEED
	var initial_state: int = rng.state

	var results: Array[bool] = []
	for r: int in range(1, 7):
		results.append(rule.specials_allowed(r))

	assert_array(results).is_equal([false, false, false, true, true, true])
	assert_int(rng.state).override_failure_message(
			"specials_allowed must draw no RNG").is_equal(initial_state)


# --- Test: Bureaucratia AI by round and HP ---

## Pre-permit, every member above half HP: the enemy hunkers down (Defend)
## and jabs the `rng.randi_range` target, pinned by `RULE_SEED`.
func test_pre_permit_healthy_squad_hunkers_and_jabs_rng_target() -> void:
	for enemy: Combatant in [BureaucratiaRule.make_clerk(), BureaucratiaRule.make_supervisor()]:
		for round_number: int in [1, 2, 3]:
			var squad := _fixture_squad()
			var rng := RandomNumberGenerator.new()
			rng.seed = CharacterizationExpected.RULE_SEED
			var rule := BureaucratiaRule.new()

			var actions: Array = rule.choose_enemy_action(enemy, squad, round_number, rng)

			var label: String = "%s round %d" % [enemy.display_name, round_number]
			assert_int(actions.size()).override_failure_message(label).is_equal(2)
			assert_str((actions[0]["move"] as Move).display_name).override_failure_message(label).is_equal("Defend")
			var jab: Dictionary = actions[1]
			assert_str((jab["move"] as Move).display_name).override_failure_message(label).is_equal("Pen Jab")
			assert_int((jab["move"] as Move).power).override_failure_message(label).is_equal(5)
			assert_object(jab["target"]).override_failure_message(label) \
					.is_same(squad[CharacterizationExpected.PEN_JAB_TARGET_INDEX])
			assert_int(rng.state).override_failure_message(label).is_equal(CharacterizationExpected.RULE_RNG_STATE_AFTER_ONE_DRAW)


## Pre-permit, the weakest at or below half HP: Red Tape on the weakest, no
## RNG draw at all (the hunker/jab branch is the only one that uses `rng`).
func test_pre_permit_low_hp_squad_gets_red_tape_no_rng_draw() -> void:
	var squad := _fixture_squad()
	BattleContentSeam.arrange_vitals(squad[1], 10, squad[1].mp)  # Chef, well below half.
	var rng := RandomNumberGenerator.new()
	rng.seed = CharacterizationExpected.RULE_SEED
	var initial_state: int = rng.state
	var rule := BureaucratiaRule.new()

	var actions: Array = rule.choose_enemy_action(BureaucratiaRule.make_clerk(), squad, 1, rng)

	assert_int(actions.size()).is_equal(1)
	assert_str((actions[0]["move"] as Move).display_name).is_equal("Red Tape")
	assert_int((actions[0]["move"] as Move).power).is_equal(10)
	assert_object(actions[0]["target"]).is_same(squad[1])
	assert_int(rng.state).override_failure_message("Red Tape must draw no RNG").is_equal(initial_state)


## Edge case: exactly 50% HP is inclusive (Red Tape); one HP above it is not
## (Pen Jab, the healthy/hunker branch).
func test_exactly_half_hp_boundary_is_inclusive() -> void:
	var squad := _fixture_squad()
	BattleContentSeam.arrange_vitals(squad[0], 17, squad[0].mp)  # Karen 17/34 == 0.5 exactly.
	var rng := RandomNumberGenerator.new()
	rng.seed = CharacterizationExpected.RULE_SEED
	var rule := BureaucratiaRule.new()

	var actions: Array = rule.choose_enemy_action(BureaucratiaRule.make_clerk(), squad, 1, rng)

	assert_int(actions.size()).is_equal(1)
	assert_str((actions[0]["move"] as Move).display_name).is_equal("Red Tape")
	assert_object(actions[0]["target"]).is_same(squad[0])


func test_one_hp_above_half_boundary_is_the_healthy_branch() -> void:
	var squad := _fixture_squad()
	BattleContentSeam.arrange_vitals(squad[0], 18, squad[0].mp)  # Karen 18/34 > 0.5.
	var rng := RandomNumberGenerator.new()
	rng.seed = CharacterizationExpected.RULE_SEED
	var rule := BureaucratiaRule.new()

	var actions: Array = rule.choose_enemy_action(BureaucratiaRule.make_clerk(), squad, 1, rng)

	assert_int(actions.size()).is_equal(2)
	assert_str((actions[1]["move"] as Move).display_name).is_equal("Pen Jab")


## Edge case: a two-member tie at equal fraction targets the first in squad
## order (`_weakest` uses strict `<`).
func test_weakest_tie_goes_to_the_first_in_squad_order() -> void:
	var squad := _fixture_squad()
	BattleContentSeam.arrange_vitals(squad[0], 17, squad[0].mp)  # Karen 17/34 == 0.5.
	BattleContentSeam.arrange_vitals(squad[1], 15, squad[1].mp)  # Chef 15/30 == 0.5, same fraction.
	var rng := RandomNumberGenerator.new()
	rng.seed = CharacterizationExpected.RULE_SEED
	var rule := BureaucratiaRule.new()

	var actions: Array = rule.choose_enemy_action(BureaucratiaRule.make_clerk(), squad, 1, rng)

	assert_object(actions[0]["target"]).override_failure_message(
			"tie must resolve to squad[0] (Karen), not squad[1] (Chef)").is_same(squad[0])


func test_post_permit_clerk_late_fee_on_weakest() -> void:
	var squad := _fixture_squad()
	BattleContentSeam.arrange_vitals(squad[2], 10, squad[2].mp)  # Florida Man, the weakest.
	var rule := BureaucratiaRule.new()

	var actions: Array = rule.choose_enemy_action(BureaucratiaRule.make_clerk(), squad, 4, _seeded_rng())

	assert_int(actions.size()).is_equal(1)
	assert_str((actions[0]["move"] as Move).display_name).is_equal("Late Fee")
	assert_int((actions[0]["move"] as Move).power).is_equal(16)
	assert_object(actions[0]["target"]).is_same(squad[2])


## Mass Audit hits every living member, each its own action, in squad order.
## 3 living members (one left out of `living_squad` entirely, as `BattleCore`
## would do for a knocked-out one) gives exactly 3 actions.
func test_post_permit_supervisor_mass_audit_hits_every_living_member_in_order() -> void:
	var full_squad := _fixture_squad()
	var living: Array[Combatant] = [full_squad[0], full_squad[1], full_squad[2]]
	var rule := BureaucratiaRule.new()

	var actions: Array = rule.choose_enemy_action(BureaucratiaRule.make_supervisor(), living, 4, _seeded_rng())

	assert_int(actions.size()).is_equal(3)
	for i: int in 3:
		assert_str((actions[i]["move"] as Move).display_name).override_failure_message("action %d" % i).is_equal("Mass Audit")
		assert_int((actions[i]["move"] as Move).power).override_failure_message("action %d" % i).is_equal(8)
		assert_object(actions[i]["target"]).override_failure_message("action %d" % i).is_same(living[i])


func test_post_permit_supervisor_final_notice_on_weakest_in_odd_rounds() -> void:
	var squad := _fixture_squad()
	BattleContentSeam.arrange_vitals(squad[3], 10, squad[3].mp)  # Baguette Thrower, the weakest.
	var rule := BureaucratiaRule.new()

	var actions: Array = rule.choose_enemy_action(BureaucratiaRule.make_supervisor(), squad, 5, _seeded_rng())

	assert_int(actions.size()).is_equal(1)
	assert_str((actions[0]["move"] as Move).display_name).is_equal("Final Notice")
	assert_int((actions[0]["move"] as Move).power).is_equal(18)
	assert_object(actions[0]["target"]).is_same(squad[3])


# --- Test: MegaCorp AI ---

## The CEO's parity is the reverse of the Supervisor's: Layoffs hits everyone
## in odd rounds, Hostile Takeover hits the weakest in even rounds. Both
## pinned in one test so a copy-paste adapter can't swap them.
func test_megacorp_ceo_parity_is_the_reverse_of_the_supervisors() -> void:
	var squad := _fixture_squad()
	BattleContentSeam.arrange_vitals(squad[1], 10, squad[1].mp)  # Chef, the weakest.
	var rule := MegaCorpRule.new()
	var ceo := MegaCorpRule.make_ceo()

	var odd_actions: Array = rule.choose_enemy_action(ceo, squad, 1, _seeded_rng())
	assert_int(odd_actions.size()).override_failure_message("odd round").is_equal(4)
	for i: int in 4:
		assert_str((odd_actions[i]["move"] as Move).display_name).override_failure_message(
				"odd round action %d" % i).is_equal("Layoffs")
		assert_int((odd_actions[i]["move"] as Move).power).override_failure_message(
				"odd round action %d" % i).is_equal(8)
		assert_object(odd_actions[i]["target"]).override_failure_message(
				"odd round action %d" % i).is_same(squad[i])

	var even_actions: Array = rule.choose_enemy_action(ceo, squad, 2, _seeded_rng())
	assert_int(even_actions.size()).override_failure_message("even round").is_equal(1)
	assert_str((even_actions[0]["move"] as Move).display_name).override_failure_message("even round").is_equal("Hostile Takeover")
	assert_int((even_actions[0]["move"] as Move).power).override_failure_message("even round").is_equal(18)
	assert_object(even_actions[0]["target"]).override_failure_message("even round").is_same(squad[1])


func test_megacorp_middle_manager_upsells_and_drone_laser_scans() -> void:
	var squad := _fixture_squad()
	BattleContentSeam.arrange_vitals(squad[0], 10, squad[0].mp)  # Karen, the weakest.
	var rule := MegaCorpRule.new()

	var manager_actions: Array = rule.choose_enemy_action(MegaCorpRule.make_middle_manager(), squad, 1, _seeded_rng())
	assert_int(manager_actions.size()).is_equal(1)
	assert_str((manager_actions[0]["move"] as Move).display_name).is_equal("Upsell")
	assert_int((manager_actions[0]["move"] as Move).power).is_equal(6)
	assert_object(manager_actions[0]["target"]).is_same(squad[0])

	var drone_actions: Array = rule.choose_enemy_action(MegaCorpRule.make_security_drone(), squad, 1, _seeded_rng())
	assert_int(drone_actions.size()).is_equal(1)
	assert_str((drone_actions[0]["move"] as Move).display_name).is_equal("Laser Scan")
	assert_int((drone_actions[0]["move"] as Move).power).is_equal(11)
	assert_object(drone_actions[0]["target"]).is_same(squad[0])


# --- Test: billing ---

## 1 MP per living member per round, clamped at 0. A knocked-out member is
## not billed: only `living_squad` is ever passed to `apply_round_upkeep`.
func test_billing_drains_mp_to_zero_clamped_and_skips_the_knocked_out() -> void:
	var squad := _fixture_squad()
	BattleContentSeam.arrange_vitals(squad[0], squad[0].max_hp, 2)  # Karen: alive, 2 MP, drains to 0 in round 2, stays 0 after.
	# Baguette Thrower: knocked out but holding 5 MP, so being billed by
	# mistake would show (it couldn't if it started at 0 -- the clamp hides it).
	BattleContentSeam.arrange_vitals(squad[3], 0, 5)
	var living: Array[Combatant] = [squad[0], squad[1], squad[2]]
	var rule := MegaCorpRule.new()

	for _round: int in 3:
		rule.apply_round_upkeep(living)

	assert_int(squad[0].mp).is_equal(0)
	assert_int(squad[1].mp).is_equal(CharacterizationExpected.SQUAD_CHEF["max_mp"] - 3)
	assert_int(squad[2].mp).is_equal(CharacterizationExpected.SQUAD_FLORIDA_MAN["max_mp"] - 3)
	assert_int(squad[3].mp).override_failure_message("knocked-out member must not be billed").is_equal(5)


# --- Test: move_allowed ---

## MegaCorp's suspension rule: Attack always allowed; Defend and a Special
## require MP > 0. Side-effect-free, no RNG.
func test_move_allowed_at_mp_zero_and_mp_positive() -> void:
	var rule := MegaCorpRule.new()
	var actor := _squad_member(CharacterizationExpected.SQUAD_KAREN)
	var attack := Move.make_attack()
	var defend := Move.make_defend()
	var special := BattleContentSeam.move("move_speak_to_the_manager")
	var rng := RandomNumberGenerator.new()
	rng.seed = CharacterizationExpected.RULE_SEED
	var initial_state: int = rng.state

	BattleContentSeam.arrange_vitals(actor, actor.max_hp, 0)
	assert_bool(rule.move_allowed(actor, attack)).override_failure_message("Attack @ 0 MP").is_true()
	assert_bool(rule.move_allowed(actor, defend)).override_failure_message("Defend @ 0 MP").is_false()
	assert_bool(rule.move_allowed(actor, special)).override_failure_message("Special @ 0 MP").is_false()

	BattleContentSeam.arrange_vitals(actor, actor.max_hp, 4)
	assert_bool(rule.move_allowed(actor, attack)).override_failure_message("Attack @ 4 MP").is_true()
	assert_bool(rule.move_allowed(actor, defend)).override_failure_message("Defend @ 4 MP").is_true()
	assert_bool(rule.move_allowed(actor, special)).override_failure_message("Special @ 4 MP").is_true()

	assert_int(rng.state).override_failure_message("move_allowed must draw no RNG").is_equal(initial_state)


# --- Test: statelessness and the neutral control case ---

## Each AI call repeated with the RNG reseeded gives identical output
## (ADR-0011 Validation Criteria).
func test_statelessness_same_seed_gives_identical_output() -> void:
	var rule := BureaucratiaRule.new()
	var clerk := BureaucratiaRule.make_clerk()

	var squad_1 := _fixture_squad()
	var rng_1 := RandomNumberGenerator.new()
	rng_1.seed = CharacterizationExpected.RULE_SEED
	var actions_1: Array = rule.choose_enemy_action(clerk, squad_1, 1, rng_1)

	var squad_2 := _fixture_squad()
	var rng_2 := RandomNumberGenerator.new()
	rng_2.seed = CharacterizationExpected.RULE_SEED
	var actions_2: Array = rule.choose_enemy_action(clerk, squad_2, 1, rng_2)

	assert_int(actions_2.size()).is_equal(actions_1.size())
	for i: int in actions_1.size():
		assert_str((actions_2[i]["move"] as Move).display_name).override_failure_message(
				"action %d" % i).is_equal((actions_1[i]["move"] as Move).display_name)
		var target_index_1: int = squad_1.find(actions_1[i]["target"])
		var target_index_2: int = squad_2.find(actions_2[i]["target"])
		assert_int(target_index_2).override_failure_message("action %d target index" % i).is_equal(target_index_1)
	assert_int(rng_2.state).is_equal(rng_1.state)


## The record-less fallback (ADR-0011 §1): one power-10 Attack on a random
## living member.
func test_neutral_faction_rule_gives_one_attack_on_the_rng_target() -> void:
	var rule := FactionRule.new()
	var squad := _fixture_squad()
	var rng := RandomNumberGenerator.new()
	rng.seed = CharacterizationExpected.RULE_SEED

	var actions: Array = rule.choose_enemy_action(BureaucratiaRule.make_clerk(), squad, 1, rng)

	assert_int(actions.size()).is_equal(1)
	var move: Move = actions[0]["move"]
	assert_str(move.display_name).is_equal("Attack")
	assert_int(move.power).is_equal(10)
	assert_int(move.category).is_equal(Move.Category.ATTACK)
	assert_object(actions[0]["target"]).is_same(squad[CharacterizationExpected.NEUTRAL_TARGET_INDEX])
	assert_int(rng.state).is_equal(CharacterizationExpected.RULE_RNG_STATE_AFTER_ONE_DRAW)
