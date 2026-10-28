## Minimal production construction path for a `BattleCore` from a
## `BattleEntryPayload` (ADR-0010 §3; this story's slice). Builds the enemy
## roster and the faction rule from ADR-0010's interim enemy-ID and
## faction-id tables -- the same code factories `ChapterFlow`/`ChapterMode`
## already relied on -- until content-migration story 029 gives this a
## catalog + `FactionRuleRegistry` parameter list instead. The squad is
## `payload.party` itself, never copied (ADR-0002 §7 carryover).
##
## Usage example:
## [codeblock]
## var result := BattleFactory.build(payload, RandomNumberGenerator.new())
## if result.core == null:
##     print(result.errors)  # swap failure -- Game State rolls back
## [/codeblock]
class_name BattleFactory
extends RefCounted

## `core` is `null` on failure; `errors` then names every reason (unknown
## enemy id(s), unknown faction id).
class BattleBuildResult:
	extends RefCounted
	var core: BattleCore = null
	var errors: PackedStringArray = PackedStringArray()


static func build(payload: BattleEntryPayload, rng: RandomNumberGenerator) -> BattleBuildResult:
	var result := BattleBuildResult.new()
	var descriptor: EncounterDescriptor = payload.descriptor
	var enemies: Array[Combatant] = []
	for enemy_id: String in descriptor.enemy_ids:
		var enemy: Combatant = _build_enemy(enemy_id)
		if enemy == null:
			result.errors.append("unknown enemy_id: %s" % enemy_id)
			continue
		enemies.append(enemy)
	var rule: FactionRule = _build_faction_rule(descriptor.faction_id)
	if rule == null:
		result.errors.append("unknown faction_id: %s" % descriptor.faction_id)
	if not result.errors.is_empty():
		return result
	result.core = BattleCore.new(payload.party, enemies, rng, rule)
	return result


## ADR-0010 §3's interim enemy-ID -> factory table, covering the IDs
## `ChapterMode` emits. Deleted together with the table once content-migration
## story 029 lands.
static func _build_enemy(enemy_id: String) -> Combatant:
	match enemy_id:
		"enemy_clerk":
			return BureaucratiaRule.make_clerk()
		"enemy_supervisor":
			return BureaucratiaRule.make_supervisor()
		"enemy_security_drone":
			return MegaCorpRule.make_security_drone()
		"enemy_middle_manager":
			return MegaCorpRule.make_middle_manager()
		"enemy_ceo":
			return MegaCorpRule.make_ceo()
		_:
			return null


static func _build_faction_rule(faction_id: String) -> FactionRule:
	match faction_id:
		"faction_bureaucratia":
			return BureaucratiaRule.new()
		"faction_megacorp":
			return MegaCorpRule.new()
		_:
			return null
