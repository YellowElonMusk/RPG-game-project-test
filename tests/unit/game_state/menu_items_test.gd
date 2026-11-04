## Items & Shops OQ-2: the Overworld Menu's Items screen uses an item on a
## squad member outside battle, through the same effects battle uses; the
## payload's entry list is unchanged (AC-31), and a Menu without the bag
## wired (Battle) has no Items entry.
extends GdUnitTestSuite


class FakeCatalog extends RefCounted:
	var records: Dictionary = {}

	func get_record(_type: StringName, id: String) -> Resource:
		return records.get(id)


func _croissant() -> ItemData:
	var rec := ItemData.new()
	rec.id = "item_croissant"
	rec.display_name = "Croissant"
	rec.kind = "consumable"
	rec.effects = [{"type": "heal_hp", "amount": 25}]
	rec.price = 8
	return rec


func _menu(with_bag: bool, party: Array[Combatant]) -> InterimMenu:
	var menu := InterimMenu.new()
	if with_bag:
		var catalog := FakeCatalog.new()
		catalog.records["item_croissant"] = _croissant()
		menu.world_state = WorldState.new()
		menu.world_state.inventory.add("item_croissant", 2)
		menu.item_catalog = catalog
		menu.party = party
	var payload := MenuPayload.new()
	payload.entries = [&"pause", &"party", &"quit"]
	menu.setup(null, payload)
	add_child(menu)
	return auto_free(menu)


func test_items_entry_sits_under_resume_and_entries_stay_the_payload() -> void:
	var party: Array[Combatant] = [Combatant.new("Karen", 34, 12, 10, 6, 10, false)]
	var menu := _menu(true, party)
	assert_array(menu.entries()).is_equal([&"pause", &"party", &"quit"])
	assert_object(menu.button_for(&"items")).is_not_null()


func test_no_items_entry_without_the_bag() -> void:
	var menu := _menu(false, [])
	assert_object(menu.button_for(&"items")).is_null()


func test_using_a_croissant_heals_and_spends_one() -> void:
	var karen := Combatant.new("Karen", 34, 12, 10, 6, 10, false)
	karen.hp = 5
	var party: Array[Combatant] = [karen]
	var menu := _menu(true, party)
	menu.button_for(&"items").emit_signal(&"pressed")
	var item_button: Button = _first_enabled(menu)
	assert_str(item_button.text).starts_with("Croissant x2")
	item_button.emit_signal(&"pressed")
	_first_enabled(menu).emit_signal(&"pressed")  # Karen
	assert_int(karen.hp).is_equal(30)
	assert_int(menu.world_state.inventory.count("item_croissant")).is_equal(1)


func test_an_item_no_one_needs_is_disabled() -> void:
	var party: Array[Combatant] = [Combatant.new("Karen", 34, 12, 10, 6, 10, false)]
	var menu := _menu(true, party)
	menu.button_for(&"items").emit_signal(&"pressed")
	assert_object(_first_enabled(menu)).is_null()


func test_party_screen_equips_gear_from_the_bag() -> void:
	var karen := Combatant.new("Karen", 34, 12, 10, 6, 10, false, false, "char_karen")
	var party: Array[Combatant] = [karen]
	var menu := _menu(true, party)
	var coat := ItemData.new()
	coat.id = "item_coat"
	coat.display_name = "Trench Coat"
	coat.kind = "equipment"
	coat.effects = [{"type": "equip", "slot": "outfit", "attack": 0, "defense": 3, "user": ""}]
	(menu.item_catalog as FakeCatalog).records["item_coat"] = coat
	menu.world_state.inventory.add("item_coat")
	var party_button: Button = menu.button_for(&"party")
	assert_bool(party_button.disabled).is_false()
	party_button.emit_signal(&"pressed")
	_first_enabled(menu).emit_signal(&"pressed")  # Karen
	_button_starting(menu, "Outfit").emit_signal(&"pressed")
	_button_starting(menu, "Trench Coat").emit_signal(&"pressed")
	assert_str(String(karen.equipment.get(&"outfit", ""))).is_equal("item_coat")
	assert_int(karen.effective_defense()).is_equal(9)
	assert_int(menu.world_state.inventory.count("item_coat")).is_equal(0)


func _button_starting(node: Node, prefix: String) -> Button:
	for child: Node in node.find_children("*", "Button", true, false):
		var b: Button = child as Button
		if b.text.begins_with(prefix) and not b.is_queued_for_deletion():
			return b
	return null


func _first_enabled(node: Node) -> Button:
	for child: Node in node.find_children("*", "Button", true, false):
		var b: Button = child as Button
		if not b.disabled and not b.is_queued_for_deletion():
			return b
	return null
