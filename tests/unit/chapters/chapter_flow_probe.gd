## Test-side adapter over ChapterFlow (Story 032; ADR-0002 Migration Step 0,
## Validation Criteria: "Step 0 characterization tests pass unchanged after
## the ChapterFlow refactor"). This is the only file Story 033 may change --
## every test file and expected table it drives stays byte-identical across
## that refactor.
##
## Forces fight outcomes through ChapterFlow's own real signal
## (`current_battle.battle_ended.emit(won)`), never a private method, so the
## probe exercises exactly the path a real BattleCore would take.
class_name ChapterFlowProbe
extends RefCounted

var chapter: ChapterFlow

## Incremented once per chapter_won emission (check 4: "a boss win emits
## chapter_won once").
var chapter_won_count: int = 0

## Incremented once per fight_lost emission (check 5).
var fight_lost_count: int = 0


func _init(faction_name: String, squad: Array[Combatant],
		rng: RandomNumberGenerator = null) -> void:
	chapter = ChapterFlow.new(faction_name, squad, rng)
	chapter.chapter_won.connect(func() -> void: chapter_won_count += 1)
	chapter.fight_lost.connect(func(_index: int) -> void: fight_lost_count += 1)


## Begins the chapter. current_fight() is readable immediately after.
func start() -> void:
	chapter.start_chapter()


## `{index: int, is_boss: bool, enemy_names: Array[String]}` for the fight
## currently in progress, read live off the current BattleCore -- never
## cached, since a retry or advance replaces `current_battle`.
func current_fight() -> Dictionary:
	var enemy_names: Array[String] = []
	for enemy: Combatant in chapter.current_battle.enemies:
		enemy_names.append(enemy.display_name)
	return {
		"index": chapter.current_fight_index,
		"is_boss": chapter.current_fight_index >= ChapterFlow.REGULAR_FIGHT_COUNT,
		"enemy_names": enemy_names,
	}


## Forces the fight in progress to a win via the real battle_ended signal --
## ChapterFlow reacts exactly as it would to a real BattleCore outcome.
func win_current() -> void:
	chapter.current_battle.battle_ended.emit(true)


## Forces the fight in progress to a loss via the real battle_ended signal.
func lose_current() -> void:
	chapter.current_battle.battle_ended.emit(false)


## `{hp: int, mp: int}` per squad member, in squad order, read live off the
## Combatants ChapterFlow carries by reference (never a copy taken earlier).
func squad_hp_mp() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for combatant: Combatant in chapter.squad:
		result.append({"hp": combatant.hp, "mp": combatant.mp})
	return result
