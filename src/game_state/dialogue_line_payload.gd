## Payload for the interim Dialogue overlay (`InterimLineDialogue`): one
## line of text, optionally with a speaker. Opened through
## `GameStateMachine.open_overlay(OverlayKind.DIALOGUE, payload)`. The
## Dialogue, Banter & Quests system (not designed, systems index #17)
## replaces the overlay; this payload is its smallest input.
class_name DialogueLinePayload extends RefCounted

## The line, shown verbatim.
var text: String = ""
## Who says it; empty for none.
var speaker: String = ""
## Seconds after opening during which `confirm` is refused (P2 Guarded Menu,
## `input_guard`, 0.15 s), so a press mashed from the previous screen never
## skips the line.
var input_guard_s: float = 0.15


func _init(p_text: String = "", p_speaker: String = "") -> void:
	text = p_text
	speaker = p_speaker
