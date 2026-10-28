## Structured logging for Game State (ADR-0002, story-001). Tests assert on
## `code` and `context`, never on message wording.
class_name GameStateLog extends RefCounted

## Logs a structured error. `context` carries whatever fields `code` needs
## (e.g. `{"from": Mode.BATTLE, "to": Mode.OVERWORLD}`).
func error(code: StringName, context: Dictionary = {}) -> void:
	push_error("GameState error [%s]: %s" % [code, context])


## Logs a structured warning. See `error()`.
func warning(code: StringName, context: Dictionary = {}) -> void:
	push_warning("GameState warning [%s]: %s" % [code, context])
