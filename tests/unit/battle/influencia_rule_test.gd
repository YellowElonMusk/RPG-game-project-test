## Chapter 3 (Influencia, Sydney): the attention-economy rule. A hit gives
## an Influencia enemy a Follower (+follower_attack ATK each, capped at
## max_followers); an enemy nobody hit all round loses one; the squad never
## gains any; Retry clears them; the card badge and texts come from the rule.
extends GdUnitTestSuite

const _FOLLOWER_ATK: int = 2
const _MAX: int = 5


func before() -> void:
	BattleContentSeam.ensure_catalog()


func _rule() -> InfluenciaRule:
	var rule := InfluenciaRule.new()
	rule.configure({"follower_attack": _FOLLOWER_ATK, "max_followers": _MAX})
	return rule


func _enemy(name: String = "Ring Light", attack: int = 10) -> Combatant:
	return Combatant.new(name, 500, 0, attack, 5, 1, true, false, "enemy_ring_light")


func _hero() -> Combatant:
	return Combatant.new("Hero", 999, 10, 30, 99, 99, false)


func test_a_hit_gives_one_follower_and_its_attack() -> void:
	var rule := _rule()
	var e := _enemy()
	rule.on_damage_taken(e, _hero(), 7)
	assert_int(e.rule_stacks).is_equal(1)
	assert_int(e.effective_attack()).is_equal(10 + _FOLLOWER_ATK)
	assert_bool(e.hit_this_round).is_true()


func test_followers_cap_at_max() -> void:
	var rule := _rule()
	var e := _enemy()
	for i: int in _MAX + 3:
		rule.on_damage_taken(e, _hero(), 1)
	assert_int(e.rule_stacks).is_equal(_MAX)
	assert_int(e.rule_attack_bonus).is_equal(_MAX * _FOLLOWER_ATK)


func test_the_squad_never_gains_followers() -> void:
	var rule := _rule()
	var hero := _hero()
	rule.on_damage_taken(hero, _enemy(), 9)
	assert_int(hero.rule_stacks).is_equal(0)
	assert_int(hero.effective_attack()).is_equal(30)


func test_an_ignored_enemy_loses_a_follower_and_a_hit_one_keeps_its_own() -> void:
	var rule := _rule()
	var hit := _enemy("A")
	var ignored := _enemy("B")
	rule.on_damage_taken(ignored, _hero(), 1)
	rule.on_damage_taken(ignored, _hero(), 1)
	rule.on_round_end([hit, ignored] as Array[Combatant])
	# Round 1: both were hit (B twice), so nobody decays; marks clear.
	assert_int(ignored.rule_stacks).is_equal(2)
	rule.on_damage_taken(hit, _hero(), 1)
	rule.on_round_end([hit, ignored] as Array[Combatant])
	assert_int(hit.rule_stacks).is_equal(1)
	assert_int(ignored.rule_stacks).is_equal(1)
	assert_int(ignored.effective_attack()).is_equal(10 + _FOLLOWER_ATK)
	assert_bool(hit.hit_this_round).is_false()


func test_decay_stops_at_zero() -> void:
	var rule := _rule()
	var e := _enemy()
	rule.on_round_end([e] as Array[Combatant])
	assert_int(e.rule_stacks).is_equal(0)
	assert_int(e.rule_attack_bonus).is_equal(0)


func test_battle_core_feeds_the_hit_enemy_and_starves_the_other() -> void:
	var rule := _rule()
	var hero := _hero()
	var target := _enemy("A")
	var other := _enemy("B")
	var core := BattleCore.new([hero] as Array[Combatant], [target, other] as Array[Combatant],
			RandomNumberGenerator.new(), rule)
	core.start_battle()
	rule.on_damage_taken(other, hero, 1)
	rule.on_damage_taken(other, hero, 1)
	other.hit_this_round = false
	core.submit_action(Move.make_attack(), target)
	# The single hero's turn ends the round: both enemies act, then upkeep.
	assert_int(core.round_number).is_equal(2)
	assert_int(target.rule_stacks).is_equal(1)
	assert_int(other.rule_stacks).is_equal(1)


func test_retry_clears_followers() -> void:
	var rule := _rule()
	var e := _enemy()
	rule.on_damage_taken(e, _hero(), 1)
	e.reset_for_battle()
	assert_int(e.rule_stacks).is_equal(0)
	assert_int(e.effective_attack()).is_equal(10)
	assert_bool(e.hit_this_round).is_false()


func test_badge_and_texts_name_the_numbers() -> void:
	var rule := _rule()
	assert_str(rule.get_stack_badge(0)).is_empty()
	assert_str(rule.get_stack_badge(3)).is_equal("Followers 3")
	assert_str(rule.get_banner_text(1)).contains("+2 ATK").contains("up to 5")
	var e := _enemy()
	rule.on_damage_taken(e, _hero(), 1)
	assert_str(rule.get_combatant_tooltip_note(e)).is_equal("1 Followers: +2 ATK.")


func test_the_shipped_record_validates_and_configures_the_rule() -> void:
	var record := load("res://data/faction_rules/rule_influencia_followers.tres") as FactionRuleData
	assert_array(InfluenciaRuleValidator.validate_record(record)).is_empty()
	var rule := InfluenciaRuleValidator.create(null, record) as InfluenciaRule
	assert_int(rule.follower_attack).is_equal(_FOLLOWER_ATK)
	assert_int(rule.max_followers).is_equal(_MAX)


func test_a_record_missing_params_is_rejected() -> void:
	var record := FactionRuleData.new()
	record.params = {"follower_attack": 2}
	var errors := InfluenciaRuleValidator.validate_record(record)
	var fields: PackedStringArray = []
	for e: Dictionary in errors:
		fields.append(String(e["field"]))
	assert_bool(fields.has("params.max_followers")).is_true()
	assert_bool(fields.has("texts.banner")).is_true()


func test_the_factory_builds_influencia_for_its_faction() -> void:
	var payload := BattleEntryPayload.new()
	var enc := load("res://data/encounters/enc_sydney_fans_west.tres") as EncounterData
	payload.descriptor = OverworldMode.build_descriptor(enc)
	payload.party = [_hero()] as Array[Combatant]
	var result := BattleFactory.build(payload, RandomNumberGenerator.new())
	assert_array(result.errors).is_empty()
	assert_bool(result.core.faction_rule is InfluenciaRule).is_true()
	assert_int(result.core.enemies.size()).is_equal(3)
