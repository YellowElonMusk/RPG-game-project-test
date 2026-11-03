## Victory rewards (Stats & Damage GDD F9): the sum of `reward_xp` and
## `reward_money` over the defeated (knocked-out) enemies, read from their
## Enemy records. A loss or flee gives nothing; the caller only asks on a win.
##
## Usage example:
## [codeblock]
## var r: Dictionary = BattleRewards.totals(battle.enemies, BattleCatalog.shipped())
## print(r["xp"], " XP, ", r["money"], " money")
## [/codeblock]
class_name BattleRewards
extends RefCounted


## `{"xp": int, "money": int}` for the knocked-out enemies in `enemies`. An
## enemy with no record (a test double) gives nothing.
static func totals(enemies: Array[Combatant], catalog: ContentCatalogService) -> Dictionary:
	var xp: int = 0
	var money: int = 0
	for enemy: Combatant in enemies:
		if not enemy.is_knocked_out() or enemy.record_id.is_empty() or catalog == null:
			continue
		var rec := catalog.get_record(&"enemy", enemy.record_id) as EnemyData
		if rec == null:
			continue
		xp += rec.reward_xp
		money += rec.reward_money
	return {"xp": xp, "money": money}
