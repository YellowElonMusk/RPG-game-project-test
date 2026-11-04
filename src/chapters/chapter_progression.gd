## Moving the squad from one campaign chapter to the next (pure; no scene
## access). GameRoot calls `advance()` when the Overworld's chapter-end
## prompt is answered Yes, then sends the squad to the returned chapter's
## first map.
##
## Usage example:
## [codeblock]
## var next: CampaignChapter = ChapterProgression.advance(world_state, campaign)
## if next != null:
##     machine.request_transition(GameStateMachine.Mode.OVERWORLD,
##             ChapterProgression.arrival_payload(next))
## [/codeblock]
class_name ChapterProgression
extends RefCounted


## Makes `chapter` current in `world_state`: its ID, its first step and that
## step's `flags_on_enter` (GDD rule 8).
static func begin(world_state: WorldState, chapter: CampaignChapter) -> void:
	if world_state == null or chapter == null or chapter.steps == null:
		return
	world_state.chapter_id = chapter.chapter_id()
	if chapter.steps.steps.is_empty():
		world_state.chapter_step = ""
		return
	var first: ChapterStep = chapter.steps.steps[0]
	world_state.chapter_step = first.id
	for flag: String in first.flags_on_enter:
		world_state.set_flag(flag)


## Begins the chapter after `world_state.chapter_id` and returns it; null,
## with `world_state` untouched, when the current chapter is the last.
static func advance(world_state: WorldState, campaign: Campaign) -> CampaignChapter:
	if world_state == null or campaign == null:
		return null
	var next: CampaignChapter = campaign.next_after(world_state.chapter_id)
	if next == null:
		return null
	begin(world_state, next)
	return next


## Where the squad arrives in `chapter`: its first step's map, at
## `start_entry_id`.
static func arrival_payload(chapter: CampaignChapter) -> MapEntryPayload:
	if chapter == null or chapter.steps == null or chapter.steps.steps.is_empty():
		return null
	return MapEntryPayload.new(chapter.steps.steps[0].map_id, chapter.start_entry_id)
