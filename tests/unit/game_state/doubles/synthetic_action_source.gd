## The ADR-0002 `ActionSource` contract (signal-and-method, not a required
## base class). Names from `input-system.md`, verbatim.
class_name SyntheticActionSource extends RefCounted

signal action_pressed(action: StringName)
signal action_released(action: StringName)
signal focus_lost()
signal device_lost()

var move_vector: Vector2 = Vector2.ZERO


func get_move_vector() -> Vector2:
	return move_vector


func press(action: StringName) -> void:
	action_pressed.emit(action)


func release(action: StringName) -> void:
	action_released.emit(action)


func lose_focus() -> void:
	focus_lost.emit()


func lose_device() -> void:
	device_lost.emit()
