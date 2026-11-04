## Items & Shops GDD: the bag (rules 1-2), item effects (rule 5, F1-F2),
## battle use (rules 4 and 6: allowed under a Special ban, spent only when it
## does something) and the Retry refund (rule 7).
extends GdUnitTestSuite

const _HEAL_AMOUNT: int = 25
const _MP_AMOUNT: int = 10
const _REVIVE_PCT: int = 50


func _rec(id: String, type: String, amount: int, kind: String = "consumable") -> ItemData:
	var rec := ItemData.new()
	rec.id = id
	rec.display_name = id.trim_prefix("item_").capitalize()
	rec.kind = kind
	rec.effects = [{"type": type, "amount": amount}]
	rec.price = 10
	return rec


func _member(name: String) -> Combatant:
	return Combatant.new(name, 40, 12, 10, 6, 10, false)


func _battle(squad: Array[Combatant], rule: FactionRule = null) -> BattleCore:
	var enemies: Array[Combatant] = [Combatant.new("Clerk", 28, 0, 9, 5, 8, true)]
	var battle := BattleCore.new(squad, enemies, RandomNumberGenerator.new(), rule)
	battle.inventory = Inventory.new()
	battle.start_battle(false)
	return battle


# --- the bag ---

func test_bag_caps_each_item_and_reports_what_it_added() -> void:
	var bag := Inventory.new()
	assert_int(bag.add("item_croissant", 5)).is_equal(5)
	assert_int(bag.add("item_croissant", 9)).is_equal(Inventory.MAX_PER_ITEM - 5)
	assert_bool(bag.is_full("item_croissant")).is_true()
	assert_int(bag.add("item_croissant")).is_equal(0)


func test_bag_remove_erases_at_zero_and_refuses_when_empty() -> void:
	var bag := Inventory.new()
	bag.add("item_espresso")
	assert_bool(bag.remove("item_espresso")).is_true()
	assert_array(bag.ids()).is_empty()
	assert_bool(bag.remove("item_espresso")).is_false()


func test_bag_round_trips_and_drops_bad_counts() -> void:
	var bag := Inventory.new()
	bag.from_dict({"item_a": 3, "item_b": 0, "item_c": -2, "item_d": 40})
	assert_dict(bag.to_dict()).is_equal({"item_a": 3, "item_d": Inventory.MAX_PER_ITEM})


# --- records -> moves, effects ---

func test_move_for_maps_types_to_effects_and_targets() -> void:
	var heal: Move = ItemEffects.move_for(_rec("item_croissant", "heal_hp", _HEAL_AMOUNT))
	assert_int(heal.category).is_equal(Move.Category.ITEM)
	assert_int(heal.item_effect).is_equal(Move.ItemEffect.HEAL_HP)
	assert_int(heal.target_type).is_equal(Move.TargetType.SINGLE_ALLY)
	assert_int(heal.power).is_equal(_HEAL_AMOUNT)
	assert_int(heal.mp_cost).is_equal(0)
	assert_str(heal.item_id).is_equal("item_croissant")
	assert_int(ItemEffects.move_for(_rec("item_x", "revive", _REVIVE_PCT)).target_type).is_equal(Move.TargetType.SINGLE_KO_ALLY)
	assert_int(ItemEffects.move_for(_rec("item_y", "heal_party", 20)).target_type).is_equal(Move.TargetType.SELF)


func test_move_for_rejects_non_consumables_and_unknown_types() -> void:
	assert_object(ItemEffects.move_for(_rec("item_key", "heal_hp", 5, "key"))).is_null()
	assert_object(ItemEffects.move_for(_rec("item_odd", "teleport", 5))).is_null()
	assert_object(ItemEffects.move_for(null)).is_null()


func test_revive_hp_is_half_rounded_down_and_never_zero() -> void:
	assert_int(ItemEffects.revive_hp(31, _REVIVE_PCT)).is_equal(15)
	assert_int(ItemEffects.revive_hp(1, _REVIVE_PCT)).is_equal(1)


# --- battle use ---

func test_item_works_while_specials_are_banned_and_is_spent() -> void:
	var a := _member("A")
	var b := _member("B")
	var squad: Array[Combatant] = [a, b]
	var battle := _battle(squad, BureaucratiaRule.new())
	assert_bool(battle.faction_rule.specials_allowed(battle.round_number)).is_false()
	a.hp = 10
	battle.inventory.add("item_croissant", 2)
	var outcome := battle.submit_action(ItemEffects.move_for(_rec("item_croissant", "heal_hp", _HEAL_AMOUNT)), a)
	assert_object(outcome).is_not_null()
	assert_int(outcome.hp_delta).is_equal(_HEAL_AMOUNT)
	assert_int(a.hp).is_equal(10 + _HEAL_AMOUNT)
	assert_int(battle.inventory.count("item_croissant")).is_equal(1)


func test_item_that_would_do_nothing_is_refused_and_kept() -> void:
	var a := _member("A")
	var squad: Array[Combatant] = [a]
	var battle := _battle(squad)
	battle.inventory.add("item_croissant")
	var move: Move = ItemEffects.move_for(_rec("item_croissant", "heal_hp", _HEAL_AMOUNT))
	assert_bool(battle.item_usable(move, a)).is_false()  # already at full HP
	assert_object(battle.submit_action(move, a)).is_null()
	assert_int(battle.inventory.count("item_croissant")).is_equal(1)
	assert_object(battle.get_active_combatant()).is_same(a)


func test_item_not_in_the_bag_is_refused() -> void:
	var a := _member("A")
	var squad: Array[Combatant] = [a]
	var battle := _battle(squad)
	a.hp = 5
	assert_object(battle.submit_action(ItemEffects.move_for(_rec("item_croissant", "heal_hp", _HEAL_AMOUNT)), a)).is_null()
	assert_int(a.hp).is_equal(5)


func test_revive_targets_only_the_knocked_out() -> void:
	var a := _member("A")
	var b := _member("B")
	var squad: Array[Combatant] = [a, b]
	var battle := _battle(squad)
	b.hp = 0
	battle.inventory.add("item_cheese")
	var revive: Move = ItemEffects.move_for(_rec("item_cheese", "revive", _REVIVE_PCT))
	assert_bool(battle.item_usable(revive, a)).is_false()
	var outcome := battle.submit_action(revive, b)
	assert_object(outcome).is_not_null()
	assert_int(b.hp).is_equal(ItemEffects.revive_hp(b.max_hp, _REVIVE_PCT))
	assert_int(battle.inventory.count("item_cheese")).is_equal(0)


func test_mp_item_restores_mp_up_to_max() -> void:
	var a := _member("A")
	var squad: Array[Combatant] = [a]
	var battle := _battle(squad)
	a.mp = 8
	battle.inventory.add("item_espresso")
	battle.submit_action(ItemEffects.move_for(_rec("item_espresso", "restore_mp", _MP_AMOUNT)), a)
	assert_int(a.mp).is_equal(a.max_mp)


func test_party_item_heals_every_living_member_but_not_the_knocked_out() -> void:
	var a := _member("A")
	var b := _member("B")
	var c := _member("C")
	var squad: Array[Combatant] = [a, b, c]
	var battle := _battle(squad)
	a.hp = 10
	b.hp = 30
	c.hp = 0
	battle.inventory.add("item_basket")
	var outcome := battle.submit_action(ItemEffects.move_for(_rec("item_basket", "heal_party", 20)), null)
	assert_int(a.hp).is_equal(30)
	assert_int(b.hp).is_equal(b.max_hp)
	assert_int(c.hp).is_equal(0)
	assert_int(outcome.hp_delta).is_equal(20 + 10)


func test_retry_snapshot_gives_back_items_used_in_the_lost_attempt() -> void:
	var a := _member("A")
	var party: Array[Combatant] = [a]
	var bag := Inventory.new()
	bag.add("item_croissant", 3)
	var snapshot := BattleStartSnapshot.capture(party, bag)
	bag.remove("item_croissant")
	bag.remove("item_croissant")
	snapshot.restore_into(party, bag)
	assert_int(bag.count("item_croissant")).is_equal(3)
