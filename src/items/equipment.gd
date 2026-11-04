## Gear (Items & Shops rules 10-12): an `equipment` item fills one slot of
## one squad member and adds flat attack/defense on top of the levelled
## stats. Equipping takes it out of the bag; taking it off puts it back.
##
## An equipment record's first `effects` entry is
## `{"type": "equip", "slot": "weapon"|"outfit", "attack": N, "defense": N,
## "user": "<char_ id>"}`; an empty or missing `user` fits anyone.
##
## Usage example:
## [codeblock]
## var rec: ItemData = catalog.get_record(&"item", "item_cast_iron_ladle")
## if Equipment.equip(chef, rec, world_state.inventory, catalog):
##     print(chef.effective_attack())
## [/codeblock]
class_name Equipment
extends RefCounted

const SLOTS: Array[StringName] = [&"weapon", &"outfit"]
const SLOT_NAMES: Dictionary = {&"weapon": "Weapon", &"outfit": "Outfit"}


## The `equip` descriptor of `rec`, or {} when `rec` is not equipment.
static func spec(rec: ItemData) -> Dictionary:
	if rec == null or rec.kind != "equipment" or rec.effects.is_empty():
		return {}
	var e: Dictionary = rec.effects[0]
	if String(e.get("type", "")) != "equip" or not SLOTS.has(StringName(String(e.get("slot", "")))):
		return {}
	return e


## The slot `rec` fills (&"" when not equipment).
static func slot_of(rec: ItemData) -> StringName:
	var e: Dictionary = spec(rec)
	return StringName(String(e.get("slot", ""))) if not e.is_empty() else &""


## Rule 10: `true` when `member` may wear `rec` (its `user`, or anyone).
static func fits(member: Combatant, rec: ItemData) -> bool:
	var e: Dictionary = spec(rec)
	if e.is_empty() or member == null or member.is_enemy:
		return false
	var user: String = String(e.get("user", ""))
	return user.is_empty() or user == member.record_id


## Rule 11: puts `rec` on `member` from the bag, returning whatever was in
## that slot to the bag first. False (nothing changes) when it does not fit,
## is not in the bag, or the old item cannot go back (its stack is full).
static func equip(member: Combatant, rec: ItemData, bag: Inventory, catalog: Object) -> bool:
	if not fits(member, rec) or bag.count(rec.id) <= 0:
		return false
	var slot: StringName = slot_of(rec)
	var old: String = String(member.equipment.get(slot, ""))
	if not old.is_empty() and bag.is_full(old):
		return false
	bag.remove(rec.id)
	if not old.is_empty():
		bag.add(old)
	member.equipment[slot] = rec.id
	refresh_bonuses(member, catalog)
	return true


## Takes `slot` off `member` into the bag. False when the slot is empty or
## the bag's stack of that item is full.
static func unequip(member: Combatant, slot: StringName, bag: Inventory, catalog: Object) -> bool:
	var old: String = String(member.equipment.get(slot, ""))
	if old.is_empty() or bag.is_full(old):
		return false
	bag.add(old)
	member.equipment.erase(slot)
	refresh_bonuses(member, catalog)
	return true


## Rule 12: recomputes `member.bonus_attack`/`bonus_defense` from what it
## wears. An id with no record (content removed) gives nothing.
static func refresh_bonuses(member: Combatant, catalog: Object) -> void:
	var atk: int = 0
	var def: int = 0
	for slot: Variant in member.equipment:
		var rec: ItemData = catalog.call(&"get_record", &"item", String(member.equipment[slot])) as ItemData if catalog != null else null
		var e: Dictionary = spec(rec)
		atk += int(e.get("attack", 0))
		def += int(e.get("defense", 0))
	member.bonus_attack = atk
	member.bonus_defense = def


## A short bonus label for menus and the shop: "ATK +4", "DEF +3".
static func bonus_text(rec: ItemData) -> String:
	var e: Dictionary = spec(rec)
	var parts: PackedStringArray = []
	if int(e.get("attack", 0)) != 0:
		parts.append("ATK %+d" % int(e.get("attack", 0)))
	if int(e.get("defense", 0)) != 0:
		parts.append("DEF %+d" % int(e.get("defense", 0)))
	return " ".join(parts)
