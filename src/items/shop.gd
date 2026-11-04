## Buying (Items & Shops rule 9): one item at a time, paid from the wallet
## into the bag. Pure: reads and writes only the `WorldState` it is given.
##
## Usage example:
## [codeblock]
## if Shop.buy(world_state, rec) == Shop.Result.OK:
##     print(world_state.money)
## [/codeblock]
class_name Shop
extends RefCounted

enum Result { OK, NOT_ENOUGH_MONEY, BAG_FULL, INVALID }


## What `rec` costs this squad: its record price after reputation
## (`Reputation.price_of`; narrative bible §6.3).
static func price(world_state: WorldState, rec: ItemData) -> int:
	return Reputation.price_of(rec.price, world_state)


## Why `rec` cannot be bought right now, or OK.
static func check(world_state: WorldState, rec: ItemData) -> Result:
	if world_state == null or rec == null or rec.price < 0:
		return Result.INVALID
	if world_state.inventory.is_full(rec.id):
		return Result.BAG_FULL
	if world_state.money < price(world_state, rec):
		return Result.NOT_ENOUGH_MONEY
	return Result.OK


## Buys one `rec`: takes its reputation price from the wallet and puts it
## in the bag. Changes nothing unless the result is OK.
static func buy(world_state: WorldState, rec: ItemData) -> Result:
	var result: Result = check(world_state, rec)
	if result != Result.OK:
		return result
	world_state.money -= price(world_state, rec)
	world_state.inventory.add(rec.id)
	return Result.OK


## The player-facing reason for a refused purchase ("" for OK).
static func reason(result: Result) -> String:
	match result:
		Result.NOT_ENOUGH_MONEY:
			return "Not enough money"
		Result.BAG_FULL:
			return "Bag full"
		Result.INVALID:
			return "Not for sale"
	return ""
