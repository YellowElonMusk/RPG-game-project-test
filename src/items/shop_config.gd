## What each camp's shop sells (Items & Shops rule 8; tuning data, read from
## `data/config/shop_config.tres`). Ids are `item_` records; prices live on
## the records themselves.
class_name ShopConfig
extends Resource

const PATH: String = "res://data/config/shop_config.tres"

## camp_id -> PackedStringArray of item ids, in shelf order.
@export var stock_by_camp: Dictionary = {}
## What a camp with no entry in `stock_by_camp` sells (empty = no shop).
@export var default_stock: PackedStringArray = PackedStringArray()


## The shelf for `camp_id`.
func stock_for(camp_id: String) -> PackedStringArray:
	return PackedStringArray(stock_by_camp.get(camp_id, default_stock))


## The shipped config, or an empty one (no shops) when it is missing.
static func load_default() -> ShopConfig:
	if ResourceLoader.exists(PATH):
		var cfg := load(PATH) as ShopConfig
		if cfg != null:
			return cfg
	return ShopConfig.new()
