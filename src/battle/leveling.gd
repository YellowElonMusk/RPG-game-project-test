## Leveling (design/gdd/leveling.md): XP on Victory to every standing squad
## member, level-ups by `xp_total(L) = k × L × (L − 1)`, and per-character
## growth from the Character record. Stats are always derivable as
## `base + growth × (level − 1)`, so a save stores only level, XP, HP and MP.
##
## Usage example:
## [codeblock]
## var lines: Array[String] = Leveling.award(battle.squad, 40, BattleCatalog.shipped())
## for line in lines: print(line)   # "Karen reached level 2!"
## [/codeblock]
class_name Leveling
extends RefCounted

## `xp_curve_k` (Leveling GDD Tuning Knobs).
const XP_CURVE_K: int = 10
## `level_max` (Leveling GDD Tuning Knobs).
const LEVEL_MAX: int = 99


## Total XP needed to reach `level` (F: `k × L × (L − 1)`; level 1 is 0).
static func xp_total(level: int) -> int:
	return XP_CURVE_K * level * (level - 1)


## Gives `amount` XP to every member of `party` still standing (rule 2) and
## levels them up (rules 3-4). Returns one line per level gained, in party
## order, e.g. "Karen reached level 3!".
static func award(party: Array[Combatant], amount: int, catalog: ContentCatalogService) -> Array[String]:
	var lines: Array[String] = []
	if amount <= 0:
		return lines
	for member: Combatant in party:
		if member.is_enemy or member.is_knocked_out():
			continue
		member.xp += amount
		while member.level < LEVEL_MAX and member.xp >= xp_total(member.level + 1):
			_grow(member, _record(member, catalog), 1)
			member.level += 1
			lines.append("%s reached level %d!" % [member.display_name, member.level])
	return lines


## Sets `member` to `level` from its record's base stats (rule 7, a load):
## stats become `base + growth × (level − 1)`; HP/MP are left to the caller.
static func apply_level(member: Combatant, level: int, catalog: ContentCatalogService) -> void:
	var rec: CharacterData = _record(member, catalog)
	if rec == null:
		return
	member.level = clampi(level, 1, LEVEL_MAX)
	var n: int = member.level - 1
	member.max_hp = rec.max_hp + rec.growth_hp * n
	member.max_mp = rec.max_mp + rec.growth_mp * n
	member.attack = rec.attack + rec.growth_attack * n
	member.defense = rec.defense + rec.growth_defense * n
	member.speed = rec.speed + rec.growth_speed * n


## One level's growth: maxima and current HP/MP rise together (rule 4).
static func _grow(member: Combatant, rec: CharacterData, levels: int) -> void:
	if rec == null:
		return
	member.max_hp += rec.growth_hp * levels
	member.hp += rec.growth_hp * levels
	member.max_mp += rec.growth_mp * levels
	member.mp += rec.growth_mp * levels
	member.attack += rec.growth_attack * levels
	member.defense += rec.growth_defense * levels
	member.speed += rec.growth_speed * levels


static func _record(member: Combatant, catalog: ContentCatalogService) -> CharacterData:
	if catalog == null or member.record_id.is_empty():
		return null
	return catalog.get_record(&"character", member.record_id) as CharacterData
