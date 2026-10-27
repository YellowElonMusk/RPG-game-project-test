## Story 001 (ADR-0001 Migration Step 0; ADR-0011 Migration Step 1): proves
## BattleContentSeam builds every shipped enemy, move and rule by its future
## record ID, normalises enemy turns, arranges vitals, scripts enemy turns,
## and fails the calling test on an unknown ID. Display names below are
## literal copies of today's factories' own values, read once -- never a
## reference to a factory's `const` (ADR-0001 Migration Step 0's own rule).
extends GdUnitTestSuite

## Enemy id -> its factory's pinned display_name.
const _ENEMY_DISPLAY_NAMES: Dictionary = {
	"enemy_clerk": "Clerk",
	"enemy_supervisor": "Supervisor",
	"enemy_security_drone": "Security Drone",
	"enemy_middle_manager": "Middle Manager",
	"enemy_ceo": "CEO",
}

## Move id -> its pinned display_name (9 named attacks, then 5 Specials).
const _MOVE_DISPLAY_NAMES: Dictionary = {
	"move_pen_jab": "Pen Jab",
	"move_red_tape": "Red Tape",
	"move_late_fee": "Late Fee",
	"move_mass_audit": "Mass Audit",
	"move_final_notice": "Final Notice",
	"move_laser_scan": "Laser Scan",
	"move_upsell": "Upsell",
	"move_layoffs": "Layoffs",
	"move_hostile_takeover": "Hostile Takeover",
	"move_speak_to_the_manager": "Speak to the Manager",
	"move_family_meal": "Family Meal",
	"move_appetizer": "Appetizer",
	"move_viral_stunt": "Viral Stunt",
	"move_home_run": "Home Run",
}


## Builds a plain 4-member squad, all at full HP/MP (today's factory shape;
## stats are arbitrary since this test's rules don't read them).
func _fixture_squad() -> Array[Combatant]:
	var squad: Array[Combatant] = []
	for i: int in range(4):
		squad.append(Combatant.new("Squad %d" % i, 30, 10, 12, 8, 10, false))
	return squad


# --- Test: seam builds every ID ---

func test_seam_builds_every_enemy_id_with_the_right_display_name() -> void:
	for id: String in CharacterizationExpected.ENEMY_IDS:
		var combatant: Combatant = BattleContentSeam.enemy(id)
		assert_object(combatant).override_failure_message("enemy(%s)" % id).is_not_null()
		assert_str(combatant.display_name).override_failure_message("enemy(%s)" % id).is_equal(_ENEMY_DISPLAY_NAMES[id])


func test_seam_builds_every_move_id_with_the_right_display_name() -> void:
	for id: String in CharacterizationExpected.MOVE_IDS:
		var built_move: Move = BattleContentSeam.move(id)
		assert_object(built_move).override_failure_message("move(%s)" % id).is_not_null()
		assert_str(built_move.display_name).override_failure_message("move(%s)" % id).is_equal(_MOVE_DISPLAY_NAMES[id])


func test_seam_builds_every_rule_id() -> void:
	assert_object(BattleContentSeam.rule("rule_bureaucratia_permit")).is_instanceof(BureaucratiaRule)
	assert_object(BattleContentSeam.rule("rule_megacorp_billing")).is_instanceof(MegaCorpRule)


## Edge case: two calls for the same ID return different objects.
func test_two_calls_for_the_same_id_return_different_objects() -> void:
	assert_object(BattleContentSeam.enemy("enemy_clerk")) \
			.is_not_same(BattleContentSeam.enemy("enemy_clerk"))
	assert_object(BattleContentSeam.move("move_pen_jab")) \
			.is_not_same(BattleContentSeam.move("move_pen_jab"))
	assert_object(BattleContentSeam.rule("rule_bureaucratia_permit")) \
			.is_not_same(BattleContentSeam.rule("rule_bureaucratia_permit"))


# --- Test: enemy_turn normalises ---

## GIVEN seam.rule("rule_bureaucratia_permit"), a Clerk, the 4-member fixture
## squad, round 1, rng.seed = SEED_A, WHEN enemy_turn runs, THEN the result
## holds {"Pen Jab", 5, <target>} -- and, since specials are banned and the
## squad is at full HP, also the pre-permit Defend with power 0 (pinned, so
## story 006 sees the hunker).
func test_enemy_turn_normalises_the_hunker_down_turn() -> void:
	var rule: FactionRule = BattleContentSeam.rule("rule_bureaucratia_permit")
	var clerk: Combatant = BattleContentSeam.enemy("enemy_clerk")
	var squad: Array[Combatant] = _fixture_squad()
	var rng := RandomNumberGenerator.new()
	rng.seed = CharacterizationExpected.SEED_A

	var turn: Array = BattleContentSeam.enemy_turn(rule, clerk, squad, 1, rng)

	var pen_jab_entries: Array = turn.filter(func(a: Dictionary) -> bool: return a["move_name"] == "Pen Jab")
	assert_int(pen_jab_entries.size()).override_failure_message("turn: %s" % [turn]).is_equal(1)
	var pen_jab: Dictionary = pen_jab_entries[0]
	assert_int(pen_jab["power"]).is_equal(5)
	assert_object(pen_jab["target"]).is_not_null()

	var defend_entries: Array = turn.filter(func(a: Dictionary) -> bool: return a["move_name"] == "Defend")
	assert_int(defend_entries.size()).override_failure_message("turn: %s" % [turn]).is_equal(1)
	assert_int((defend_entries[0] as Dictionary)["power"]).is_equal(0)


# --- Test: arrange_vitals ---

func test_arrange_vitals_sets_hp_and_mp() -> void:
	var karen := Combatant.new("Karen", 34, 12, 12, 9, 11, false)

	BattleContentSeam.arrange_vitals(karen, 17, 0)

	assert_int(karen.hp).is_equal(17)
	assert_int(karen.mp).is_equal(0)


## Edge case: arranging to 0/0 gives a knocked-out combatant.
func test_arrange_vitals_to_zero_gives_knocked_out() -> void:
	var karen := Combatant.new("Karen", 34, 12, 12, 9, 11, false)

	BattleContentSeam.arrange_vitals(karen, 0, 0)

	assert_bool(karen.is_knocked_out()).is_true()


## Edge case: hp above max_hp fails the calling test.
func test_arrange_vitals_above_max_hp_fails() -> void:
	var karen := Combatant.new("Karen", 34, 12, 12, 9, 11, false)

	assert_failure(func() -> void: BattleContentSeam.arrange_vitals(karen, 35, 0)).is_failed()


# --- Test: scripted_rule follows its script ---

func test_scripted_rule_follows_its_script() -> void:
	var rule: FactionRule = BattleContentSeam.scripted_rule([
		{"move_id": "move_late_fee", "target_index": 1},
	])
	var squad: Array[Combatant] = _fixture_squad()
	var enemies: Array[Combatant] = [BattleContentSeam.enemy("enemy_clerk")]
	var battle := BattleCore.new(squad, enemies, RandomNumberGenerator.new(), rule)
	battle.start_battle()

	# Exactly one round's worth of Defends: the 4th submit_action runs the
	# enemy phase synchronously and returns with round 2 already begun, so a
	# bounded loop (not an open while) avoids looping into further rounds.
	for _i: int in squad.size():
		battle.submit_action(Move.make_defend())

	var enemy_actions: Array[BattleOutcome] = []
	for outcome: BattleOutcome in battle.outcome_log:
		if outcome.actor == enemies[0]:
			enemy_actions.append(outcome)
	assert_int(enemy_actions.size()).override_failure_message(
			"outcome_log: %s" % [battle.outcome_log]).is_equal(1)
	assert_str(enemy_actions[0].move_name).is_equal("Late Fee")
	assert_object(enemy_actions[0].target).is_same(squad[1])


## A two-entry script with two enemies: each enemy's turn takes the next
## entry in order (the cursor advances once per choose_enemy_action call).
func test_scripted_rule_advances_one_entry_per_enemy_turn() -> void:
	var rule: FactionRule = BattleContentSeam.scripted_rule([
		{"move_id": "move_late_fee", "target_index": 0},
		{"move_id": "move_upsell", "target_index": 2},
	])
	var squad: Array[Combatant] = _fixture_squad()
	var enemies: Array[Combatant] = [BattleContentSeam.enemy("enemy_clerk"), BattleContentSeam.enemy("enemy_middle_manager")]
	var battle := BattleCore.new(squad, enemies, RandomNumberGenerator.new(), rule)
	battle.start_battle()

	for _i: int in squad.size():
		battle.submit_action(Move.make_defend())

	var enemy_actions: Array[BattleOutcome] = []
	for outcome: BattleOutcome in battle.outcome_log:
		if outcome.actor.is_enemy:
			enemy_actions.append(outcome)
	assert_int(enemy_actions.size()).override_failure_message(
			"outcome_log: %s" % [battle.outcome_log]).is_equal(2)
	if enemy_actions.size() != 2:
		return
	assert_object(enemy_actions[0].actor).is_same(enemies[0])
	assert_str(enemy_actions[0].move_name).is_equal("Late Fee")
	assert_object(enemy_actions[0].target).is_same(squad[0])
	assert_object(enemy_actions[1].actor).is_same(enemies[1])
	assert_str(enemy_actions[1].move_name).is_equal("Upsell")
	assert_object(enemy_actions[1].target).is_same(squad[2])


## Edge case: an empty script yields no enemy action.
func test_scripted_rule_empty_script_yields_no_enemy_action() -> void:
	var rule: FactionRule = BattleContentSeam.scripted_rule([])
	var squad: Array[Combatant] = _fixture_squad()
	var enemies: Array[Combatant] = [BattleContentSeam.enemy("enemy_clerk")]
	var battle := BattleCore.new(squad, enemies, RandomNumberGenerator.new(), rule)
	battle.start_battle()

	for _i: int in squad.size():
		battle.submit_action(Move.make_defend())

	for outcome: BattleOutcome in battle.outcome_log:
		assert_object(outcome.actor).override_failure_message(
				"outcome_log: %s" % [battle.outcome_log]).is_not_same(enemies[0])


## Edge case: specials_allowed(1) is true under the scripted double, even
## though round 1 would ban them under a real rule.
func test_scripted_rule_allows_specials_in_round_one() -> void:
	var rule: FactionRule = BattleContentSeam.scripted_rule([])

	assert_bool(rule.specials_allowed(1)).is_true()


# --- Test: unknown ID fails ---

func test_unknown_enemy_id_fails() -> void:
	assert_failure(func() -> void: BattleContentSeam.enemy("enemy_nope")).is_failed()


func test_unknown_move_id_fails() -> void:
	assert_failure(func() -> void: BattleContentSeam.move("move_nope")).is_failed()


func test_unknown_rule_id_fails() -> void:
	assert_failure(func() -> void: BattleContentSeam.rule("rule_nope")).is_failed()
