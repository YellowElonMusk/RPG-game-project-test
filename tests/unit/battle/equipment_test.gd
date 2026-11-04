## Items & Shops rules 10-12: gear fits its user (or anyone), moves between
## the bag and a slot, adds flat bonuses on top of the levelled stats that
## the damage formula reads, and survives a squad save round trip.
extends GdUnitTestSuite

const _ATK: int = 4
const _DEF: int = 3


class FakeCatalog extends RefCounted:
	var records: Dictionary = {}

	func get_record(_type: StringName, id: String) -> Resource:
		return records.get(id)


func _gear(id: String, slot: String, atk: int, def: int, user: String = "") -> ItemData:
	var rec := ItemData.new()
	rec.id = id
	rec.display_name = id
	rec.kind = "equipment"
	rec.effects = [{"type": "equip", "slot": slot, "attack": atk, "defense": def, "user": user}]
	return rec


func _catalog() -> FakeCatalog:
	var c := FakeCatalog.new()
	c.records["item_ladle"] = _gear("item_ladle", "weapon", _ATK, 0, "char_chef")
	c.records["item_coat"] = _gear("item_coat", "outfit", 0, _DEF)
	c.records["item_beret"] = _gear("item_beret", "outfit", 0, 2)
	return c


func _chef() -> Combatant:
	return Combatant.new("Chef", 30, 14, 9, 6, 8, false, false, "char_chef")


func test_weapon_fits_only_its_user_and_outfits_fit_anyone() -> void:
	var cat := _catalog()
	var karen := Combatant.new("Karen", 34, 12, 10, 6, 10, false, false, "char_karen")
	assert_bool(Equipment.fits(_chef(), cat.records["item_ladle"])).is_true()
	assert_bool(Equipment.fits(karen, cat.records["item_ladle"])).is_false()
	assert_bool(Equipment.fits(karen, cat.records["item_coat"])).is_true()


func test_equip_moves_bag_to_slot_and_adds_bonuses() -> void:
	var cat := _catalog()
	var chef := _chef()
	var bag := Inventory.new()
	bag.add("item_ladle")
	bag.add("item_coat")
	assert_bool(Equipment.equip(chef, cat.records["item_ladle"], bag, cat)).is_true()
	assert_bool(Equipment.equip(chef, cat.records["item_coat"], bag, cat)).is_true()
	assert_int(bag.count("item_ladle")).is_equal(0)
	assert_int(chef.effective_attack()).is_equal(9 + _ATK)
	assert_int(chef.effective_defense()).is_equal(6 + _DEF)
	assert_int(chef.attack).is_equal(9)  # the levelled base is untouched


func test_swapping_returns_the_old_item_and_take_off_empties_the_slot() -> void:
	var cat := _catalog()
	var chef := _chef()
	var bag := Inventory.new()
	bag.add("item_coat")
	bag.add("item_beret")
	Equipment.equip(chef, cat.records["item_coat"], bag, cat)
	Equipment.equip(chef, cat.records["item_beret"], bag, cat)
	assert_int(bag.count("item_coat")).is_equal(1)
	assert_int(chef.bonus_defense).is_equal(2)
	assert_bool(Equipment.unequip(chef, &"outfit", bag, cat)).is_true()
	assert_int(chef.bonus_defense).is_equal(0)
	assert_int(bag.count("item_beret")).is_equal(1)


func test_cannot_equip_what_the_bag_does_not_hold_or_what_does_not_fit() -> void:
	var cat := _catalog()
	var karen := Combatant.new("Karen", 34, 12, 10, 6, 10, false, false, "char_karen")
	var bag := Inventory.new()
	assert_bool(Equipment.equip(_chef(), cat.records["item_ladle"], bag, cat)).is_false()
	bag.add("item_ladle")
	assert_bool(Equipment.equip(karen, cat.records["item_ladle"], bag, cat)).is_false()
	assert_int(bag.count("item_ladle")).is_equal(1)


func test_damage_formula_reads_gear() -> void:
	var cat := _catalog()
	var chef := _chef()
	var clerk := Combatant.new("Clerk", 28, 0, 9, 5, 8, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bare: int = DamageCalculator.calculate_damage(chef, clerk, 10, rng)
	var bag := Inventory.new()
	bag.add("item_ladle")
	Equipment.equip(chef, cat.records["item_ladle"], bag, cat)
	rng.seed = 7
	assert_int(DamageCalculator.calculate_damage(chef, clerk, 10, rng)).is_greater(bare)


func test_bonus_text() -> void:
	assert_str(Equipment.bonus_text(_gear("x", "weapon", _ATK, 0))).is_equal("ATK +4")
	assert_str(Equipment.bonus_text(_gear("y", "outfit", 0, _DEF))).is_equal("DEF +3")
