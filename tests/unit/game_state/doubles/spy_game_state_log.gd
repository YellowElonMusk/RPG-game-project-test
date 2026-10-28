## Records structured `{level, code, context}` entries instead of logging to
## the console, so tests assert on `code` and `context`, never on wording.
class_name SpyGameStateLog extends GameStateLog

var entries: Array[Dictionary] = []


func error(code: StringName, context: Dictionary = {}) -> void:
	entries.append({"level": &"error", "code": code, "context": context})


func warning(code: StringName, context: Dictionary = {}) -> void:
	entries.append({"level": &"warning", "code": code, "context": context})
