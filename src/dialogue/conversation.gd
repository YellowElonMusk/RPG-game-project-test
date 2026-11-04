## An ordered conversation (Dialogue system, systems index #17): lines with
## speakers, optional choices and flag conditions. Stored one per file at
## `res://data/dialogue/<id>.tres` and loaded by `Conversation.load_by_id()`.
## Not a ContentCatalog record type: conversations hold nested line
## resources, which catalog records may not (ADR-0001).
##
## Usage example:
## [codeblock]
## var talk: Conversation = Conversation.load_by_id("conv_paris_union_regular")
## overworld.talk(talk)
## [/codeblock]
class_name Conversation
extends Resource

## Where conversation files live.
const DIR: String = "res://data/dialogue/"

## Permanent ID, equal to the filename; `conv_` prefix.
@export var id: String = ""
## The lines, in order.
@export var lines: Array[DialogueLine] = []


## The conversation at `DIR/<id>.tres`, or null when there is none.
static func load_by_id(conversation_id: String) -> Conversation:
	if conversation_id.is_empty():
		return null
	var path: String = DIR + conversation_id + ".tres"
	if not ResourceLoader.exists(path):
		push_error("Conversation: no conversation at %s" % path)
		return null
	return ResourceLoader.load(path) as Conversation


## A one-line conversation (the old single-line Dialogue).
static func single(text: String, speaker: String = "") -> Conversation:
	var line := DialogueLine.new()
	line.text = text
	line.speaker = speaker
	var talk := Conversation.new()
	talk.lines.append(line)
	return talk


## The index of the line whose `id` is `line_id`, or -1.
func index_of(line_id: String) -> int:
	for i: int in lines.size():
		if lines[i].id == line_id:
			return i
	return -1
