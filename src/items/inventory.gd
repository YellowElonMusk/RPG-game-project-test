## The squad's bag (Items & Shops GDD rules 1-2): how many of each `item_`
## record the squad carries, capped at `max_per_item`. Ids only; the records
## live in the content catalog. Owned by `WorldState` and saved with it.
##
## Usage example:
## [codeblock]
## var bag := Inventory.new()
## bag.add("item_croissant", 2)
## if bag.remove("item_croissant"):
##     print(bag.count("item_croissant"))  # 1
## [/codeblock]
class_name Inventory
extends RefCounted

## Rule 2: the most of one item the bag holds (tuning knob).
const MAX_PER_ITEM: int = 9

## The cap this bag applies; `MAX_PER_ITEM` unless a test injects another.
var max_per_item: int = MAX_PER_ITEM
# item id -> count (always >= 1; an item at 0 is erased).
var _counts: Dictionary = {}


## How many of `item_id` the bag holds.
func count(item_id: String) -> int:
	return int(_counts.get(item_id, 0))


## Adds up to `n` of `item_id`, stopping at the cap. Returns how many were
## actually added (0 when already full).
func add(item_id: String, n: int = 1) -> int:
	if item_id.is_empty() or n <= 0:
		return 0
	var added: int = mini(n, max_per_item - count(item_id))
	if added <= 0:
		return 0
	_counts[item_id] = count(item_id) + added
	return added


## Removes one `item_id`. Returns false (and changes nothing) when there is none.
func remove(item_id: String) -> bool:
	var have: int = count(item_id)
	if have <= 0:
		return false
	if have == 1:
		_counts.erase(item_id)
	else:
		_counts[item_id] = have - 1
	return true


## `true` when one more `item_id` would go over the cap.
func is_full(item_id: String) -> bool:
	return count(item_id) >= max_per_item


## The held item ids, sorted (a stable menu order).
func ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in _counts.keys():
		out.append(id)
	out.sort()
	return out


## Empties the bag (New Game).
func clear() -> void:
	_counts = {}


## A copy of the counts, id -> count (saving, battle Retry snapshots).
func to_dict() -> Dictionary:
	return _counts.duplicate()


## Replaces the counts from `to_dict()` output: non-positive counts are
## dropped and each count is clamped to the cap.
func from_dict(data: Dictionary) -> void:
	_counts = {}
	for id: Variant in data:
		var n: int = int(data[id])
		if id is String and not (id as String).is_empty() and n > 0:
			_counts[id] = mini(n, max_per_item)
