## Items & Shops rules 8-9: the camp's shop sells its shelf from the wallet
## into the bag, refuses with a reason when it cannot, and one confirm on
## arrival still sets out (Set out stays first). Also the bag's save round
## trip through WorldState (rule 1).
extends GdUnitTestSuite

const CAMP_SCENE: String = "res://src/game_state/modes/interim_camp_mode.tscn"
const _PRICE: int = 8


class FakeCatalog extends RefCounted:
	var records: Dictionary = {}

	func get_record(_type: StringName, id: String) -> Resource:
		return records.get(id)


func _rec(id: String, price: int) -> ItemData:
	var rec := ItemData.new()
	rec.id = id
	rec.display_name = id.trim_prefix("item_").capitalize()
	rec.kind = "consumable"
	rec.effects = [{"type": "heal_hp", "amount": 25}]
	rec.price = price
	return rec


func _camp(money: int) -> InterimCampMode:
	var camp: InterimCampMode = auto_free((load(CAMP_SCENE) as PackedScene).instantiate())
	var catalog := FakeCatalog.new()
	catalog.records["item_croissant"] = _rec("item_croissant", _PRICE)
	var cfg := ShopConfig.new()
	cfg.stock_by_camp = {"camp_test": PackedStringArray(["item_croissant"])}
	camp.world_state = WorldState.new()
	camp.world_state.money = money
	camp.item_catalog = catalog
	camp.shop_config = cfg
	var payload := CampEntryPayload.new()
	payload.camp_id = "camp_test"
	camp.setup(null, payload)
	return camp


func test_set_out_is_first_and_shop_is_listed_when_the_camp_sells() -> void:
	var camp := _camp(0)
	assert_array(camp.rows()).is_equal([InterimCampMode.SET_OUT, InterimCampMode.SHOP])
	assert_int(camp.cursor).is_equal(0)


func test_buying_moves_money_into_the_bag() -> void:
	var camp := _camp(20)
	camp.handle_action(InputActions.NAV_DOWN, true)
	camp.handle_action(InputActions.CONFIRM, true)  # Shop
	assert_int(camp.screen).is_equal(InterimCampMode.Screen.SHOP)
	camp.handle_action(InputActions.CONFIRM, true)  # buy one
	camp.handle_action(InputActions.CONFIRM, true)  # buy another
	assert_int(camp.world_state.money).is_equal(20 - 2 * _PRICE)
	assert_int(camp.world_state.inventory.count("item_croissant")).is_equal(2)
	camp.handle_action(InputActions.CONFIRM, true)  # too poor now
	assert_int(camp.world_state.inventory.count("item_croissant")).is_equal(2)
	assert_str(camp.shop_message).contains("Not enough money")
	camp.handle_action(InputActions.CANCEL, true)
	assert_int(camp.screen).is_equal(InterimCampMode.Screen.MAIN)


func test_a_full_bag_refuses_and_keeps_the_money() -> void:
	var ws := WorldState.new()
	ws.money = 100
	ws.inventory.add("item_croissant", Inventory.MAX_PER_ITEM)
	assert_int(Shop.buy(ws, _rec("item_croissant", _PRICE))).is_equal(Shop.Result.BAG_FULL)
	assert_int(ws.money).is_equal(100)


func test_camp_with_no_shelf_offers_only_set_out() -> void:
	var camp: InterimCampMode = auto_free((load(CAMP_SCENE) as PackedScene).instantiate())
	camp.setup(null, null)
	assert_array(camp.rows()).is_equal([InterimCampMode.SET_OUT])


func test_bag_survives_world_state_save_round_trip_and_new_game_clears_it() -> void:
	var ws := WorldState.new()
	ws.inventory.add("item_espresso", 2)
	assert_dict(ws.to_dict()["items"]).is_equal({"item_espresso": 2})
	var loaded := WorldState.new()
	# from_dict() takes the participant's staged shape (Vector2s already built).
	loaded.from_dict({"items": ws.to_dict()["items"]})
	assert_int(loaded.inventory.count("item_espresso")).is_equal(2)
	loaded.reset_to_new_game()
	assert_array(loaded.inventory.ids()).is_empty()
