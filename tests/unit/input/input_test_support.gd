## Shared Input System test support (ADR-0003 Implementation Notes; story
## 001), used by every test in `tests/unit/input/`. Provides a signal
## recorder, synthetic event factories, a config factory and the shared
## `DEFAULT`/`NON_DEFAULT` config constants and tolerances every later Input
## story reuses, so no test picks its own tolerance or config values.
## Carries a `class_name` (like `MigratedRecordsExpected`) rather than staying
## preload-only, because every Input story references it directly.
##
## Usage example:
## [codeblock]
## var rec := InputTestSupport.Recorder.new()
## var resolver := InputResolver.new(InputTestSupport.default_bindings(), InputTestSupport.DEFAULT)
## rec.attach(resolver)
## resolver.feed_event(InputTestSupport.key(KEY_ENTER, true))
## assert_array(rec.since(0)).contains_exactly([[&"action_pressed", [InputActions.CONFIRM]]])
## [/codeblock]
class_name InputTestSupport
extends RefCounted

## Vector comparison tolerance (GDD Acceptance Criteria harness).
const EPS_V: float = 1e-6
## Tick-time comparison tolerance, in seconds (GDD AC-7).
const EPS_T: float = 1e-9
## The harness's fixed tick (GDD AC-7): Δt = 1/60 s.
const DT: float = 1.0 / 60.0


## Records every signal a resolver emits, in order, as `[signal_name, args]`
## pairs. `since(mark)` lets a test ignore setup noise by recording a mark
## before acting and reading only what happened after it.
class Recorder:
	extends RefCounted

	var entries: Array = []

	func attach(resolver: InputResolver) -> void:
		resolver.action_pressed.connect(_on_action_pressed)
		resolver.action_released.connect(_on_action_released)
		resolver.action_held.connect(_on_action_held)
		resolver.focus_lost.connect(_on_focus_lost)
		resolver.focus_gained.connect(_on_focus_gained)
		resolver.device_lost.connect(_on_device_lost)
		resolver.device_restored.connect(_on_device_restored)
		resolver.active_device_changed.connect(_on_active_device_changed)
		resolver.pointer_confirm.connect(_on_pointer_confirm)
		resolver.pointer_cancel.connect(_on_pointer_cancel)
		resolver.wheel_step.connect(_on_wheel_step)
		resolver.binding_override_discarded.connect(_on_binding_override_discarded)

	## The number of entries recorded so far -- a mark to pass to `since()`.
	func mark() -> int:
		return entries.size()

	## Every entry recorded after `mark_index` (exclusive), in order.
	func since(mark_index: int) -> Array:
		return entries.slice(mark_index)

	func _on_action_pressed(action: StringName) -> void:
		entries.append([&"action_pressed", [action]])

	func _on_action_released(action: StringName) -> void:
		entries.append([&"action_released", [action]])

	func _on_action_held(action: StringName) -> void:
		entries.append([&"action_held", [action]])

	func _on_focus_lost() -> void:
		entries.append([&"focus_lost", []])

	func _on_focus_gained() -> void:
		entries.append([&"focus_gained", []])

	func _on_device_lost() -> void:
		entries.append([&"device_lost", []])

	func _on_device_restored() -> void:
		entries.append([&"device_restored", []])

	func _on_active_device_changed(kind: InputResolver.DeviceKind, pad_style: StringName) -> void:
		entries.append([&"active_device_changed", [kind, pad_style]])

	func _on_pointer_confirm(position: Vector2) -> void:
		entries.append([&"pointer_confirm", [position]])

	func _on_pointer_cancel(position: Vector2) -> void:
		entries.append([&"pointer_cancel", [position]])

	func _on_wheel_step(direction: int) -> void:
		entries.append([&"wheel_step", [direction]])

	func _on_binding_override_discarded(reason: String) -> void:
		entries.append([&"binding_override_discarded", [reason]])


## A synthetic keyboard event. `physical_keycode` is always set (and
## `keycode` always left at `KEY_NONE`), so a resolver that wrongly matched on
## `keycode` fails against this fixture (ADR-0003 §4, story 001 QA edge case).
static func key(physical_keycode: int, pressed: bool, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode as Key
	event.pressed = pressed
	event.echo = echo
	return event


## A synthetic gamepad button event for `device`.
static func pad_button(device: int, button_index: int, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button_index as JoyButton
	event.pressed = pressed
	return event


## A synthetic gamepad axis event for `device`. Press = `pad_axis(0, axis,
## ±1.0)`, release = `pad_axis(0, axis, 0.0)` (ADR-0003 Implementation Notes).
static func pad_axis(device: int, axis: int, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis as JoyAxis
	event.axis_value = value
	return event


## A synthetic mouse button event.
static func mouse_button(button_index: int, pressed: bool, position: Vector2 = Vector2.ZERO) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index as MouseButton
	event.pressed = pressed
	event.position = position
	return event


## A synthetic mouse motion event carrying only the relative movement later
## stories need for cumulative pointer distance.
static func mouse_motion(relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	return event


## An `InputConfig` with `overrides` applied over the declared defaults.
## Example: [code]InputTestSupport.make_config({"deadzone": 0.25})[/code]
static func make_config(overrides: Dictionary) -> InputConfig:
	var config := InputConfig.new()
	for field: String in overrides:
		config.set(field, overrides[field])
	return config


## The shipped `bindings_default` record, loaded fresh (never cached, never
## through `ContentCatalog`) so a test can mutate its copy freely.
static func default_bindings() -> InputBindings:
	return ResourceLoader.load("res://data/bindings/bindings_default.tres", "",
			ResourceLoader.CACHE_MODE_IGNORE) as InputBindings


## The declared-default config, equal to the GDD's defaults.
static var DEFAULT: InputConfig = InputConfig.new()

## A single non-default config, every value inside the GDD's Tuning Knob
## safe range (ADR-0003 Implementation Notes): every "runs once with a
## non-default config" clause in this epic means this constant.
static var NON_DEFAULT: InputConfig = make_config({
	"deadzone": 0.25,
	"repeat_delay": 0.30,
	"repeat_interval": 0.07,
	"menu_stick_threshold": 0.50,
	"pointer_switch_px": 12,
})
