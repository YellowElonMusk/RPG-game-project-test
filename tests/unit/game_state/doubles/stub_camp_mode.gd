## Subclasses `GameMode`, same note as `StubOverworldMode`.
class_name StubCampMode extends GameMode


func handle_action(_action: StringName, _pressed: bool) -> bool:
	return false
