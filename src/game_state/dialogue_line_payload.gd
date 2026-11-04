## Payload for the Dialogue overlay (`InterimLineDialogue`): one line of
## text with an optional speaker, or a whole `Conversation` (Dialogue
## system, systems index #17). Opened through
## `GameStateMachine.open_overlay(OverlayKind.DIALOGUE, payload)`.
##
## Usage example:
## [codeblock]
## var p := DialogueLinePayload.new("Mind the queue.", "Café regular")
## var talk := DialogueLinePayload.for_conversation(conv, world.has_flag, world.set_flag)
## [/codeblock]
class_name DialogueLinePayload extends RefCounted

## The line, shown verbatim (ignored when `conversation` is set).
var text: String = ""
## Who says it; empty for none.
var speaker: String = ""
## Seconds after opening, and after choices appear, during which `confirm`
## is refused (P2 Guarded Menu, `input_guard`, 0.15 s), so a press mashed
## from the previous screen never skips the line or picks an answer.
var input_guard_s: float = 0.15
## A whole conversation; null = the one line above.
var conversation: Conversation = null
## `func(flag: String) -> bool` for line conditions; unset = no flag is set.
var has_flag: Callable = Callable()
## `func(flag: String)` for flags set by lines and choices.
var set_flag: Callable = Callable()
## `func(char_id: String) -> String`: a squad member's display name, or ""
## when they are not in the party (their lines are skipped).
var speaker_name: Callable = Callable()


func _init(p_text: String = "", p_speaker: String = "") -> void:
	text = p_text
	speaker = p_speaker


## A payload that plays `talk` with the given flag and name lookups.
static func for_conversation(talk: Conversation, p_has_flag: Callable = Callable(),
		p_set_flag: Callable = Callable(), p_speaker_name: Callable = Callable()) -> DialogueLinePayload:
	var payload := DialogueLinePayload.new()
	payload.conversation = talk
	payload.has_flag = p_has_flag
	payload.set_flag = p_set_flag
	payload.speaker_name = p_speaker_name
	return payload


## The conversation to play: `conversation`, or the one line as a
## one-line conversation.
func to_conversation() -> Conversation:
	return conversation if conversation != null else Conversation.single(text, speaker)
