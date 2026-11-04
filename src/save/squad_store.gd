## The squad's live members and any loaded-but-not-yet-applied save data
## (Leveling GDD rule 7). `GameRoot` owns one; the Overworld, Camp and the
## `squad` save participant share it, so a save always sees the same
## `Combatant`s the battles changed in place (ADR-0002 §7).
class_name SquadStore
extends RefCounted

## The live squad, or empty until the next Overworld entry builds it.
var squad: Array[Combatant] = []
## A committed save's members, `{char_id: {level, xp, hp, mp}}`, applied by
## the next build; empty otherwise.
var pending: Dictionary = {}


## Builds the squad from `catalog` (level 1, full HP/MP), then applies and
## clears `pending`: each saved member's level (stats rebuilt from its
## record), XP, HP, MP and equipment.
func rebuild(catalog: ContentCatalogService) -> Array[Combatant]:
	squad = ChapterFlow.build_squad(catalog)
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
	pending = {}
	return squad
