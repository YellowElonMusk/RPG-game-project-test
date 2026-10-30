## Active-device switching (ADR-0003 §1, §8; GDD rule 4, Edge Cases).
## Story 012, AC-10: one `active_device_changed` per meaningful switch (key
## then pad button; stick past the deadzone; mouse click; cumulative motion
## reaching `pointer_switch_px`). Story 013, AC-11: none for stick drift,
## motion below `pointer_switch_px`, or a second input of the active kind.
## Story 017, AC-28: the pointer counter restarts from zero after a switch.
## Every value derives from config; each case runs with DEFAULT and NON_DEFAULT.
extends GdUnitTestSuite

const KBM := InputResolver.DeviceKind.KEYBOARD_MOUSE
const PAD := InputResolver.DeviceKind.GAMEPAD

const _CONFIGS: Array = [["default"], ["non_default"]]

# Drift margin below the deadzone (story 013: `deadzone - 1e-3`).
const _DRIFT_MARGIN: float = 1e-3


func _cfg(config_name: String) -> InputConfig:
	return InputTestSupport.DEFAULT if config_name == "default" else InputTestSupport.NON_DEFAULT


func _make(config: InputConfig) -> Array:
	var resolver := InputResolver.new(InputTestSupport.default_bindings(), config)
	var rec := InputTestSupport.Recorder.new()
	rec.attach(resolver)
	return [resolver, rec]


func _pad_press(resolver: InputResolver, device: int = 0) -> void:
	resolver.feed_event(InputTestSupport.pad_button(device, JOY_BUTTON_A, true))
	resolver.feed_event(InputTestSupport.pad_button(device, JOY_BUTTON_A, false))


# Feeds `total` px of motion as one-pixel events (proves accumulation).
func _move_px(resolver: InputResolver, total: int) -> void:
	for i: int in total:
		resolver.feed_event(InputTestSupport.mouse_motion(Vector2(-1.0, 0.0)))


# --- Story 012 ---------------------------------------------------------------

func test_key_then_pad_button_emits_one_gamepad_change(config_name: String,
		test_parameters := _CONFIGS) -> void:
	var made: Array = _make(_cfg(config_name))
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.feed_event(InputTestSupport.key(KEY_ENTER, true))
	resolver.feed_event(InputTestSupport.key(KEY_ENTER, false))
	_pad_press(resolver)
	assert_array(rec.device_changes_since(0)).is_equal([PAD])
	assert_int(resolver.active_device).is_equal(PAD)


func test_stick_past_deadzone_emits_one_gamepad_change(config_name: String,
		test_parameters := _CONFIGS) -> void:
	var config: InputConfig = _cfg(config_name)
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	var past: float = config.deadzone + (1.0 - config.deadzone) * 0.1
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, past))
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, past + 0.05))
	assert_array(rec.device_changes_since(0)).is_equal([PAD])


## Edge case: an unbound trigger past the deadzone also counts.
func test_trigger_past_deadzone_emits_one_gamepad_change(config_name: String,
		test_parameters := _CONFIGS) -> void:
	var config: InputConfig = _cfg(config_name)
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_TRIGGER_RIGHT, config.deadzone + 0.1))
	assert_array(rec.device_changes_since(0)).is_equal([PAD])


func test_mouse_click_emits_one_keyboard_mouse_change(config_name: String,
		test_parameters := _CONFIGS) -> void:
	var made: Array = _make(_cfg(config_name))
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	_pad_press(resolver)
	var mark: int = rec.mark()
	resolver.feed_event(InputTestSupport.mouse_button(MOUSE_BUTTON_LEFT, true))
	resolver.feed_event(InputTestSupport.mouse_button(MOUSE_BUTTON_LEFT, false))
	assert_array(rec.device_changes_since(mark)).is_equal([KBM])


func test_motion_reaching_switch_px_emits_one_keyboard_mouse_change(config_name: String,
		test_parameters := _CONFIGS) -> void:
	var config: InputConfig = _cfg(config_name)
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	_pad_press(resolver)
	var mark: int = rec.mark()
	_move_px(resolver, config.pointer_switch_px - 1)
	assert_array(rec.device_changes_since(mark)).is_empty()
	_move_px(resolver, 1)
	assert_array(rec.device_changes_since(mark)).is_equal([KBM])
	_move_px(resolver, config.pointer_switch_px * 2)
	assert_array(rec.device_changes_since(mark)).is_equal([KBM])


func test_change_carries_current_pad_style() -> void:
	var made: Array = _make(InputTestSupport.DEFAULT)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	_pad_press(resolver)
	assert_array(rec.since(0)[0]).is_equal([&"active_device_changed", [PAD, &"generic"]])


func test_first_pad_with_meaningful_input_becomes_active_pad() -> void:
	var made: Array = _make(InputTestSupport.DEFAULT)
	var resolver: InputResolver = made[0]
	assert_int(resolver.active_pad).is_equal(-1)
	_pad_press(resolver, 2)
	_pad_press(resolver, 1)
	assert_int(resolver.active_pad).is_equal(2)


# --- Story 013 ---------------------------------------------------------------

func test_stick_drift_inside_deadzone_emits_nothing(config_name: String,
		test_parameters := _CONFIGS) -> void:
	var config: InputConfig = _cfg(config_name)
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	var drift: float = config.deadzone - _DRIFT_MARGIN
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, drift))
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, 0.0))
	# Diagonal: each axis and the vector length under the deadzone.
	var diagonal: float = drift / sqrt(2.0)
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, diagonal))
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_Y, -diagonal))
	assert_array(rec.device_changes_since(0)).is_empty()
	assert_int(resolver.active_device).is_equal(KBM)


func test_motion_below_switch_px_emits_nothing(config_name: String,
		test_parameters := _CONFIGS) -> void:
	var config: InputConfig = _cfg(config_name)
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	_pad_press(resolver)
	var mark: int = rec.mark()
	_move_px(resolver, config.pointer_switch_px - 1)
	assert_array(rec.device_changes_since(mark)).is_empty()
	assert_int(resolver.active_device).is_equal(PAD)


func test_second_input_of_active_kind_emits_nothing() -> void:
	var made: Array = _make(InputTestSupport.DEFAULT)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	_pad_press(resolver)
	var mark: int = rec.mark()
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_B, true))
	assert_array(rec.device_changes_since(mark)).is_empty()
	resolver.feed_event(InputTestSupport.key(KEY_ENTER, true))
	mark = rec.mark()
	resolver.feed_event(InputTestSupport.key(KEY_ESCAPE, true))
	assert_array(rec.device_changes_since(mark)).is_empty()
	assert_int(resolver.active_device).is_equal(KBM)


# --- Story 017 ---------------------------------------------------------------

func test_pointer_distance_restarts_after_pad_switch(config_name: String,
		test_parameters := _CONFIGS) -> void:
	var config: InputConfig = _cfg(config_name)
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	_move_px(resolver, config.pointer_switch_px - 1)
	var mark: int = rec.mark()
	_pad_press(resolver)
	assert_array(rec.device_changes_since(mark)).is_equal([PAD])
	mark = rec.mark()
	_move_px(resolver, config.pointer_switch_px - 1)
	assert_array(rec.device_changes_since(mark)).is_empty()
	_move_px(resolver, 1)
	assert_array(rec.device_changes_since(mark)).is_equal([KBM])
