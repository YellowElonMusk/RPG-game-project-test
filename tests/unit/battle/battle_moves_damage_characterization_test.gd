## Story 005 (ADR-0001 Migration Step 0; ADR-0007 Migration Step 0; ADR-0011
## §5): pins every enemy named attack, the generic Attack and Home Run
## against every shipped stat block, under a seeded RNG, taken through
## `BattleCore` (RC-2: `DamageCalculator.calculate_damage()` is pinned this
## way because ADR-0007 Step 2 deletes it). Every case is built fresh from
## `CharacterizationExpected.DAMAGE_CASES` and `CharacterizationExpected.
## DAMAGE_SEED`, reseeded per case, through `BattleContentSeam`. AC-2 (the
## rule-emitted-fields check) calls the shipped rules directly, the same call
## shape story 006 will exercise, and compares the `Move` they emit against
## `seam.move(id)`.
extends GdUnitTestSuite

const _SQUAD_KEYS: Array[String] = ["karen", "chef", "florida_man", "baguette_thrower"]
const _ENEMY_IDS: Array[String] = ["enemy_clerk", "enemy_supervisor", "enemy_security_drone", "enemy_middle_manager", "enemy_ceo"]


func _squad_combatant(key: String) -> Combatant:
	var block: Dictionary
	match key:
		"karen": block = CharacterizationExpected.SQUAD_KAREN
		"chef": block = CharacterizationExpected.SQUAD_CHEF
		"florida_man": block = CharacterizationExpected.SQUAD_FLORIDA_MAN
		"baguette_thrower": block = CharacterizationExpected.SQUAD_BAGUETTE_THROWER
	return Combatant.new(block["name"], block["max_hp"], block["max_mp"],
			block["attack"], block["defense"], block["speed"], false)


func _move_for(id: String) -> Move:
	if id == "attack":
		return Move.make_attack()
	return BattleContentSeam.move(id)


## Enemy-side case (AC-1a): the enemy acts on a scripted turn against the
## squad target. `state == "plain"`: the target heals itself (Appetizer,
## self-targeted -- no RNG draw, no state flag set) before the enemy's
## scripted action. `state == "defending"`: the target Defends instead (also
## no RNG draw). Either way the enemy's action is the case's only draw.
func _run_enemy_side_case(enemy_id: String, move_id: String, squad_key: String, state: String) -> Dictionary:
	var target: Combatant = _squad_combatant(squad_key)
	var attacker_enemy: Combatant = BattleContentSeam.enemy(enemy_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = CharacterizationExpected.DAMAGE_SEED
	var rule: FactionRule = BattleContentSeam.scripted_rule([
		{"move": _move_for(move_id), "target_index": 0},
	])
	var battle := BattleCore.new([target], [attacker_enemy], rng, rule)
	battle.start_battle()
	if state == "defending":
		battle.submit_action(Move.make_defend())
	else:
		battle.submit_action(BattleContentSeam.move("move_appetizer"), target)
	var tested: BattleOutcome = null
	for outcome: BattleOutcome in battle.outcome_log:
		if outcome.actor == attacker_enemy:
			tested = outcome
	return {"hp_delta": tested.hp_delta, "target_hp": target.hp, "rng_state": rng.state}


## Squad-side case (AC-1b): the squad attacker acts directly against the
## enemy target.
## - "plain": the attacker's move is the battle's only action.
## - "defending": round 1, the attacker self-heals (filler, no draw) while a
##   scripted enemy Defend sets its flag; round 2, the attacker's tested move
##   lands while that flag is still set (cleared only at the top of round 2's
##   own enemy phase, which runs after the tested action).
## - "vulnerable": a dedicated Florida Man helper casts Viral Stunt on the
##   target first (no draw), then the attacker's tested move follows in the
##   same round, before the round's own vulnerable-rounds tick.
func _run_squad_side_case(squad_key: String, move_id: String, enemy_id: String, state: String) -> Dictionary:
	var attacker: Combatant = _squad_combatant(squad_key)
	var target_enemy: Combatant = BattleContentSeam.enemy(enemy_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = CharacterizationExpected.DAMAGE_SEED
	var move_for_attacker: Move = _move_for(move_id)
	var tested: BattleOutcome = null
	match state:
		"plain":
			var battle := BattleCore.new([attacker], [target_enemy], rng, BattleContentSeam.scripted_rule([]))
			battle.start_battle()
			tested = battle.submit_action(move_for_attacker, target_enemy)
		"defending":
			var rule: FactionRule = BattleContentSeam.scripted_rule([
				{"move": Move.make_defend(), "target_index": 0},
			])
			var battle := BattleCore.new([attacker], [target_enemy], rng, rule)
			battle.start_battle()
			battle.submit_action(BattleContentSeam.move("move_appetizer"), attacker)
			tested = battle.submit_action(move_for_attacker, target_enemy)
		"vulnerable":
			var helper: Combatant = _squad_combatant("florida_man")
			var battle := BattleCore.new([helper, attacker], [target_enemy], rng, BattleContentSeam.scripted_rule([]))
			battle.start_battle()
			battle.submit_action(BattleContentSeam.move("move_viral_stunt"), target_enemy)
			tested = battle.submit_action(move_for_attacker, target_enemy)
	return {"hp_delta": tested.hp_delta, "target_hp": target_enemy.hp, "rng_state": rng.state}


# --- Test: enemy-side matrix (AC-1a, 16 pairs x 4 targets x 2 states = 128) ---

func test_enemy_side_damage_matrix_equals_the_pins() -> void:
	for pair: Dictionary in CharacterizationExpected.DAMAGE_CASES["enemy_side"]:
		for squad_key: String in _SQUAD_KEYS:
			for state: String in ["plain", "defending"]:
				var pin: Array = pair["results"]["%s:%s" % [squad_key, state]]
				var label: String = "%s/%s vs %s (%s)" % [pair["enemy"], pair["move"], squad_key, state]
				var result: Dictionary = _run_enemy_side_case(pair["enemy"], pair["move"], squad_key, state)
				assert_int(result["hp_delta"]).override_failure_message(label).is_equal(pin[0])
				assert_int(result["target_hp"]).override_failure_message(label).is_equal(pin[1])
				assert_int(result["rng_state"]).override_failure_message(label).is_equal(CharacterizationExpected.DAMAGE_CASE_RNG_STATE)


# --- Test: squad-side matrix (AC-1b, 5 pairs x 5 targets x 3 states = 75) ---

func test_squad_side_damage_matrix_equals_the_pins() -> void:
	for pair: Dictionary in CharacterizationExpected.DAMAGE_CASES["squad_side"]:
		for enemy_id: String in _ENEMY_IDS:
			for state: String in ["plain", "defending", "vulnerable"]:
				var pin: Array = pair["results"]["%s:%s" % [enemy_id, state]]
				var label: String = "%s/%s vs %s (%s)" % [pair["squad"], pair["move"], enemy_id, state]
				var result: Dictionary = _run_squad_side_case(pair["squad"], pair["move"], enemy_id, state)
				assert_int(result["hp_delta"]).override_failure_message(label).is_equal(pin[0])
				assert_int(result["target_hp"]).override_failure_message(label).is_equal(pin[1])
				assert_int(result["rng_state"]).override_failure_message(label).is_equal(CharacterizationExpected.DAMAGE_CASE_RNG_STATE)


## Edge case: minimum damage (1) is reached and clamped (CharacterizationExpected.DAMAGE_FLOOR_CASE).
func test_minimum_damage_floor_of_one_is_reached() -> void:
	var weak_attacker := Combatant.new("Weakling", 20, 0, 1, 0, 5, false)
	var tank: Combatant = BattleContentSeam.enemy(CharacterizationExpected.DAMAGE_FLOOR_CASE["target_enemy"])
	var rng := RandomNumberGenerator.new()
	rng.seed = CharacterizationExpected.DAMAGE_SEED
	var battle := BattleCore.new([weak_attacker], [tank], rng, BattleContentSeam.scripted_rule([]))
	battle.start_battle()

	var outcome: BattleOutcome = battle.submit_action(Move.make_attack(), tank)

	assert_int(outcome.hp_delta).is_equal(CharacterizationExpected.DAMAGE_FLOOR_CASE["hp_delta"])
	assert_int(tank.hp).is_equal(CharacterizationExpected.DAMAGE_FLOOR_CASE["target_hp"])
	assert_int(rng.state).is_equal(CharacterizationExpected.DAMAGE_FLOOR_CASE["rng_state"])


# --- Test: rule-emitted fields equal the seam (AC-2) ---

## Builds a 4-member living squad at full HP so `_weakest()` picks a stable
## member regardless of which named attack targets "the weakest."
func _rule_test_squad() -> Array[Combatant]:
	var squad: Array[Combatant] = []
	for key: String in _SQUAD_KEYS:
		squad.append(_squad_combatant(key))
	return squad


## Each named-attack id, and a scenario that makes the shipped rule emit it
## (the same call shape story 006 exercises): [rule, enemy_id, round, is_low_hp].
const _NAMED_ATTACK_SCENARIOS: Dictionary = {
	"move_pen_jab": {"faction": "bureaucratia", "enemy": "enemy_clerk", "round": 1, "weaken_first": false},
	"move_red_tape": {"faction": "bureaucratia", "enemy": "enemy_clerk", "round": 1, "weaken_first": true},
	"move_late_fee": {"faction": "bureaucratia", "enemy": "enemy_clerk", "round": 4, "weaken_first": false},
	"move_mass_audit": {"faction": "bureaucratia", "enemy": "enemy_supervisor", "round": 4, "weaken_first": false},
	"move_final_notice": {"faction": "bureaucratia", "enemy": "enemy_supervisor", "round": 5, "weaken_first": false},
	"move_laser_scan": {"faction": "megacorp", "enemy": "enemy_security_drone", "round": 1, "weaken_first": false},
	"move_upsell": {"faction": "megacorp", "enemy": "enemy_middle_manager", "round": 1, "weaken_first": false},
	"move_layoffs": {"faction": "megacorp", "enemy": "enemy_ceo", "round": 1, "weaken_first": false},
	"move_hostile_takeover": {"faction": "megacorp", "enemy": "enemy_ceo", "round": 2, "weaken_first": false},
}


func test_each_named_attack_emitted_by_its_rule_matches_the_seam() -> void:
	for move_id: String in _NAMED_ATTACK_SCENARIOS:
		var scenario: Dictionary = _NAMED_ATTACK_SCENARIOS[move_id]
		var expected: Move = BattleContentSeam.move(move_id)
		var rule: FactionRule = BureaucratiaRule.new() if scenario["faction"] == "bureaucratia" else MegaCorpRule.new()
		var enemy: Combatant = BattleContentSeam.enemy(scenario["enemy"])
		var squad: Array[Combatant] = _rule_test_squad()
		if scenario["weaken_first"]:
			BattleContentSeam.arrange_vitals(squad[0], 1, squad[0].mp)
		var rng := RandomNumberGenerator.new()
		rng.seed = CharacterizationExpected.DAMAGE_SEED

		var actions: Array = rule.choose_enemy_action(enemy, squad, scenario["round"], rng)
		var emitted: Move = null
		for action: Dictionary in actions:
			var candidate: Move = action.get("move")
			if candidate != null and candidate.display_name == expected.display_name:
				emitted = candidate
		assert_object(emitted).override_failure_message(
				"%s: actions were %s" % [move_id, actions]).is_not_null()
		if emitted == null:
			continue

		assert_str(emitted.display_name).override_failure_message(move_id).is_equal(expected.display_name)
		assert_int(emitted.power).override_failure_message(move_id).is_equal(expected.power)
		assert_int(emitted.category).override_failure_message(move_id).is_equal(expected.category)
		assert_int(emitted.mp_cost).override_failure_message(move_id).is_equal(expected.mp_cost)
		assert_int(emitted.target_type).override_failure_message(move_id).is_equal(expected.target_type)
