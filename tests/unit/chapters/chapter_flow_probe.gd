## Test-side adapter over ChapterFlow (Story 032; ADR-0002 Migration Step 0,
## Validation Criteria: "Step 0 characterization tests pass unchanged after
## the ChapterFlow refactor"). This is the only file Story 033 may change --
## every test file and expected table it drives stays byte-identical across
## that refactor.
##
## Story 033 stripped battle construction and per-fight hp/mp snapshotting
## out of `ChapterFlow` itself (ADR-0002 Migration Plan Step 2): winning a
## fight is now `advance_on_victory()`, a plain method with no `BattleCore`
## and no signal. `win_current()` below also clears the squad's transient
## combat flags directly -- Story 032's
## `test_clear_squad_transients_resets_combat_flags_on_new_fight` still needs
## this to happen on every win, but the real responsibility moved to the
## Battle mode (`BattleCore.clear_transients(party)`, Story 034's Control
## Manifest rule); this probe stands in for that call so the pinned test
## keeps passing unchanged.
class_name ChapterFlowProbe
extends RefCounted

var chapter: ChapterFlow

## Incremented once per chapter_won emission (check 4: "a boss win emits
## chapter_won once").
var chapter_won_count: int = 0

## Interim enemy-id -> display-name map (ADR-0010 §3), used only to translate
## `EncounterDescriptor.enemy_ids` back into the display names Story 032's
## expected tables were written against. A real display-name lookup belongs
## to the Battle mode/content catalog, never this probe.
const _ENEMY_DISPLAY_NAMES: Dictionary = {
	"enemy_clerk": "Clerk",
	"enemy_supervisor": "Supervisor",
	"enemy_security_drone": "Security Drone",
	"enemy_middle_manager": "Middle Manager",
	"enemy_ceo": "CEO",
}


func _init(faction_name: String, squad: Array[Combatant],
		rng: RandomNumberGenerator = null) -> void:
	chapter = ChapterFlow.new(faction_name, squad, rng)
	chapter.chapter_won.connect(func() -> void: chapter_won_count += 1)


## Begins the chapter. current_fight() is readable immediately after.
func start() -> void:
	chapter.start_chapter()


## `{index: int, is_boss: bool, enemy_names: Array[String]}` for the fight
## currently in progress, read live off `build_next_descriptor()` -- never
## cached, since a win replaces it.
func current_fight() -> Dictionary:
	var descriptor: EncounterDescriptor = chapter.build_next_descriptor()
	var enemy_names: Array[String] = []
	for enemy_id: String in descriptor.enemy_ids:
		enemy_names.append(_ENEMY_DISPLAY_NAMES.get(enemy_id, enemy_id))
	return {
		"index": chapter.current_fight_index,
		"is_boss": descriptor.is_boss,
		"enemy_names": enemy_names,
	}


## Advances the fight in progress as a win -- `ChapterFlow`'s own real entry
## point (`advance_on_victory()`), the same call `ChapterMode` makes after
## `on_thawed(id, VICTORY)`, plus the transient-flag clear Story 034's Battle
## mode owns in production (see class doc comment).
func win_current() -> void:
	chapter.advance_on_victory()
	_clear_squad_transients()


## `{hp: int, mp: int}` per squad member, in squad order, read live off the
## Combatants ChapterFlow carries by reference (never a copy taken earlier).
func squad_hp_mp() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for combatant: Combatant in chapter.squad:
		result.append({"hp": combatant.hp, "mp": combatant.mp})
	return result


func _clear_squad_transients() -> void:
	for combatant: Combatant in chapter.squad:
		combatant.is_defending = false
		combatant.is_stunned = false
		combatant.vulnerable_rounds_left = 0
