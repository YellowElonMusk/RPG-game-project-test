## The linear chapter sequence (design/game-brief.md MVP feature 5; Story
## 006): 3 regular fights, then the faction boss, for one faction. No free
## roaming, no branching — the sequence is fixed by construction.
##
## This is the integration layer that calls Story 001's BattleCore repeatedly
## with Story 002's or Story 004's FactionRule active; it never reimplements
## battle logic itself. A caller (a UI layer, or this story's own demo
## scaffold) listens to `fight_started` and calls `BattleHud.setup(battle)`
## for each new BattleCore as a fight begins.
##
## HP/MP carry over between fights within a chapter (no full heal — no
## leveling/items/shops exist in this MVP to justify one). Each fight gets
## its own fresh BattleCore (a fresh enemy roster), constructed with
## `BattleCore.start_battle(false)` so the squad's current HP/MP drive that
## fight's first-turn selection instead of being reset to full. Losing a
## fight restores that fight's own starting snapshot (not full HP, and not
## the chapter's original starting state) and retries only that fight.
##
## ChapterFlow has no scene-tree dependency (RefCounted), matching
## BattleCore's own convention: it can be driven headlessly, from a demo
## scaffold, or eventually a future game-loop story.
##
## Usage example:
## [codeblock]
## var squad: Array[Combatant] = [Combatant.new("Hero", 30, 10, 12, 8, 10, false)]
## var chapter := ChapterFlow.new(ChapterFlow.FACTION_BUREAUCRATIA, squad)
## chapter.fight_started.connect(func(battle, fight_index, is_boss): hud.setup(battle))
## chapter.chapter_won.connect(func(): print("Chapter complete!"))
## chapter.start_chapter()
## [/codeblock]
class_name ChapterFlow
extends RefCounted

## Regular (non-boss) fights before the boss fight (Acceptance Criteria 1-2).
## Fight indices 0..REGULAR_FIGHT_COUNT-1 are regular; REGULAR_FIGHT_COUNT
## itself is the boss fight, alone.
const REGULAR_FIGHT_COUNT: int = 3

const FACTION_BUREAUCRATIA: String = "bureaucratia"
const FACTION_MEGACORP: String = "megacorp"

## Emitted when a new BattleCore is ready for a fight (including a retry
## after a loss, which gets its own fresh BattleCore and fresh enemies).
## `fight_index` is 0-based; `is_boss` is true only for the final fight. A
## caller should call `BattleHud.setup(battle)` (or equivalent) each time
## this fires, since `battle` is a new instance every time.
signal fight_started(battle: BattleCore, fight_index: int, is_boss: bool)

## Emitted when `fight_index` is lost, right before it is retried from its
## own starting snapshot (Acceptance Criterion 4). `fight_started` fires
## again immediately afterward for the retry.
signal fight_lost(fight_index: int)

## Emitted exactly once, when the boss fight is won (Acceptance Criterion 5).
## Beating both factions' bosses is tracked by the caller across two
## ChapterFlow instances/runs — this story has no persistent save (out of
## scope per the brief).
signal chapter_won()

## The squad fighting this chapter. Carried by reference across every fight:
## ChapterFlow mutates its members' hp/mp directly for carryover and retry
## (Combatant's hp/mp are plain public fields), it never replaces the array.
var squad: Array[Combatant] = []

## Which faction's fights/rule/roster this chapter runs
## (FACTION_BUREAUCRATIA or FACTION_MEGACORP).
var faction_name: String

## Shared across every fight in the chapter, matching BattleCore's own
## injected-RNG convention (Stats & Damage GDD F6): never global.
var rng: RandomNumberGenerator

## The BattleCore driving the current fight, or null before start_chapter()
## is called. Replaced with a new instance on every advance and every retry.
var current_battle: BattleCore

## 0-based index of the fight currently in progress, or -1 before
## start_chapter() is called.
var current_fight_index: int = -1

## True once the boss fight has been won. The chapter does not reset or
## continue past this point.
var chapter_complete: bool = false

var _faction_rule: FactionRule
## Combatant -> {"hp": int, "mp": int}, captured at the start of the fight
## currently in progress, used to restore that fight's own starting state on
## a loss (Acceptance Criterion 4) — never the whole chapter's original
## state, and never a full heal.
var _fight_start_snapshot: Dictionary = {}


func _init(p_faction_name: String, p_squad: Array[Combatant],
		p_rng: RandomNumberGenerator = null) -> void:
	faction_name = p_faction_name
	squad = p_squad
	rng = p_rng if p_rng != null else RandomNumberGenerator.new()
	match faction_name:
		FACTION_MEGACORP:
			_faction_rule = MegaCorpRule.new()
		FACTION_BUREAUCRATIA:
			_faction_rule = BureaucratiaRule.new()
		_:
			push_error("ChapterFlow: unrecognized faction_name '%s', defaulting to Bureaucratia" % faction_name)
			faction_name = FACTION_BUREAUCRATIA
			_faction_rule = BureaucratiaRule.new()


## Begins the chapter at fight 0. Emits the first fight_started synchronously.
## Example: [code]chapter.start_chapter()[/code]
func start_chapter() -> void:
	chapter_complete = false
	_start_fight(0)


func _start_fight(index: int) -> void:
	current_fight_index = index
	_snapshot_squad_state()
	_clear_squad_transients()

	var is_boss: bool = index >= REGULAR_FIGHT_COUNT
	var enemies: Array[Combatant] = _build_boss_enemies() if is_boss else _build_regular_enemies(index)

	current_battle = BattleCore.new(squad, enemies, rng, _faction_rule)
	current_battle.battle_ended.connect(_on_fight_ended.bind(index))
	current_battle.start_battle(false)
	fight_started.emit(current_battle, index, is_boss)


func _on_fight_ended(won: bool, index: int) -> void:
	if won:
		if index >= REGULAR_FIGHT_COUNT:
			chapter_complete = true
			chapter_won.emit()
		else:
			_start_fight(index + 1)
	else:
		_restore_squad_snapshot()
		fight_lost.emit(index)
		_start_fight(index)


## Captures each squad member's current hp/mp (plain field reads) so a loss
## in the fight about to start can be retried from exactly this state —
## whatever HP/MP carried into this fight, which may already be below full.
func _snapshot_squad_state() -> void:
	_fight_start_snapshot.clear()
	for combatant in squad:
		_fight_start_snapshot[combatant] = {"hp": combatant.hp, "mp": combatant.mp}


## Restores the snapshot taken at the start of the fight that was just lost
## (plain field writes) — not a full heal, and not the chapter's original
## starting state.
func _restore_squad_snapshot() -> void:
	for combatant in squad:
		var snapshot: Dictionary = _fight_start_snapshot.get(combatant, {})
		if snapshot.is_empty():
			continue
		combatant.hp = snapshot["hp"]
		combatant.mp = snapshot["mp"]


## Clears transient per-fight combat flags left over from the previous fight
## (is_defending/is_stunned/vulnerable_rounds_left) without touching hp/mp.
## These are meaningless carried into a new BattleCore against a new enemy
## roster; only HP/MP carry over.
func _clear_squad_transients() -> void:
	for combatant in squad:
		combatant.is_defending = false
		combatant.is_stunned = false
		combatant.vulnerable_rounds_left = 0


## This chapter's regular-fight enemy roster (Acceptance Criteria 1-2): one
## Clerk every Bureaucratia regular fight; a Security Drone/Middle Manager
## mix varied across MegaCorp's three regular fights. One enemy per regular
## fight (the brief fixes no exact number — "1-2 enemies" is explicitly a
## free choice): across a 3-fight-plus-boss chapter with HP/MP carryover and
## no healing between fights, two full-strength enemies per regular fight
## compounds faster than a squad's carried-over HP recovers, making later
## fights in the chapter unwinnable; one keeps every fight (including the
## chapter's later fights, once HP is already down) a fair fight.
func _build_regular_enemies(fight_index: int) -> Array[Combatant]:
	if faction_name == FACTION_MEGACORP:
		match fight_index:
			0:
				return [MegaCorpRule.make_security_drone()]
			1:
				return [MegaCorpRule.make_middle_manager()]
			_:
				return [MegaCorpRule.make_security_drone()]
	return [BureaucratiaRule.make_clerk()]


## This chapter's boss fight roster: the boss alone (Acceptance Criteria 1-2:
## "followed by the boss fight").
func _build_boss_enemies() -> Array[Combatant]:
	if faction_name == FACTION_MEGACORP:
		return [MegaCorpRule.make_ceo()]
	return [BureaucratiaRule.make_supervisor()]
