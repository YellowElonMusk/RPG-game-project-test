## Base class for every overlay scene's root script (ADR-0002 Key
## Interfaces). `@abstract`, same note as `GameMode`: every test double
## subclasses this base.
@abstract class_name GameOverlay extends Control

## Called by `SceneLoader` before `add_child()`.
func setup(_machine: GameStateMachine, _payload: RefCounted) -> void:
	pass


## Returns `true` if this overlay consumed the action. Routing to this call
## is story-010's concern.
@abstract func handle_action(action: StringName, pressed: bool) -> bool
