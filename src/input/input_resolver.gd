## The Input System's logic core (ADR-0003 §1; GDD input-system.md). A pure
## `RefCounted` that owns the compiled binding table, the per-action held set
## and the move vector, with no scene-tree dependency: it never calls `Input`,
## `InputMap`, `get_tree()`, `Time` or `Engine`, and never references an
## autoload. Events, time, focus and joypad connections enter only through
## `feed_event()`, `tick()`, `set_window_focused()` and `on_joy_connection()`.
## It satisfies ADR-0002's `ActionSource` contract directly (`action_pressed`,
## `action_released`, `focus_lost`, `device_lost`, `get_move_vector()`), with
## no adapter.
##
## The binding table is this resolver's own dictionary, matched by
## `physical_keycode` / `JoyButton` / `JoyAxis`, never Godot's `InputMap`
## (ADR-0003 §3). `move_*` are binding-side sub-actions only: a press or
## release of a `move_*` triple is never emitted as `action_pressed` /
## `action_released` -- it only updates `get_move_vector()` (ADR-0003 §8).
##
## This story (001) implements edge detection for the default bindings only.
## `action_held` emission, echo suppression, bindings validation, deadzone
## rescale, per-axis arbitration, active-device tracking, focus/disconnect
## signals and overrides are later stories' concern; every signal they need
## is declared here now so later stories add behaviour, not surface.
##
## Usage example:
## [codeblock]
## var resolver := InputResolver.new(bindings, InputConfig.new())
## resolver.action_pressed.connect(func(action: StringName) -> void: print(action))
## resolver.feed_event(InputEventKey.new())
## [/codeblock]
class_name InputResolver
extends RefCounted

## The active device kind (ADR-0003 Key Interfaces).
enum DeviceKind { KEYBOARD_MOUSE, GAMEPAD }

## Fixed positional gamepad button vocabulary (ADR-0003 §4): engine glue, not
## tuning, so it lives in code, never in data. Public: `InputBindingsValidator`
## (story 003) shares this vocabulary rather than keeping a second copy.
const PAD_BUTTON_TOKENS: Dictionary = {
	"south": JOY_BUTTON_A,
	"east": JOY_BUTTON_B,
	"west": JOY_BUTTON_X,
	"north": JOY_BUTTON_Y,
	"start": JOY_BUTTON_START,
	"back": JOY_BUTTON_BACK,
	"left_shoulder": JOY_BUTTON_LEFT_SHOULDER,
	"right_shoulder": JOY_BUTTON_RIGHT_SHOULDER,
	"dpad_up": JOY_BUTTON_DPAD_UP,
	"dpad_down": JOY_BUTTON_DPAD_DOWN,
	"dpad_left": JOY_BUTTON_DPAD_LEFT,
	"dpad_right": JOY_BUTTON_DPAD_RIGHT,
}

## Fixed positional gamepad axis vocabulary (ADR-0003 §4). The shipped
## defaults use only `left_x`/`left_y`; `right_x`/`right_y` are parsed for
## later data with no code change. Public: `InputBindingsValidator` (story
## 003) shares this vocabulary rather than keeping a second copy.
const PAD_AXIS_TOKENS: Dictionary = {
	"left_x": JOY_AXIS_LEFT_X,
	"left_y": JOY_AXIS_LEFT_Y,
	"right_x": JOY_AXIS_RIGHT_X,
	"right_y": JOY_AXIS_RIGHT_Y,
}

# ActionSource contract (ADR-0002) -- names unchanged.
signal action_pressed(action: StringName)
signal action_released(action: StringName)
signal focus_lost()
signal device_lost()

# Rest of the GDD surface (ADR-0003 Key Interfaces), declared now so later
# stories add behaviour, not surface.
signal action_held(action: StringName)
signal focus_gained()
signal device_restored()
signal active_device_changed(kind: DeviceKind, pad_style: StringName)
signal pointer_confirm(position: Vector2)
signal pointer_cancel(position: Vector2)
signal wheel_step(direction: int)
signal binding_override_discarded(reason: String)

# The project config supplying every tuning value (ADR-0003 §4). Stored for
# later stories' formulas; this story reads none of it yet.
var _config: InputConfig

# Whether the game window currently has focus. No signal fires from this yet
# (story 025); stored so later stories do not need a new field.
var _window_focused: bool = true

# physical_keycode -> action name (discrete or move_*).
var _key_actions: Dictionary = {}
# JoyButton -> action name (discrete or move_*).
var _pad_button_actions: Dictionary = {}
# JoyAxis -> { +1: action name, -1: action name } for the two directions of
# one axis.
var _pad_axis_actions: Dictionary = {}

# Per-action held set, action name -> Dictionary acting as a Set of source
# keys (one entry per physical key/button currently holding that action).
# Discrete actions only -- kept from the start because stories 008 and 016
# rely on it (ADR-0003 Implementation Notes).
var _discrete_held: Dictionary = {}

# Per-move-action source magnitudes, action name -> Dictionary of
# source key -> float level in [0, 1]. get_move_vector() combines these;
# deadzone rescale and per-axis arbitration are later stories' concern.
var _move_sources: Dictionary = {}


func _init(bindings: InputBindings, config: InputConfig) -> void:
	_config = config
	_compile_bindings(bindings)


## Feeds one engine `InputEvent` into the resolver. Only `InputEventKey`,
## `InputEventJoypadButton` and `InputEventJoypadMotion` are matched against
## the binding table in this story; every other event type (including
## `InputEventAction`, per ADR-0003 §5) is ignored with no error.
func feed_event(event: InputEvent) -> void:
	if event is InputEventKey:
		_feed_key(event as InputEventKey)
	elif event is InputEventJoypadButton:
		_feed_pad_button(event as InputEventJoypadButton)
	elif event is InputEventJoypadMotion:
		_feed_pad_axis(event as InputEventJoypadMotion)


## Advances the resolver's own clock by `delta` seconds. This story's `tick()`
## is a no-op placeholder: menu-repeat steps and `action_held` emission are
## story 002's and 018's concern; the method exists now because
## `ActionSource`-style drivers call it every frame.
func tick(_delta: float) -> void:
	pass


## Records whether the game window has focus. This story stores the value
## only; releasing held actions and emitting `focus_lost`/`focus_gained` is
## story 025's concern.
func set_window_focused(focused: bool) -> void:
	_window_focused = focused


## Records a joypad connecting or disconnecting. This story is a no-op
## placeholder; `device_lost`/`device_restored` and active-pad tracking are
## later stories' concern.
func on_joy_connection(_device: int, _connected: bool, _joy_name: String) -> void:
	pass


## The deadzone-rescaled, per-axis-arbitrated, diagonal-normalized move
## vector (ADR-0003 §8). This story combines sources with a simple maximum
## per axis, which already satisfies story 001's AC (a single active source
## per test case); deadzone rescale and arbitration ties are stories 004-006.
## Sign convention (pinned, ADR-0003 §8, Godot's y-down): `move_right` ->
## (+1, 0), `move_left` -> (-1, 0), `move_up` -> (0, -1), `move_down` -> (0, 1).
func get_move_vector() -> Vector2:
	var up: float = _move_level(InputActions.MOVE_UP)
	var down: float = _move_level(InputActions.MOVE_DOWN)
	var left: float = _move_level(InputActions.MOVE_LEFT)
	var right: float = _move_level(InputActions.MOVE_RIGHT)
	return Vector2(right - left, down - up)


## The code-constant fallback bindings for Content Error only (ADR-0003 §7):
## `confirm` (Enter, south), `cancel` (Esc, east), `move` (arrows, d-pad).
## `GameRoot` uses this only when the catalog is `FAILED` -- never a second
## default-bindings source (control manifest, story 003). Deliberately
## incomplete under `InputBindingsValidator`'s "every action has a binding"
## rule (`menu`, `inspect`, `page_left`, `page_right` and `fast_forward` have
## none); only the token-parse and double-bound rules apply to it, so Content
## Error's Quit stays reachable by keyboard and pad as well as mouse.
static func make_fallback_bindings() -> InputBindings:
	var bindings := InputBindings.new()
	bindings.id = "bindings_fallback"
	bindings.bindings = [
		{"action": "confirm", "device": "key", "input": "Enter"},
		{"action": "confirm", "device": "pad", "input": "south"},
		{"action": "cancel", "device": "key", "input": "Escape"},
		{"action": "cancel", "device": "pad", "input": "east"},
		{"action": "move_up", "device": "key", "input": "Up"},
		{"action": "move_up", "device": "pad", "input": "dpad_up"},
		{"action": "move_down", "device": "key", "input": "Down"},
		{"action": "move_down", "device": "pad", "input": "dpad_down"},
		{"action": "move_left", "device": "key", "input": "Left"},
		{"action": "move_left", "device": "pad", "input": "dpad_left"},
		{"action": "move_right", "device": "key", "input": "Right"},
		{"action": "move_right", "device": "pad", "input": "dpad_right"},
	]
	return bindings


# Compiles the binding table once from `bindings.bindings` (Array[Dictionary]
# of {action, device, input}; src/data/records/input_bindings.gd). Keyboard
# resolves through OS.find_keycode_from_string(); pad buttons and axes
# through the fixed positional vocabularies above. A row this story cannot
# resolve (an unknown device, an unparseable key token, device="mouse") is
# silently skipped -- bindings validation is story 003's concern, not this
# resolver's.
func _compile_bindings(bindings: InputBindings) -> void:
	for entry: Dictionary in bindings.bindings:
		var action: StringName = StringName(entry.get("action", ""))
		var device: String = String(entry.get("device", ""))
		var input: String = String(entry.get("input", ""))
		match device:
			"key":
				var code: int = OS.find_keycode_from_string(input)
				if code != KEY_NONE:
					_key_actions[code] = action
			"pad":
				if PAD_BUTTON_TOKENS.has(input):
					_pad_button_actions[PAD_BUTTON_TOKENS[input]] = action
			"pad_axis":
				_compile_axis_binding(action, input)
			_:
				pass


# Parses one `pad_axis` token (e.g. "left_y-") into its JoyAxis and sign, and
# stores the action under that sign. Silently skipped when the token does not
# parse (same rationale as `_compile_bindings()`).
func _compile_axis_binding(action: StringName, token: String) -> void:
	if token.length() < 2:
		return
	var axis_name: String = token.substr(0, token.length() - 1)
	var sign_char: String = token.substr(token.length() - 1)
	if not PAD_AXIS_TOKENS.has(axis_name):
		return
	if sign_char != "+" and sign_char != "-":
		return
	var axis: int = PAD_AXIS_TOKENS[axis_name]
	var sign: int = 1 if sign_char == "+" else -1
	var by_sign: Dictionary = _pad_axis_actions.get(axis, {})
	by_sign[sign] = action
	_pad_axis_actions[axis] = by_sign


# Matches a keyboard event by physical_keycode (never keycode, ADR-0003 §4),
# then routes the resolved action to the discrete or move handler.
func _feed_key(event: InputEventKey) -> void:
	var action: StringName = _key_actions.get(event.physical_keycode, &"")
	if action == &"":
		return
	_apply_edge(action, "key:%d" % event.physical_keycode, event.pressed)


# Matches a gamepad button event by JoyButton, keyed per device so two pads
# holding the same action are tracked as distinct sources (story 008).
func _feed_pad_button(event: InputEventJoypadButton) -> void:
	var action: StringName = _pad_button_actions.get(event.button_index, &"")
	if action == &"":
		return
	_apply_edge(action, "pad:%d:%d" % [event.device, event.button_index], event.pressed)


# Matches a gamepad axis event by JoyAxis. One physical axis feeds both of
# its bound directions at once: the positive part of the raw value feeds the
# "+"-bound action, the negative part (as a magnitude) feeds the "-"-bound
# action, so centering the stick (raw 0.0) clears both.
func _feed_pad_axis(event: InputEventJoypadMotion) -> void:
	var by_sign: Dictionary = _pad_axis_actions.get(event.axis, null)
	if by_sign == null:
		return
	var positive_action: StringName = by_sign.get(1, &"")
	var negative_action: StringName = by_sign.get(-1, &"")
	var positive_level: float = max(event.axis_value, 0.0)
	var negative_level: float = max(-event.axis_value, 0.0)
	if positive_action != &"":
		_apply_move_level(positive_action, "pad_axis:%d:%d:+" % [event.device, event.axis], positive_level)
	if negative_action != &"":
		_apply_move_level(negative_action, "pad_axis:%d:%d:-" % [event.device, event.axis], negative_level)


# Routes one source's press/release to the discrete held-set logic, or to
# the move-vector source logic, depending on the action's kind.
func _apply_edge(action: StringName, source_key: String, pressed: bool) -> void:
	if InputActions.MOVE.has(action):
		_apply_move_level(action, source_key, 1.0 if pressed else 0.0)
	else:
		_apply_discrete_edge(action, source_key, pressed)


# Updates one discrete action's held set and fires action_pressed on the
# set's 0 -> 1 edge, action_released on its 1 -> 0 edge (GDD rule 2 / Edge
# Cases: held until every device releases; released fires once, at the final
# release).
func _apply_discrete_edge(action: StringName, source_key: String, pressed: bool) -> void:
	var holders: Dictionary = _discrete_held.get(action, {})
	var was_held: bool = not holders.is_empty()
	if pressed:
		holders[source_key] = true
	else:
		holders.erase(source_key)
	_discrete_held[action] = holders
	var is_held: bool = not holders.is_empty()
	if is_held and not was_held:
		action_pressed.emit(action)
	elif was_held and not is_held:
		action_released.emit(action)


# Sets or clears one source's contribution to a move_* action's level. A
# level of 0 removes the source entirely, so an action with no remaining
# source reports level 0 from _move_level() without an empty-dictionary check
# at every call site.
func _apply_move_level(action: StringName, source_key: String, level: float) -> void:
	var sources: Dictionary = _move_sources.get(action, {})
	if level > 0.0:
		sources[source_key] = level
	else:
		sources.erase(source_key)
	_move_sources[action] = sources


# The current combined level, in [0, 1], of one move_* action across every
# source holding it.
func _move_level(action: StringName) -> float:
	var sources: Dictionary = _move_sources.get(action, {})
	var level: float = 0.0
	for source_key: String in sources:
		level = max(level, sources[source_key] as float)
	return level
