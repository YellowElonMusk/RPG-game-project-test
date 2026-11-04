## The ordered chapter list (Paris, then London, ...): which chapter follows
## which, and each chapter's steps and flag registry. `WorldState.chapter_id`
## names the current one; "" means the first.
##
## Usage example:
## [codeblock]
## var campaign: Campaign = Campaign.load_default()
## var next: CampaignChapter = campaign.next_after(world_state.chapter_id)
## [/codeblock]
class_name Campaign
extends Resource

const DEFAULT_PATH: String = "res://data/chapters/campaign.tres"

@export var chapters: Array[CampaignChapter] = []


## The shipped campaign, or null when `DEFAULT_PATH` is missing.
static func load_default() -> Campaign:
	if not ResourceLoader.exists(DEFAULT_PATH):
		return null
	return ResourceLoader.load(DEFAULT_PATH) as Campaign


## The chapter with `chapter_id`; "" means the first chapter. Null when
## unknown or the campaign is empty.
func chapter(chapter_id: String) -> CampaignChapter:
	if chapters.is_empty():
		return null
	if chapter_id.is_empty():
		return chapters[0]
	for c: CampaignChapter in chapters:
		if c.chapter_id() == chapter_id:
			return c
	return null


## The chapter after `chapter_id` ("" = the first chapter), or null when it
## is the last one or unknown.
func next_after(chapter_id: String) -> CampaignChapter:
	var current: CampaignChapter = chapter(chapter_id)
	if current == null:
		return null
	var i: int = chapters.find(current)
	return chapters[i + 1] if i + 1 < chapters.size() else null


## Every chapter's step list, in campaign order (validators).
func all_steps() -> Array[ChapterSteps]:
	var out: Array[ChapterSteps] = []
	for c: CampaignChapter in chapters:
		if c.steps != null:
			out.append(c.steps)
	return out
