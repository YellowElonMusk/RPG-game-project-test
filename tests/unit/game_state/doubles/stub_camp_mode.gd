## Subclasses `GameMode`, same note as `StubOverworldMode`.
class_name StubCampMode extends GameMode

## Story 010: counts `handle_action` calls.
var handle_action_count: int = 0
var last_action: StringName = &""
var last_pressed: bool = false


func handle_action(action: StringName, pressed: bool) -> bool:
	handle_action_count += 1
	last_action = action
	last_pressed = pressed
	return false
