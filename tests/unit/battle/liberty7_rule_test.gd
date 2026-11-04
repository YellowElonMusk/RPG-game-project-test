## Chapter 4 (Liberty-7, New York): Mandatory Freedom. Nobody may use the
## same command twice in a row; everything else stays allowed; Attack and
## Defend never block each other, so a member always has a legal command;
## the memory clears on Retry; BattleCore refuses a repeat and the command
## menu's reason names it; the shipped record wires the rule.
extends GdUnitTestSuite


func before() -> void:
	BattleContentSeam.ensure_catalog()


func _hero(name: String = "Hero") -> Combatant:
	return Combatant.new(name, 999, 30, 30, 99, 99, false)


func _enemy() -> Combatant:
	return Combatant.new("Star Trooper", 500, 0, 10, 5, 1, true, false, "enemy_star_trooper")


func test_a_fresh_combatant_may_use_anything() -> void:
	var rule := Liberty7Rule.new()
	var hero := _hero()
	assert_bool(rule.move_allowed(hero, Move.make_attack())).is_true()
	assert_bool(rule.move_allowed(hero, Move.make_defend())).is_true()


func test_the_command_just_used_is_refused_and_the_rest_allowed() -> void:
	var rule := Liberty7Rule.new()
	var hero := _hero()
	rule.on_action_resolved(hero, Move.make_attack())
	assert_bool(rule.move_allowed(hero, Move.make_attack())).is_false()
	assert_bool(rule.move_allowed(hero, Move.make_defend())).is_true()
	rule.on_action_resolved(hero, Move.make_defend())
	assert_bool(rule.move_allowed(hero, Move.make_defend())).is_false()
	assert_bool(rule.move_allowed(hero, Move.make_attack())).is_true()


func test_one_members_command_never_blocks_another() -> void:
	var rule := Liberty7Rule.new()
	var a := _hero("A")
	var b := _hero("B")
	rule.on_action_resolved(a, Move.make_attack())
	assert_bool(rule.move_allowed(b, Move.make_attack())).is_true()


func test_a_new_fight_forgets_the_last_command() -> void:
	var rule := Liberty7Rule.new()
	var hero := _hero()
	rule.on_action_resolved(hero, Move.make_attack())
	hero.reset_for_battle()
	assert_bool(rule.move_allowed(hero, Move.make_attack())).is_true()
	rule.on_action_resolved(hero, Move.make_attack())
	BattleCore.clear_transients([hero] as Array[Combatant])
	assert_bool(rule.move_allowed(hero, Move.make_attack())).is_true()


func test_battle_core_refuses_a_repeat_with_no_state_change() -> void:
	var rule := Liberty7Rule.new()
	var hero := _hero()
	var squad: Array[Combatant] = [hero]
	var enemies: Array[Combatant] = [_enemy()]
	var core := BattleCore.new(squad, enemies, null, rule)
	core.start_battle()
	assert_object(core.submit_action(Move.make_attack(), enemies[0])).is_not_null()
	# Round 2: the enemy phase ran; the hero's Attack is now a repeat.
	assert_int(core.round_number).is_equal(2)
	var hp_before: int = enemies[0].hp
	assert_object(core.submit_action(Move.make_attack(), enemies[0])).is_null()
	assert_int(enemies[0].hp).is_equal(hp_before)
	assert_object(core.submit_action(Move.make_defend())).is_not_null()


func test_the_refusal_note_names_the_member_and_command() -> void:
	var rule := Liberty7Rule.new()
	var hero := _hero("Karen")
	assert_str(rule.get_combatant_tooltip_note(hero)).is_empty()
	rule.on_action_resolved(hero, Move.make_attack())
	assert_str(rule.get_combatant_tooltip_note(hero)).contains("Karen").contains("Attack")


func test_enemies_alternate_their_two_moves() -> void:
	var rule := Liberty7Rule.new()
	var squad: Array[Combatant] = [_hero()]
	var trooper := _enemy()
	var odd: Array = rule.choose_enemy_action(trooper, squad, 1, RandomNumberGenerator.new())
	var even: Array = rule.choose_enemy_action(trooper, squad, 2, RandomNumberGenerator.new())
	assert_str((odd[0]["move"] as Move).display_name).is_equal("Marching Orders")
	assert_str((even[0]["move"] as Move).display_name).is_equal("Baton Twirl")


func test_the_boss_hits_everyone_on_odd_rounds_and_one_on_even() -> void:
	var rule := Liberty7Rule.new()
	var squad: Array[Combatant] = [_hero("A"), _hero("B"), _hero("C")]
	var boss := Combatant.new("Super Patriot", 300, 0, 20, 15, 10, true, true, "enemy_super_patriot")
	assert_int(rule.choose_enemy_action(boss, squad, 1, RandomNumberGenerator.new()).size()).is_equal(3)
	var solo: Array = rule.choose_enemy_action(boss, squad, 2, RandomNumberGenerator.new())
	assert_int(solo.size()).is_equal(1)
	assert_str((solo[0]["move"] as Move).display_name).is_equal("Anthem Solo")


func test_the_shipped_faction_builds_this_rule_with_its_texts() -> void:
	var rec: FactionRuleData = BattleCatalog.shipped().get_record(&"faction_rule", "rule_liberty7_freedom") as FactionRuleData
	assert_object(rec).is_not_null()
	assert_array(Liberty7RuleValidator.validate_record(rec)).is_empty()
	var rule: FactionRule = Liberty7RuleValidator.create(null, rec)
	assert_object(rule).is_instanceof(Liberty7Rule)
	assert_str(rule.get_banner_text(1)).contains("LIBERTY-7")
	assert_str(rule.get_identity_color().to_html(false)).is_equal("2f5bea")


func test_a_record_missing_a_text_is_an_error() -> void:
	var rec := FactionRuleData.new()
	var texts: Dictionary[String, String] = {"banner": "b", "tooltip": "t"}
	rec.texts = texts
	var errors: Array[Dictionary] = Liberty7RuleValidator.validate_record(rec)
	assert_int(errors.size()).is_equal(1)
	assert_str(String(errors[0]["field"])).is_equal("texts.note_repeat")
