## The Input System's engine-facing shell (ADR-0003 §2, §5, §9; story 025).
## The only script that reads engine input or mutates `InputMap`: it strips
## the built-in `ui_*` navigation actions' device bindings, forwards every
## `_input` event to the injected `InputResolver` unconsumed, ticks the
## resolver every frame, and maps focus notifications and
## `Input.joy_connection_changed` onto it. It owns no game logic of its own.
##
## A child of `GameRoot/Services` (not an autoload), with
## `process_mode = PROCESS_MODE_ALWAYS` so a disabled `ModeHost` never stops
## it. `GameRoot`'s boot story (`production/epics/game-state-scene-flow/`)
## constructs it and calls `setup(resolver)` -- the injection seam this story
## pins.
##
## Usage example:
## [codeblock]
## var system := InputSystem.new()
## services.add_child(system)
## system.setup(resolver)
## [/codeblock]
class_name InputSystem
extends Node

## Godot's built-in UI navigation actions stripped of device bindings in
## `_enter_tree()` (ADR-0003 §5), before any `Control` can grab focus.
## `ui_text_*` is deliberately absent -- text fields keep their bindings.
## `ui_select`'s presence on 4.7.2 is unverified (ADR-0003 Engine Notes), so
## each name is guarded with `InputMap.has_action()` rather than assumed.
const _UI_ACTIONS_TO_STRIP: Array[StringName] = [
	&"ui_accept", &"ui_select", &"ui_cancel",
	&"ui_up", &"ui_down", &"ui_left", &"ui_right",
	&"ui_focus_next", &"ui_focus_prev",
	&"ui_page_up", &"ui_page_down", &"ui_home", &"ui_end",
]

# The resolver this shell drives. Null until setup() is called.
var _resolver: InputResolver


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _enter_tree() -> void:
	for action: StringName in _UI_ACTIONS_TO_STRIP:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)


func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)


## Injects the resolver this shell drives and connects
## `Input.joy_connection_changed`. The seam `GameRoot._ready()` calls
## (pinned by this story).
func setup(resolver: InputResolver) -> void:
	_resolver = resolver
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _input(event: InputEvent) -> void:
	if _resolver == null:
		return
	if event is InputEventAction:
		return
	_resolver.feed_event(event)
	# Never call set_input_as_handled(): text fields and the native mouse
	# GUI must still receive every event (ADR-0003 §2).


func _process(delta: float) -> void:
	if _resolver != null:
		_resolver.tick(delta)


func _notification(what: int) -> void:
	if _resolver == null:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_resolver.set_window_focused(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_resolver.set_window_focused(true)


# Maps one joypad connection change onto the resolver, with the device's
# current name (ADR-0003 §2).
func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if _resolver != null:
		_resolver.on_joy_connection(device, connected, Input.get_joy_name(device))
