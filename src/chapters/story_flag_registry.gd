## The interim MVP story-flag registry (GDD Overworld rule 18, OQ-13): every
## flag a map, checkpoint, marker or chapter step reads is listed here with
## what sets it. Interim data until Dialogue, Banter & Quests replaces it;
## the narrative-director owns its content. Checked by
## `tests/unit/overworld/paris_stage_registry_rules_test.gd` (story 055).
##
## Usage example:
## [codeblock]
## var reg: StoryFlagRegistry = load("res://data/chapters/chapter_paris_flags.tres")
## assert(reg.set_by("permits_mandatory") == StoryFlagRegistry.CHAPTER_STEP)
## [/codeblock]
class_name StoryFlagRegistry
extends Resource

## A ChapterFlow step change (the only legal setter of a stage-raising flag).
const CHAPTER_STEP: String = "chapter_step"
## A story encounter's Victory.
const STORY_VICTORY: String = "story_victory"
## A gag's `change` response.
const GAG_CHANGE: String = "gag_change"
## The region boss's Victory (`region_liberation_flag`).
const BOSS_VICTORY: String = "boss_victory"
## An `open` victory payoff's checkpoint (rule 7a): the payoff opens the gate
## directly; the flag names the requirement the Victory meets.
const VICTORY_PAYOFF: String = "victory_payoff"

@export var chapter_id: String = ""
## Flag name -> what sets it (one of the constants above).
@export var flags: Dictionary[String, String] = {}


## `true` when `flag` is registered.
func has_flag(flag: String) -> bool:
	return flags.has(flag)


## What sets `flag`, or "" when it is not registered.
func set_by(flag: String) -> String:
	return flags.get(flag, "")
