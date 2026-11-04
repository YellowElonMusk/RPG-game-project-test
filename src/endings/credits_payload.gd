## Title's payload after the campaign ends (`GameStateMachine.finish_campaign`):
## Title rolls the credits for `ending` before showing its buttons.
class_name CreditsPayload
extends RefCounted

## The ending that played; null rolls the credits with no ending heading.
var ending: EndingData = null


func _init(p_ending: EndingData = null) -> void:
	ending = p_ending
