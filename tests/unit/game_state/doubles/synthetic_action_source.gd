## The ADR-0002 `ActionSource` contract (signal-and-method, not a required
## base class). Names from `input-system.md`, verbatim.
class_name SyntheticActionSource extends RefCounted

signal action_pressed(action: StringName)
signal action_released(action: StringName)
signal focus_lost()
signal device_lost()

## Story 010: declared so a test can prove the machine does NOT connect to
## them (ADR-0002 §6 "Deliberately NOT consumed by Game State") — real
## signals from `InputResolver`'s surface (ADR-0003 Key Interfaces), unused
## by anything in Game State.
signal action_held(action: StringName)
signal focus_gained()
signal device_restored()
signal active_device_changed(kind: int, pad_style: StringName)

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


func hold(action: StringName) -> void:
	action_held.emit(action)


func gain_focus() -> void:
	focus_gained.emit()


func restore_device() -> void:
	device_restored.emit()


func change_active_device(kind: int, pad_style: StringName) -> void:
	active_device_changed.emit(kind, pad_style)
