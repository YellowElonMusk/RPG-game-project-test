## One campaign ending (Faction Reputation & Endings; narrative bible §6.6):
## its title, the conversation that plays when the last chapter ends, and
## the line the credits open with. Stored one per file at
## `res://data/endings/<id>.tres`; `EndingRules.pick()` chooses which.
##
## Usage example:
## [codeblock]
## var ending: EndingData = EndingData.load_by_id("ending_human")
## overworld.talk(Conversation.load_by_id(ending.conversation_id))
## [/codeblock]
class_name EndingData
extends Resource

const DIR: String = "res://data/endings/"

## Permanent ID, equal to the filename; `ending_` prefix.
@export var id: String = ""
## Shown as the credits' heading ("Ending: <title>").
@export var title: String = ""
## The `conv_` conversation that plays before the credits.
@export var conversation_id: String = ""
## The credits' first line under the heading.
@export_multiline var epilogue: String = ""


## The ending at `DIR/<id>.tres`, or null.
static func load_by_id(ending_id: String) -> EndingData:
	if ending_id.is_empty():
		return null
	var path: String = DIR + ending_id + ".tres"
	if not ResourceLoader.exists(path):
		push_error("EndingData: no ending at %s" % path)
		return null
	return ResourceLoader.load(path) as EndingData
