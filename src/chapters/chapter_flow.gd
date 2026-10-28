## Encounter sequencing for the linear chapter structure (design/game-brief.md
## MVP feature 5; Story 006): 3 regular fights, then the faction boss, for one
## faction. No free roaming, no branching -- the sequence is fixed by
## construction.
##
## Story 033 (ADR-0002 Migration Plan Step 2) stripped this class down to
## sequencing alone: which fight is next, its roster (`enemy_ids`), boss
## detection, and `chapter_won`. Building a battle, tracking HP/MP across
## fights, and retrying a lost fight all moved out -- HP/MP now carries over
## *by construction*, because `ChapterMode` hands the Battle mode the same
## `Combatant` instances this chapter holds (ADR-0002 §7); a loss never
## reaches this class at all (Implementation Notes).
##
## `ChapterFlow` has no scene-tree dependency (RefCounted): it can be driven
## headlessly, from `ChapterMode`, or from a test probe.
##
## Usage example:
## [codeblock]
## var squad: Array[Combatant] = [Combatant.new("Hero", 30, 10, 12, 8, 10, false)]
## var chapter := ChapterFlow.new(ChapterFlow.FACTION_BUREAUCRATIA, squad)
## chapter.start_chapter()
## var descriptor := chapter.build_next_descriptor()  # fight 0's EncounterDescriptor
## # ... ChapterMode requests Battle with `descriptor`; on a win:
## chapter.advance_on_victory()
## [/codeblock]
class_name ChapterFlow
extends RefCounted

## Regular (non-boss) fights before the boss fight (Acceptance Criteria 1-2).
## Fight indices 0..REGULAR_FIGHT_COUNT-1 are regular; REGULAR_FIGHT_COUNT
## itself is the boss fight, alone.
const REGULAR_FIGHT_COUNT: int = 3

const FACTION_BUREAUCRATIA: String = "bureaucratia"
const FACTION_MEGACORP: String = "megacorp"

## `EncounterDescriptor.faction_id` is the catalog record id (`faction_` +
## the faction name), which `EncounterValidator` checks against the catalog.
const FACTION_RECORD_PREFIX: String = "faction_"

## Placeholder `EncounterDescriptor.battle_stage_id` (Implementation Notes:
## "an interim placeholder, recorded in Completion Notes") until a real stage
## catalog exists.
const BATTLE_STAGE_ID_INTERIM: String = "stage_chapter_interim"

## ADR-0010 §3's interim per-faction boss enemy id.
const _BOSS_ENEMY_ID: Dictionary = {
	FACTION_BUREAUCRATIA: "enemy_supervisor",
	FACTION_MEGACORP: "enemy_ceo",
}

## Emitted exactly once, when the boss fight is won (Acceptance Criterion 5).
## Beating both factions' bosses is tracked by the caller across two
## ChapterFlow instances/runs -- this story has no persistent save (out of
## scope per the brief).
signal chapter_won()

## The squad fighting this chapter. Carried by reference across every fight
## (never replaced): `ChapterMode` hands this same array to the Battle mode
## as `BattleEntryPayload.party`, so HP/MP carryover is the Battle mode
## changing these same `Combatant`s in place (ADR-0002 §7) -- this class
## never reads or writes hp/mp itself any more.
var squad: Array[Combatant] = []

## Which faction's fights/roster this chapter runs (FACTION_BUREAUCRATIA or
## FACTION_MEGACORP).
var faction_name: String

## Shared across every fight in the chapter, matching BattleCore's own
## injected-RNG convention (Stats & Damage GDD F6): never global. Unused by
## this class today (no enemy stats are rolled here); kept so a caller that
## wants one shared seed across the whole chapter's battles has somewhere to
## put it.
var rng: RandomNumberGenerator

## 0-based index of the fight currently in progress, or -1 before
## start_chapter() is called.
var current_fight_index: int = -1

## True once the boss fight has been won. The chapter does not reset or
## continue past this point.
var chapter_complete: bool = false


func _init(p_faction_name: String, p_squad: Array[Combatant],
		p_rng: RandomNumberGenerator = null) -> void:
	squad = p_squad
	rng = p_rng if p_rng != null else RandomNumberGenerator.new()
	match p_faction_name:
		FACTION_MEGACORP, FACTION_BUREAUCRATIA:
			faction_name = p_faction_name
		_:
			push_error("ChapterFlow: unrecognized faction_name '%s', defaulting to Bureaucratia" % p_faction_name)
			faction_name = FACTION_BUREAUCRATIA


## Begins the chapter at fight 0. `build_next_descriptor()` is readable
## immediately after.
func start_chapter() -> void:
	chapter_complete = false
	current_fight_index = 0


## The `EncounterDescriptor` for the fight currently in progress -- side
## effect free, so a caller (or a test) may call this as many times as it
## likes without advancing anything. `retreat_allowed` is always false (no
## Camp exists yet, Implementation Notes); `can_flee` is false only at the
## boss (ADR-0010 §5).
func build_next_descriptor() -> EncounterDescriptor:
	var index: int = current_fight_index
	var is_boss: bool = index >= REGULAR_FIGHT_COUNT
	var descriptor := EncounterDescriptor.new()
	descriptor.encounter_id = "%s_fight_%d" % [faction_name, index]
	descriptor.enemy_ids = _enemy_ids_for(index, is_boss)
	descriptor.battle_stage_id = BATTLE_STAGE_ID_INTERIM
	descriptor.faction_id = FACTION_RECORD_PREFIX + faction_name
	descriptor.is_boss = is_boss
	descriptor.can_flee = not is_boss
	descriptor.retreat_allowed = false
	return descriptor


## Advances past the fight just won. At the boss, instead marks the chapter
## complete and emits `chapter_won` exactly once. The caller (`ChapterMode`)
## is responsible for calling this only on a win -- a loss never reaches this
## class (Implementation Notes: a Defeat never reaches this class).
func advance_on_victory() -> void:
	if current_fight_index >= REGULAR_FIGHT_COUNT:
		chapter_complete = true
		chapter_won.emit()
	else:
		current_fight_index += 1


## This chapter's enemy roster at `index` (ADR-0010 §3's interim per-fight
## enemy-id table): one Clerk every Bureaucratia regular fight, the
## Supervisor as its boss; a Security Drone/Middle Manager mix across
## MegaCorp's three regular fights, the CEO as its boss. One enemy id per
## regular fight, matching the roster this story's characterization tests
## (032) pinned.
func _enemy_ids_for(index: int, is_boss: bool) -> PackedStringArray:
	if is_boss:
		return PackedStringArray([_BOSS_ENEMY_ID[faction_name]])
	if faction_name == FACTION_MEGACORP:
		match index:
			0:
				return PackedStringArray(["enemy_security_drone"])
			1:
				return PackedStringArray(["enemy_middle_manager"])
			_:
				return PackedStringArray(["enemy_security_drone"])
	return PackedStringArray(["enemy_clerk"])
