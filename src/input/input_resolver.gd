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
## Story 001 implements edge detection for the default bindings. Story 002
## adds `action_held` on every `tick()`; stories 004-006 add the digital
## diagonal normalization, the radial deadzone rescale and per-axis
## arbitration; story 008 pins per-source press semantics (every new source
## emits `pressed`, only the last release emits `released`). Active-device
## tracking and overrides are later stories'
## concern; every signal they need is declared here now so later stories add
## behaviour, not surface. Story 025 adds the focus gate (every held action
## released before `focus_lost()`, pad input dropped while unfocused, a
## fresh non-echo press required after `focus_gained()`, and a per-axis
## re-centre latch) and a minimal `device_restored()` on any pad reconnect;
## full disconnect semantics (the active pad, release-before-`device_lost()`)
## remain later stories' concern.
##
## Stories 009-010 add the raw pointer signals (`pointer_confirm`,
## `pointer_cancel`, `wheel_step`, `pointer_position`) from fixed code
## outside the binding table; a pointer never drives `move` or `nav_*`.
## Stories 011-013 and 017 add active-device tracking (`active_device`,
## `active_device_changed`, the device-switch pointer counter, the first
## active pad); story 016 pins that the later of two same-frame events sets
## the kind. Story 020 adds the menu-direction derivation (the stick counts
## past `menu_stick_threshold`, after the rescale) and the `nav_*` step
## stream: step 0 on the press inside `feed_event()`, later steps in `tick()`
## per the GDD `step_time` formula, single stream where the newest direction
## is the held one (story 018/019 readings).
## Story 014 resolves `pad_style` from the joy name stored by
## `on_joy_connection()` through `InputConfig.pad_style_patterns`; story 015
## re-elects the active pad per switch to gamepad; stories 022-024 add the
## disconnect path (the pad's sources released, then `device_lost()` for the
## active pad only, then the kind change) and `device_restored()` on every
## connection; story 026 adds `apply_overrides()`.
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

# Float32 round-trip guard for stick_output()'s deadzone edge: engine
# precision glue, not tuning (axis_value is a 32-bit float, ~1e-8 error).
const _STICK_PRECISION_EPS: float = 1e-6

# Menu-repeat due-time comparison tolerance, in seconds (story 018, pinned:
# fire step k when `elapsed + 1e-9 >= step_time(k)`). Precision glue, not
# tuning.
const _NAV_TIME_EPS: float = 1e-9

# The pad style broadcast until a pad's joy name is matched (GDD Edge Cases:
# an unrecognized pad is `generic`). Story 014 sets real styles.
const _DEFAULT_PAD_STYLE: StringName = &"generic"

# `InputBindings.id` of make_fallback_bindings(): apply_overrides() is
# refused on it (story 026, ADR-0009 §7 guard).
const _FALLBACK_BINDINGS_ID: String = "bindings_fallback"

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

# The project config supplying every tuning value (ADR-0003 §4).
var _config: InputConfig

# The defaults record this resolver was built from; overrides merge over it
# (story 026).
var _bindings: InputBindings

# Joy name per connected pad (device -> String), stored by
# on_joy_connection() so story 014 can resolve the style when that pad
# becomes active.
var _joy_names: Dictionary = {}

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

# Per-move-action DIGITAL sources (keys, pad buttons), action name ->
# Dictionary acting as a Set of source keys. Analog sticks live in _axis_raw.
var _move_sources: Dictionary = {}

# Latest raw stick value per pad per axis ("device:axis" -> float), kept so
# get_move_vector() can apply the radial deadzone on the whole stick vector
# (story 005) and a later story can clear one pad's entries on disconnect.
var _axis_raw: Dictionary = {}

# Per-physical-axis re-centre latch ("device:axis" -> true), set on focus
# loss for every axis then contributing to _move_sources (story 025,
# ADR-0003 §8/§9). While latched, _feed_pad_axis() drops that axis's events
# entirely; the latch clears the moment it reports a value inside
# _config.deadzone, after which it counts again.
var _axis_recentre_latch: Dictionary = {}

# Every gamepad axis's latest raw value, bound or not ("device:axis" ->
# float), so a trigger or unbound stick past the deadzone still counts as
# meaningful input for the active device (GDD rule 4; story 012).
var _device_axis_raw: Dictionary = {}

# The active device kind (GDD States and Transitions: starts keyboard_mouse).
var _active_device: DeviceKind = DeviceKind.KEYBOARD_MOUSE
# The style broadcast with active_device_changed (story 014 sets it).
var _pad_style: StringName = _DEFAULT_PAD_STYLE
# Device ID of the first pad to send meaningful input, or -1 (story 012;
# used by stories 015 and 022).
var _active_pad: int = -1
# The device-switch pointer counter: summed |relative| of mouse motion since
# the last non-mouse meaningful input or active-device change (story 017).
# Not the UI's hover-focus counter (ADR-0008 §6), which shares no state.
var _pointer_distance: float = 0.0
# Latest pointer position from any mouse motion or button event (story 009).
var _pointer_position: Vector2 = Vector2.ZERO

# Menu-repeat stream (story 020, with story 018/019 readings): the current
# held menu direction (ZERO = none), seconds since its press, and the index
# of the next due step. `_nav_active` is the set of menu directions active
# after the previous update, so a direction counts as pressed only when it
# newly appears.
var _nav_dir: Vector2i = Vector2i.ZERO
var _nav_elapsed: float = 0.0
var _nav_next_k: int = 0
var _nav_active: Array[Vector2i] = []


## The active device kind (GDD rule 4, ADR-0003 §8). Starts `KEYBOARD_MOUSE`.
var active_device: DeviceKind:
	get:
		return _active_device


## Device ID of the first pad that sent meaningful input, or -1 if none has
## (story 012; stories 015 and 022 consume it).
var active_pad: int:
	get:
		return _active_pad


## The style of the active pad (story 014): `xbox`, `playstation`,
## `nintendo` or `generic`. Unchanged when the kind switches to
## keyboard_mouse.
var pad_style: StringName:
	get:
		return _pad_style


## The latest pointer position, from every `InputEventMouseMotion` and
## `InputEventMouseButton` (story 009, ADR-0008 §6 polls it).
var pointer_position: Vector2:
	get:
		return _pointer_position


func _init(bindings: InputBindings, config: InputConfig) -> void:
	_config = config
	_bindings = bindings
	_compile_bindings(bindings.bindings)


## Feeds one engine `InputEvent` into the resolver. Only `InputEventKey`,
## `InputEventJoypadButton` and `InputEventJoypadMotion` are matched against
## the binding table. Mouse events drive only the raw pointer signals and the
## active device, never `move` or `nav_*` (stories 009-010). Every other
## event type (including `InputEventAction`, per ADR-0003 §5) is ignored with
## no error. Key echo events are ignored (story 025/ADR-0003 §8: a
## still-held key needs a fresh non-echo press). While the window is
## unfocused, every gamepad event is dropped (ADR-0003 §9); keyboard events
## are still processed normally. The device kind is classified by event type,
## never by `event.device == 0` (story 011). An `active_device_changed`
## caused by an event fires before that event's action signals.
func feed_event(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			_note_meaningful(DeviceKind.KEYBOARD_MOUSE, -1, false)
		_feed_key(key_event)
		_update_nav()
	elif event is InputEventJoypadButton:
		if _window_focused:
			var button_event := event as InputEventJoypadButton
			if button_event.pressed:
				_note_meaningful(DeviceKind.GAMEPAD, button_event.device, false)
			_feed_pad_button(button_event)
			_update_nav()
	elif event is InputEventJoypadMotion:
		if _window_focused:
			_feed_pad_axis(event as InputEventJoypadMotion)
			_update_nav()
	elif event is InputEventMouseButton:
		_feed_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_feed_mouse_motion(event as InputEventMouseMotion)


## Advances the resolver's own clock by `delta` seconds. Emits
## `action_held(action)` exactly once per discrete action currently held, by
## however many sources (story 002/008, ADR-0003 §8). `held` never comes from
## device events, so a tap pressed and released between two ticks emits no
## `held`. Then advances the menu-repeat stream: every `nav_*` step whose
## `step_time(k)` is now due fires, in k order, each as its own
## `action_pressed` (story 018 catch-up, never merged).
func tick(delta: float) -> void:
	for action: StringName in _discrete_held.keys():
		var holders: Dictionary = _discrete_held[action]
		if not holders.is_empty():
			action_held.emit(action)
	if _nav_dir == Vector2i.ZERO:
		return
	_nav_elapsed += delta
	while _nav_elapsed + _NAV_TIME_EPS >= step_time(_nav_next_k, _config):
		_emit_nav_step(_nav_dir)
		_nav_next_k += 1


## The menu-repeat due time of step `k` (GDD Formulas, `step_time`): 0 for
## k = 0, else `repeat_delay + (k - 1) * repeat_interval`.
static func step_time(k: int, config: InputConfig) -> float:
	if k <= 0:
		return 0.0
	return config.repeat_delay + float(k - 1) * config.repeat_interval


## Sets whether the game window has focus (ADR-0003 §8/§9; AC-17). Losing
## focus releases every held discrete action (`action_released` for each, in
## no guaranteed order) and latches every then-active gamepad axis, both
## before `focus_lost()` fires; `get_move_vector()` reports `Vector2.ZERO`
## while unfocused. Regaining focus emits `focus_gained()` exactly once. A
## call that repeats the current value is a no-op (no duplicate signal).
func set_window_focused(focused: bool) -> void:
	if focused == _window_focused:
		return
	_window_focused = focused
	if focused:
		# Still-held move keys need a fresh press before stepping again.
		_nav_active = _menu_directions()
		focus_gained.emit()
	else:
		_release_all_held_actions()
		_latch_active_axes()
		_update_nav()
		focus_lost.emit()


## Records a joypad connecting or disconnecting (ADR-0003 §8).
## A connection stores `joy_name` for the pad-style lookup (story 014) and
## emits `device_restored()` for any pad, active or not, focused or not,
## including the first connection at boot (story 024 pinned reading).
## A disconnect (stories 022, 023) removes every held-set source of
## `device`, emitting `action_released` for each action whose set becomes
## empty (hold order), zeroes that pad's axes and re-derives the menu
## repeat. Then, only if `device` is the active pad, the active pad is
## cleared, `device_lost()` fires, then `active_device_changed(
## KEYBOARD_MOUSE, <unchanged pad_style>)`.
func on_joy_connection(device: int, connected: bool, joy_name: String) -> void:
	if connected:
		_joy_names[device] = joy_name
		device_restored.emit()
		return
	_joy_names.erase(device)
	var prefix: String = "pad:%d:" % device
	for action: StringName in _discrete_held.keys():
		var holders: Dictionary = _discrete_held[action]
		var had_any: bool = not holders.is_empty()
		for source_key: String in holders.keys():
			if source_key.begins_with(prefix):
				holders.erase(source_key)
		if had_any and holders.is_empty():
			action_released.emit(action)
	for action: StringName in _move_sources.keys():
		var sources: Dictionary = _move_sources[action]
		for source_key: String in sources.keys():
			if source_key.begins_with(prefix):
				sources.erase(source_key)
	var axis_prefix: String = "%d:" % device
	for table: Dictionary in [_axis_raw, _device_axis_raw, _axis_recentre_latch]:
		for axis_key: String in table.keys():
			if axis_key.begins_with(axis_prefix):
				table.erase(axis_key)
	_update_nav()
	if device != _active_pad:
		return
	_active_pad = -1
	device_lost.emit()
	if _active_device == DeviceKind.GAMEPAD:
		_active_device = DeviceKind.KEYBOARD_MOUSE
		_pointer_distance = 0.0
		active_device_changed.emit(_active_device, _pad_style)


## The pad style for `joy_name` (story 014, ADR-0003 §4): the style of the
## first `"substring:style"` entry of `patterns` whose substring occurs in
## the name, case-insensitively; `generic` when none matches (including an
## empty name). An entry with no `:` is skipped.
static func resolve_pad_style(joy_name: String, patterns: PackedStringArray) -> StringName:
	var lowered: String = joy_name.to_lower()
	if lowered.is_empty():
		return _DEFAULT_PAD_STYLE
	for entry: String in patterns:
		var split_at: int = entry.rfind(":")
		if split_at <= 0:
			continue
		var needle: String = entry.substr(0, split_at).to_lower()
		if lowered.contains(needle):
			return StringName(entry.substr(split_at + 1))
	return _DEFAULT_PAD_STYLE


## Applies the player's binding overrides (story 026; ADR-0003 §3, ADR-0009
## §7): `"action:device:input"` triples merged over the defaults record
## (`merge_overrides()`) and validated with `InputBindingsValidator`'s
## rules. Valid: the binding table is recompiled, with no engine-global
## mutation. Invalid: the defaults table stays untouched and
## `binding_override_discarded(reason)` fires exactly once, however many
## triples are bad. An empty array is a no-op with no signal. Refused with a
## warning and no signal on the fallback bindings (GameRoot never calls it
## there; defensive guard).
func apply_overrides(overrides: PackedStringArray) -> void:
	if overrides.is_empty():
		return
	if _bindings.id == _FALLBACK_BINDINGS_ID:
		push_warning("InputResolver.apply_overrides ignored on fallback bindings")
		return
	var merged: Array[Dictionary] = merge_overrides(_bindings.bindings, overrides)
	var errors: Array[Dictionary] = InputBindingsValidator.validate_rows(merged)
	if not errors.is_empty():
		var fields: PackedStringArray = PackedStringArray()
		for error: Dictionary in errors:
			fields.append(String(error.get("field", "")))
		binding_override_discarded.emit("invalid binding override: %s" % ", ".join(fields))
		return
	_compile_bindings(merged)


## The override merge step, isolated so the open add-vs-replace ruling
## changes one place (story 026 OPEN item). Current reading: each override
## triple replaces the default rows of its own action and device, then is
## appended. A triple that does not split into three parts is appended with
## the parts it has, which the validator then rejects.
static func merge_overrides(defaults: Array, overrides: PackedStringArray) -> Array[Dictionary]:
	var parsed: Array[Dictionary] = []
	for triple: String in overrides:
		var parts: PackedStringArray = triple.split(":", true, 2)
		parsed.append({
			"action": parts[0] if parts.size() > 0 else "",
			"device": parts[1] if parts.size() > 1 else "",
			"input": parts[2] if parts.size() > 2 else "",
		})
	var rows: Array[Dictionary] = []
	for row: Dictionary in defaults:
		var replaced: bool = false
		for override: Dictionary in parsed:
			if override["device"] != "" and row.get("action", "") == override["action"] \
					and row.get("device", "") == override["device"]:
				replaced = true
		if not replaced:
			rows.append(row.duplicate())
	rows.append_array(parsed)
	return rows


## The deadzone-rescaled, per-axis-arbitrated, diagonal-normalized move
## vector (ADR-0003 §8; GDD rule 6, Formulas, Edge Cases). Per axis, the
## digital term is +1 for any positive key/button held plus -1 for any
## negative one (so opposites cancel to 0); the analog term is the pad stick,
## after `stick_output()`, with the larger absolute value. The term with the
## larger absolute value wins the axis; on a tie the digital term wins
## (story 006). A digital 0 from cancellation counts as magnitude 0, so a
## deflected stick wins that axis (QL-STORY-READY 2026-10-23 reading). The
## result is normalized last, only when its length exceeds 1 (story 004).
## Sign convention (pinned, ADR-0003 §8, Godot's y-down): `move_right` ->
## (+1, 0), `move_left` -> (-1, 0), `move_up` -> (0, -1), `move_down` -> (0, 1).
## Returns `Vector2.ZERO` while the window is unfocused (ADR-0003 §9).
func get_move_vector() -> Vector2:
	if not _window_focused:
		return Vector2.ZERO
	var digital := Vector2(
			_digital_level(InputActions.MOVE_RIGHT) - _digital_level(InputActions.MOVE_LEFT),
			_digital_level(InputActions.MOVE_DOWN) - _digital_level(InputActions.MOVE_UP))
	var analog: Vector2 = _analog_vector()
	var result := Vector2(
			analog.x if absf(analog.x) > absf(digital.x) else digital.x,
			analog.y if absf(analog.y) > absf(digital.y) else digital.y)
	if result.length() > 1.0:
		result = result.normalized()
	return result


## The radial deadzone rescale (GDD Formulas, `stick_output`; ADR-0003 §4):
## 0 when `|raw| < deadzone`, else `raw / |raw| * min(1, (|raw| - deadzone) /
## (1 - deadzone))`. Applied to the vector's magnitude, never per axis, so a
## diagonal keeps its direction; `|raw| == deadzone` gives 0 from both
## branches and `|raw| > 1` is clamped to length 1. `|raw|` within
## `_STICK_PRECISION_EPS` of the deadzone counts as on the edge, because
## `InputEventJoypadMotion.axis_value` is stored as a 32-bit float (0.2
## reads back as 0.2000000030), so a stick reported exactly at the deadzone
## must still give 0.
static func stick_output(raw: Vector2, deadzone: float) -> Vector2:
	var magnitude: float = raw.length()
	if magnitude <= deadzone + _STICK_PRECISION_EPS or magnitude == 0.0:
		return Vector2.ZERO
	return raw / magnitude * minf(1.0, (magnitude - deadzone) / (1.0 - deadzone))


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
func _compile_bindings(rows: Array) -> void:
	_key_actions.clear()
	_pad_button_actions.clear()
	_pad_axis_actions.clear()
	for entry: Dictionary in rows:
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
# then routes the resolved action to the discrete or move handler. Echo
# events are ignored (story 025): a held key only ever re-arrives as echoes
# then a release, so skipping them here is what makes a still-held key need
# a fresh press after focus returns.
func _feed_key(event: InputEventKey) -> void:
	if event.echo:
		return
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


# Matches a gamepad axis event by JoyAxis and stores its latest raw value
# per pad per axis (story 005). The direction mapping and the radial
# deadzone are applied in get_move_vector(), on the whole stick vector.
func _feed_pad_axis(event: InputEventJoypadMotion) -> void:
	var axis_key: String = "%d:%d" % [event.device, event.axis]
	if _axis_recentre_latch.get(axis_key, false):
		if absf(event.axis_value) <= _config.deadzone:
			_axis_recentre_latch.erase(axis_key)
		return
	_device_axis_raw[axis_key] = event.axis_value
	if _axis_is_meaningful(event.device, event.axis):
		_note_meaningful(DeviceKind.GAMEPAD, event.device, false)
	if not _pad_axis_actions.has(event.axis):
		return
	if event.axis_value == 0.0:
		_axis_raw.erase(axis_key)
	else:
		_axis_raw[axis_key] = event.axis_value


# Routes one source's press/release to the discrete held-set logic, or to
# the move-vector source logic, depending on the action's kind.
func _apply_edge(action: StringName, source_key: String, pressed: bool) -> void:
	if InputActions.MOVE.has(action):
		_apply_move_digital(action, source_key, pressed)
	else:
		_apply_discrete_edge(action, source_key, pressed)


# Updates one discrete action's held set (story 002/008 edge rules, AC-19/
# AC-27 ruling 2026-10-23): action_pressed fires for every press of a source
# not already in the set, so a second device pressing a held action does
# emit it; a repeat press of a source already in the set (a repeat not
# flagged echo, a duplicate pad report) is a no-op; action_released fires
# only when the set becomes empty, at the final release. A release of a
# source not in the set is ignored.
func _apply_discrete_edge(action: StringName, source_key: String, pressed: bool) -> void:
	var holders: Dictionary = _discrete_held.get(action, {})
	if pressed:
		if holders.has(source_key):
			return
		holders[source_key] = true
		_discrete_held[action] = holders
		action_pressed.emit(action)
	else:
		if not holders.has(source_key):
			return
		holders.erase(source_key)
		_discrete_held[action] = holders
		if holders.is_empty():
			action_released.emit(action)


# Adds or removes one digital source (key, pad button) of a move_* action.
func _apply_move_digital(action: StringName, source_key: String, pressed: bool) -> void:
	var sources: Dictionary = _move_sources.get(action, {})
	if pressed:
		sources[source_key] = true
	else:
		sources.erase(source_key)
	_move_sources[action] = sources


# 1.0 if any digital source holds this move_* action, else 0.0 (digital
# sources are magnitude 1 per axis, story 004).
func _digital_level(action: StringName) -> float:
	var sources: Dictionary = _move_sources.get(action, {})
	return 0.0 if sources.is_empty() else 1.0


# The analog move term: each pad's raw stick vector (every bound pad_axis,
# mapped through its move_* direction) rescaled by stick_output(); per axis,
# the pad with the larger absolute rescaled value wins (story 006).
func _analog_vector() -> Vector2:
	var raw_by_device: Dictionary = {}
	for axis_key: String in _axis_raw:
		var parts: PackedStringArray = axis_key.split(":")
		var device: int = int(parts[0])
		var by_sign: Dictionary = _pad_axis_actions.get(int(parts[1]), {})
		var value: float = _axis_raw[axis_key]
		var sign: int = 1 if value > 0.0 else -1
		var action: StringName = by_sign.get(sign, &"")
		var raw: Vector2 = raw_by_device.get(device, Vector2.ZERO)
		raw += _move_direction(action) * absf(value)
		raw_by_device[device] = raw
	var best := Vector2.ZERO
	for device: int in raw_by_device:
		var out: Vector2 = stick_output(raw_by_device[device], _config.deadzone)
		if absf(out.x) > absf(best.x):
			best.x = out.x
		if absf(out.y) > absf(best.y):
			best.y = out.y
	return best


# The unit vector of one move_* action (pinned y-down sign convention), or
# ZERO for any other action.
static func _move_direction(action: StringName) -> Vector2:
	if action == InputActions.MOVE_UP:
		return Vector2.UP
	if action == InputActions.MOVE_DOWN:
		return Vector2.DOWN
	if action == InputActions.MOVE_LEFT:
		return Vector2.LEFT
	if action == InputActions.MOVE_RIGHT:
		return Vector2.RIGHT
	return Vector2.ZERO


# Releases every currently-held discrete action, emitting `action_released`
# for each (ADR-0003 §8: every release fires before `focus_lost`/
# `device_lost`).
func _release_all_held_actions() -> void:
	for action: StringName in _discrete_held.keys():
		var holders: Dictionary = _discrete_held[action]
		if not holders.is_empty():
			_discrete_held[action] = {}
			action_released.emit(action)


# Latches every gamepad axis currently reporting a non-zero raw value
# (story 025): its stored value is cleared immediately, as if centered, and
# the latch set here makes _feed_pad_axis() ignore that physical axis until a
# later event reports it inside the deadzone.
func _latch_active_axes() -> void:
	for axis_key: String in _axis_raw.keys():
		_axis_recentre_latch[axis_key] = true
	_axis_raw.clear()


# Raw pointer buttons (story 009, ADR-0003 §5/§8): fixed code, never the
# binding table. Left/right fire on the press edge only with the event
# position; each wheel up/down press is one step (+1/-1, `factor` ignored);
# releases, middle, X1/X2 and wheel left/right emit no pointer signal. Any
# button press is a mouse click for the active device (GDD rule 4).
func _feed_mouse_button(event: InputEventMouseButton) -> void:
	_pointer_position = event.position
	if not event.pressed:
		return
	_note_meaningful(DeviceKind.KEYBOARD_MOUSE, -1, true)
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			pointer_confirm.emit(event.position)
		MOUSE_BUTTON_RIGHT:
			pointer_cancel.emit(event.position)
		MOUSE_BUTTON_WHEEL_UP:
			wheel_step.emit(1)
		MOUSE_BUTTON_WHEEL_DOWN:
			wheel_step.emit(-1)
		_:
			pass


# Accumulates the device-switch pointer counter (stories 012, 017); reaching
# `pointer_switch_px` is meaningful keyboard_mouse input.
func _feed_mouse_motion(event: InputEventMouseMotion) -> void:
	_pointer_position = event.position
	_pointer_distance += event.relative.length()
	if _pointer_distance >= float(_config.pointer_switch_px):
		_note_meaningful(DeviceKind.KEYBOARD_MOUSE, -1, true)


# Records one meaningful input of `kind` (GDD rule 4). Non-mouse input resets
# the pointer counter; a change of kind resets it too and emits
# `active_device_changed` once, at this event (stories 012, 017). The first
# pad to send meaningful input after a switch to gamepad becomes the active
# pad and sets `pad_style` from its stored joy name (stories 014, 015
# per-switch re-election); a switch to keyboard_mouse clears the active pad
# but keeps `pad_style`.
func _note_meaningful(kind: DeviceKind, pad_device: int, from_mouse: bool) -> void:
	if not from_mouse:
		_pointer_distance = 0.0
	if kind == DeviceKind.GAMEPAD and _active_pad == -1:
		_active_pad = pad_device
		_pad_style = resolve_pad_style(String(_joy_names.get(pad_device, "")),
				_config.pad_style_patterns)
	if kind == _active_device:
		return
	if kind == DeviceKind.KEYBOARD_MOUSE:
		_active_pad = -1
	_active_device = kind
	_pointer_distance = 0.0
	active_device_changed.emit(kind, _pad_style)


# Whether `axis` on `device` is past its deadzone (stories 012, 013): a stick
# axis counts when its whole stick vector (x and y of the same stick) gives a
# non-zero `stick_output()`, so diagonal drift inside the deadzone never
# counts; a trigger counts when its value exceeds the deadzone.
func _axis_is_meaningful(device: int, axis: int) -> bool:
	var x_axis: int = -1
	var y_axis: int = -1
	if axis == JOY_AXIS_LEFT_X or axis == JOY_AXIS_LEFT_Y:
		x_axis = JOY_AXIS_LEFT_X
		y_axis = JOY_AXIS_LEFT_Y
	elif axis == JOY_AXIS_RIGHT_X or axis == JOY_AXIS_RIGHT_Y:
		x_axis = JOY_AXIS_RIGHT_X
		y_axis = JOY_AXIS_RIGHT_Y
	else:
		var trigger: float = _device_axis_raw.get("%d:%d" % [device, axis], 0.0)
		return trigger > _config.deadzone + _STICK_PRECISION_EPS
	var raw := Vector2(
			_device_axis_raw.get("%d:%d" % [device, x_axis], 0.0),
			_device_axis_raw.get("%d:%d" % [device, y_axis], 0.0))
	return stick_output(raw, _config.deadzone) != Vector2.ZERO


# The menu directions currently held (stories 018, 020): per axis, the
# arbitrated winner of the digital and analog terms (story 006, before the
# diagonal normalization). A digital winner counts whenever non-zero; an
# analog winner counts only when its rescaled component is past
# `menu_stick_threshold` (per axis, never the vector length; GDD Tuning
# Knobs). Empty while unfocused.
func _menu_directions() -> Array[Vector2i]:
	var dirs: Array[Vector2i] = []
	if not _window_focused:
		return dirs
	var digital := Vector2(
			_digital_level(InputActions.MOVE_RIGHT) - _digital_level(InputActions.MOVE_LEFT),
			_digital_level(InputActions.MOVE_DOWN) - _digital_level(InputActions.MOVE_UP))
	var analog: Vector2 = _analog_vector()
	for axis: int in [0, 1]:
		var dig: float = digital[axis]
		var ana: float = analog[axis]
		var value: float = dig
		if absf(ana) > absf(dig):
			value = ana if absf(ana) > _config.menu_stick_threshold else 0.0
		if value != 0.0:
			var dir := Vector2i.ZERO
			dir[axis] = 1 if value > 0.0 else -1
			dirs.append(dir)
	return dirs


# Re-derives the menu directions after an input changed them. A newly
# appearing direction is a press: it becomes the stream's direction and
# fires step 0 now. If the stream's direction disappears while another one
# remains, the remaining one restarts the stream (GDD Edge Cases: "a single
# direction remains"); with none left, repeat stops. `nav_*` never enter
# the held set, so nothing is ever released for them.
func _update_nav() -> void:
	var dirs: Array[Vector2i] = _menu_directions()
	var appeared: Array[Vector2i] = []
	for dir: Vector2i in dirs:
		if not _nav_active.has(dir):
			appeared.append(dir)
	_nav_active = dirs
	if not appeared.is_empty():
		_start_nav(appeared.back())
	elif _nav_dir != Vector2i.ZERO and not dirs.has(_nav_dir):
		if dirs.is_empty():
			_nav_dir = Vector2i.ZERO
		else:
			_start_nav(dirs.back())


# Starts the step stream on `dir`, firing step k = 0 immediately.
func _start_nav(dir: Vector2i) -> void:
	_nav_dir = dir
	_nav_elapsed = 0.0
	_nav_next_k = 1
	_emit_nav_step(dir)


# Emits one menu step as `action_pressed(nav_*)` (never held or released).
func _emit_nav_step(dir: Vector2i) -> void:
	if dir == Vector2i.UP:
		action_pressed.emit(InputActions.NAV_UP)
	elif dir == Vector2i.DOWN:
		action_pressed.emit(InputActions.NAV_DOWN)
	elif dir == Vector2i.LEFT:
		action_pressed.emit(InputActions.NAV_LEFT)
	elif dir == Vector2i.RIGHT:
		action_pressed.emit(InputActions.NAV_RIGHT)
