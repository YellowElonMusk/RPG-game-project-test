## The squad's live members and any loaded-but-not-yet-applied save data
## (Leveling GDD rule 7). `GameRoot` owns one; the Overworld, Camp and the
## `squad` save participant share it, so a save always sees the same
## `Combatant`s the battles changed in place (ADR-0002 §7).
##
## The roster can outgrow a battle party (design/narrative/recruits.md): the
## first `ACTIVE_SIZE` members fight, the rest wait on the bench. The Menu's
## Party screen reorders `squad` with `swap()`.
class_name SquadStore
extends RefCounted

## How many members fight; the rest are the bench.
const ACTIVE_SIZE: int = 4

## The live roster in party order (active first, then the bench), or empty
## until the next Overworld entry builds it.
var squad: Array[Combatant] = []
## A committed save's members, `{char_id: {level, xp, hp, mp}}`, applied by
## the next build; empty otherwise.
var pending: Dictionary = {}
## A committed save's roster order (character ids), applied by the next
## build; empty otherwise.
var pending_order: PackedStringArray = PackedStringArray()


## Builds the squad from `catalog`: the starting members plus every
## recruit `pending` names (level 1, full HP/MP), then applies and clears
## `pending`: each saved member's level (stats rebuilt from its record), XP,
## HP, MP and equipment, and the saved order.
func rebuild(catalog: ContentCatalogService) -> Array[Combatant]:
	squad = ChapterFlow.build_squad(catalog)
	var extra: Array = pending.keys()
	extra.sort()
	for id: Variant in extra:
		if not has_member(String(id)):
			var rec: CharacterData = catalog.get_record(&"character", String(id)) as CharacterData
			if rec != null:
				squad.append(ChapterFlow.make_member(rec))
	for member: Combatant in squad:
		var saved: Dictionary = pending.get(member.record_id, {})
		if saved.is_empty():
			continue
		Leveling.apply_level(member, int(saved.get("level", 1)), catalog)
		member.xp = maxi(0, int(saved.get("xp", 0)))
		member.hp = clampi(int(saved.get("hp", member.max_hp)), 0, member.max_hp)
		member.mp = clampi(int(saved.get("mp", member.max_mp)), 0, member.max_mp)
		var gear: Dictionary = saved.get("equipment", {})
		for slot: String in gear:
			member.equipment[StringName(slot)] = String(gear[slot])
		Equipment.refresh_bonuses(member, catalog)
	_apply_order(pending_order)
	pending = {}
	pending_order = PackedStringArray()
	return squad


## The members who fight: the first `ACTIVE_SIZE` of `squad`.
func active_party() -> Array[Combatant]:
	var out: Array[Combatant] = []
	for i: int in mini(ACTIVE_SIZE, squad.size()):
		out.append(squad[i])
	return out


## The members waiting on the bench (everyone after the active party).
func bench() -> Array[Combatant]:
	var out: Array[Combatant] = []
	for i: int in range(ACTIVE_SIZE, squad.size()):
		out.append(squad[i])
	return out


## `true` when a member built from `char_id` is in the roster.
func has_member(char_id: String) -> bool:
	for m: Combatant in squad:
		if m.record_id == char_id:
			return true
	return false


## Adds `char_id` to the roster (on the bench when the party is full, else
## into the party). A recruit joins at the squad's average level, rounded
## down, with that level's XP and full HP/MP, so a late join can still
## fight. Returns the new member, or null when it is unknown or already in.
func recruit(char_id: String, catalog: ContentCatalogService) -> Combatant:
	if has_member(char_id) or catalog == null:
		return null
	var rec: CharacterData = catalog.get_record(&"character", char_id) as CharacterData
	if rec == null:
		return null
	var level: int = average_level()
	var member: Combatant = ChapterFlow.make_member(rec)
	if level > 1:
		Leveling.apply_level(member, level, catalog)
		member.xp = Leveling.xp_total(level)
	member.hp = member.max_hp
	member.mp = member.max_mp
	squad.append(member)
	return member


## Recruits every character whose `joins_on_flag` is set in `world_state`
## and who is not in yet, in id order. Returns who joined (empty = nobody).
func sync_recruits(world_state: WorldState, catalog: ContentCatalogService) -> Array[Combatant]:
	var joined: Array[Combatant] = []
	if world_state == null or catalog == null:
		return joined
	var ids: Array[String] = []
	for rec: CharacterData in catalog.all_records(&"character"):
		if not rec.joins_on_flag.is_empty() and world_state.has_flag(rec.joins_on_flag) and not has_member(rec.id):
			ids.append(rec.id)
	ids.sort()
	for id: String in ids:
		var member: Combatant = recruit(id, catalog)
		if member != null:
			joined.append(member)
	return joined


## The squad's mean level, rounded down (1 for an empty squad).
func average_level() -> int:
	if squad.is_empty():
		return 1
	var total: int = 0
	for m: Combatant in squad:
		total += m.level
	return maxi(1, floori(float(total) / squad.size()))


## Swaps the members at roster positions `a` and `b` (the Party screen's
## party/bench swap). Out-of-range indices do nothing. Returns `true` on a
## swap.
func swap(a: int, b: int) -> bool:
	return swap_in(squad, a, b)


## `swap()` on any roster array (the Menu holds the same array by reference).
static func swap_in(roster: Array[Combatant], a: int, b: int) -> bool:
	if a == b or a < 0 or b < 0 or a >= roster.size() or b >= roster.size():
		return false
	var tmp: Combatant = roster[a]
	roster[a] = roster[b]
	roster[b] = tmp
	return true


## The roster's character ids in order (the save's `order`).
func order() -> PackedStringArray:
	var out := PackedStringArray()
	for m: Combatant in squad:
		out.append(m.record_id)
	return out


# Reorders `squad` in place so the ids in `ids` come first, in that order;
# members it does not name keep their relative order after them.
func _apply_order(ids: PackedStringArray) -> void:
	if ids.is_empty():
		return
	var ordered: Array[Combatant] = []
	for id: String in ids:
		for m: Combatant in squad:
			if m.record_id == id and not ordered.has(m):
				ordered.append(m)
	for m: Combatant in squad:
		if not ordered.has(m):
			ordered.append(m)
	for i: int in ordered.size():
		squad[i] = ordered[i]
