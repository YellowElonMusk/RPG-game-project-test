## The menu input guard (GDD rule 9 "When a menu opens"; ADR-0008 §6; story
## 058). Pure logic with an injected clock and held-action source: for
## `guard_seconds` (`PresentationConfig.input_guard`) after `open()`, every menu
## action press returns `REFUSE` and emits `refused` once; an action held at
## `open()` returns `SWALLOW` (no feedback) until `on_released()`; releases
## always `PASS`. `open(screen_root)` raises a `GuardBlocker` -- a full-rect
## `MOUSE_FILTER_STOP` plain `Control`, the root's last child -- whose clicks are
## refused presses (`POINTER_ACTION`); `tick()` removes it once the window ends.
##
## Required on the command menu, target selection, the Defeat Prompt and the
## results screen (`MenuDefaultFocus.guarded_screens()`). On `refused`, the
## screen calls `UiFeedback.refuse(focused_control)`.
class_name MenuGuard
extends RefCounted

## A press's verdict.
enum Verdict { PASS, REFUSE, SWALLOW }

## The action name a refused `GuardBlocker` click reports.
const POINTER_ACTION: StringName = &"pointer_click"
## The blocker node's name under the screen root.
const BLOCKER_NAME: StringName = &"GuardBlocker"

## Emitted once per refused press (menu action or blocker click).
signal refused(action: StringName)
## Emitted by every `open()` (connect `PointerFocusSync.reset`).
signal opened

## The guard window, in seconds of the injected clock.
var guard_seconds: float

var _clock: Callable
var _held_now: Callable
var _t_open: float = -INF
var _carried: Dictionary = {}
var _blocker: Control


## `clock.call() -> float` (mode time, seconds); `held_now.call() ->
## Array[StringName]` (actions held this instant, `UiService`'s mirror).
func _init(clock: Callable, held_now: Callable, p_guard_seconds: float) -> void:
	_clock = clock
	_held_now = held_now
	guard_seconds = p_guard_seconds


## Whether `event` is a new physical press: pressed and not an OS key-repeat
## echo (Input rule 2; echoes never count).
static func is_new_press(event: InputEvent) -> bool:
	return event.is_pressed() and not event.is_echo()


## Starts the guard: records `t_open`, snapshots the held actions and raises
## the `GuardBlocker` on `screen_root` (if not null).
func open(screen_root: Control) -> void:
	_t_open = float(_clock.call())
	_carried.clear()
	for action: StringName in _held_now.call():
		_carried[action] = true
	_remove_blocker()
	if screen_root != null:
		_blocker = Control.new()
		_blocker.name = BLOCKER_NAME
		_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
		_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
		_blocker.gui_input.connect(_on_blocker_input)
		screen_root.add_child(_blocker)
	opened.emit()


## The verdict for one menu action event. `pressed == false` is a release:
## always `PASS`, and it also ends that action's carry-over.
func filter(action: StringName, pressed: bool) -> Verdict:
	if not pressed:
		on_released(action)
		return Verdict.PASS
	if _carried.has(action):
		return Verdict.SWALLOW
	if is_guarding():
		refused.emit(action)
		return Verdict.REFUSE
	return Verdict.PASS


## A release of `action` (resolver releases and derived direction releases).
func on_released(action: StringName) -> void:
	_carried.erase(action)


## Whether the guard window is still open.
func is_guarding() -> bool:
	return float(_clock.call()) - _t_open < guard_seconds


## Per-frame upkeep: removes the `GuardBlocker` once the window has passed.
func tick() -> void:
	if not is_guarding():
		_remove_blocker()


func _on_blocker_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and is_new_press(event):
		if is_guarding():
			refused.emit(POINTER_ACTION)
		else:
			_remove_blocker()


func _remove_blocker() -> void:
	if _blocker != null and is_instance_valid(_blocker):
		if _blocker.get_parent() != null:
			_blocker.get_parent().remove_child(_blocker)
		_blocker.free()
	_blocker = null
