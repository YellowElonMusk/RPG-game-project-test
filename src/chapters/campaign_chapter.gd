## One chapter of the campaign (`Campaign`): its step list, its story-flag
## registry and where the squad arrives when the previous chapter ends.
class_name CampaignChapter
extends Resource

## The chapter's ordered steps; `steps.chapter_id` is the chapter's ID.
@export var steps: ChapterSteps
## The chapter's story-flag registry (GDD Overworld rule 18).
@export var flags: StoryFlagRegistry
## The EntryPoint on the first step's map the squad arrives at when this
## chapter follows another one. New Game (the first chapter) uses the map's
## spawn cell instead.
@export var start_entry_id: StringName = &""
## The camp Retreat falls back to once this chapter has begun.
@export var start_camp_id: String = ""
## The line shown on arrival (the chapter's opening card); "" for none.
@export_multiline var intro_line: String = ""
## The line shown when the squad ends this chapter and no chapter follows.
@export_multiline var end_line: String = ""


## The chapter's ID (`steps.chapter_id`), or "" without steps.
func chapter_id() -> String:
	return steps.chapter_id if steps != null else ""
