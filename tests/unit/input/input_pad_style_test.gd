## Pad style from the joy name (story 014, GDD AC-12) and the first pad
## setting the style (story 015, GDD AC-26; ADR-0003 §4, §8). The joy name
## enters through `on_joy_connection(device, true, name)`; the style is
## resolved when that pad becomes the active pad. Expected styles are the
## literal fixture in `fixtures/joy_names.gd`.
extends GdUnitTestSuite

const PAD := InputResolver.DeviceKind.GAMEPAD
const KBM := InputResolver.DeviceKind.KEYBOARD_MOUSE


func _make(config: InputConfig) -> Array:
	var resolver := InputResolver.new(InputTestSupport.default_bindings(), config)
	var rec := InputTestSupport.Recorder.new()
	rec.attach(resolver)
	return [resolver, rec]


func _south(resolver: InputResolver, device: int) -> void:
	resolver.feed_event(InputTestSupport.pad_button(device, JOY_BUTTON_A, true))
	resolver.feed_event(InputTestSupport.pad_button(device, JOY_BUTTON_A, false))


func _changes(rec: InputTestSupport.Recorder) -> Array:
	var out: Array = []
	for entry: Array in rec.since(0):
		if entry[0] == &"active_device_changed":
			out.append(entry[1])
	return out


func _patterns(rows: Array[String]) -> PackedStringArray:
	return PackedStringArray(rows)


# --- Story 014 ---------------------------------------------------------------

## AC-12: each fixture joy name maps to its literal style (case-insensitive
## for the XBOX row; the empty name and an unknown name give generic).
func test_joy_name_maps_to_pad_style(joy_name: String, style: StringName,
		test_parameters := JoyNames.DEFAULT_ROWS) -> void:
	var made: Array = _make(InputTestSupport.DEFAULT)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.on_joy_connection(0, true, joy_name)
	_south(resolver, 0)
	assert_array(_changes(rec)).is_equal([[PAD, style]])
	assert_str(resolver.pad_style).is_equal(style)


## Edge case: the non-default pattern list maps "Acme USB Pad" to nintendo.
func test_non_default_patterns_map_custom_name() -> void:
	var config: InputConfig = InputTestSupport.make_config(
			{"pad_style_patterns": _patterns(JoyNames.CUSTOM_PATTERNS)})
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.on_joy_connection(0, true, JoyNames.CUSTOM_NAME)
	_south(resolver, 0)
	assert_array(_changes(rec)).is_equal([[PAD, JoyNames.CUSTOM_STYLE]])


## Edge case: first match wins.
func test_first_matching_pattern_wins() -> void:
	var config: InputConfig = InputTestSupport.make_config(
			{"pad_style_patterns": _patterns(JoyNames.ORDER_PATTERNS)})
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	resolver.on_joy_connection(0, true, JoyNames.ORDER_NAME)
	_south(resolver, 0)
	assert_str(resolver.pad_style).is_equal(JoyNames.ORDER_STYLE)


## Edge case: a pad that sends input without any on_joy_connection call
## gives generic.
func test_unconnected_pad_gives_generic() -> void:
	var made: Array = _make(InputTestSupport.DEFAULT)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	_south(resolver, 3)
	assert_array(_changes(rec)).is_equal([[PAD, &"generic"]])


# --- Story 015 ---------------------------------------------------------------

## AC-26: pad A (xbox) then pad B (playstation): exactly one
## active_device_changed(GAMEPAD, xbox); pad_style stays xbox; B's confirm
## still emits (two pressed(confirm) in total).
func test_first_pad_sets_style_second_fires_no_change() -> void:
	var made: Array = _make(InputTestSupport.DEFAULT)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.on_joy_connection(0, true, JoyNames.XBOX_NAME)
	resolver.on_joy_connection(1, true, JoyNames.PLAYSTATION_NAME)
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_A, true))
	resolver.feed_event(InputTestSupport.pad_button(1, JOY_BUTTON_A, true))
	assert_array(_changes(rec)).is_equal([[PAD, &"xbox"]])
	assert_str(resolver.pad_style).is_equal(&"xbox")
	assert_int(resolver.active_pad).is_equal(0)
	var confirms: int = 0
	for entry: Array in rec.since(0):
		if entry == [&"action_pressed", [InputActions.CONFIRM]]:
			confirms += 1
	assert_int(confirms).is_equal(2)


## Edge case: device 1's stick past the deadzone also fires nothing.
func test_second_pad_stick_fires_no_change() -> void:
	var made: Array = _make(InputTestSupport.DEFAULT)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.on_joy_connection(0, true, JoyNames.XBOX_NAME)
	resolver.on_joy_connection(1, true, JoyNames.PLAYSTATION_NAME)
	_south(resolver, 0)
	resolver.feed_event(InputTestSupport.pad_axis(1, JOY_AXIS_LEFT_X, 1.0))
	assert_array(_changes(rec)).is_equal([[PAD, &"xbox"]])
	assert_str(resolver.pad_style).is_equal(&"xbox")


## Pinned per-switch re-election: after a key press, pad 1 sending input
## becomes the active pad and emits (GAMEPAD, playstation).
func test_pad_reelected_after_keyboard_interval() -> void:
	var made: Array = _make(InputTestSupport.DEFAULT)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.on_joy_connection(0, true, JoyNames.XBOX_NAME)
	resolver.on_joy_connection(1, true, JoyNames.PLAYSTATION_NAME)
	_south(resolver, 0)
	resolver.feed_event(InputTestSupport.key(KEY_ENTER, true))
	resolver.feed_event(InputTestSupport.key(KEY_ENTER, false))
	_south(resolver, 1)
	assert_array(_changes(rec)).is_equal([[PAD, &"xbox"], [KBM, &"xbox"], [PAD, &"playstation"]])
	assert_int(resolver.active_pad).is_equal(1)
