## Pointer focus (ADR-0008 §6, Input rule 3; story 058): hover moves focus to
## a tracked control only once the pointer has travelled `switch_px` pixels in
## total since the screen opened (`InputConfig.pointer_switch_px`); a resting
## pointer never steals the default focus. `UiService` feeds `add_motion()` each
## frame and calls `reset()` on every screen open (connect `MenuGuard.opened`).
class_name PointerFocusSync
extends Node

## The travel threshold, in pixels (exact: `< switch_px` keeps, `>=` moves).
var switch_px: int = 8

var _travelled: float = 0.0


## Starts the count again (a screen opened).
func reset() -> void:
	_travelled = 0.0


## Adds one frame's pointer movement.
func add_motion(delta: Vector2) -> void:
	_travelled += delta.length()


## The cumulative pointer travel since the last `reset()`.
func travelled() -> float:
	return _travelled


## Hooks `control`'s `mouse_entered` (a focusable descendant).
func track(control: Control) -> void:
	if not control.mouse_entered.is_connected(_on_hover.bind(control)):
		control.mouse_entered.connect(_on_hover.bind(control))


func _on_hover(control: Control) -> void:
	if _travelled >= float(switch_px) and control.is_inside_tree():
		control.grab_focus(true)
