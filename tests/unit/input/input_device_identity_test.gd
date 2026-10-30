## Device identity (ADR-0003 Implementation Guidelines, §8; GDD rule 4).
## Story 011, AC-13: a gamepad reporting device ID 0 makes the active device
## `gamepad`; a key press makes it `keyboard_mouse`, identified by
## `InputEvent.DEVICE_ID_KEYBOARD`. Classification is by event type, never by
## `event.device == 0`.
extends GdUnitTestSuite


func _make() -> InputResolver:
	return InputResolver.new(InputTestSupport.default_bindings(), InputTestSupport.DEFAULT)


func test_initial_active_device_is_keyboard_mouse() -> void:
	assert_int(_make().active_device).is_equal(InputResolver.DeviceKind.KEYBOARD_MOUSE)


func test_pad_device_zero_is_gamepad_then_key_is_keyboard_mouse() -> void:
	var resolver: InputResolver = _make()
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_A, true))
	assert_int(resolver.active_device).is_equal(InputResolver.DeviceKind.GAMEPAD)
	var key_event: InputEventKey = InputTestSupport.key(KEY_ENTER, true)
	assert_int(key_event.device).is_equal(InputEvent.DEVICE_ID_KEYBOARD)
	resolver.feed_event(key_event)
	assert_int(resolver.active_device).is_equal(InputResolver.DeviceKind.KEYBOARD_MOUSE)


## Regression guard: a key stamped device 0 is still keyboard by type.
func test_key_stamped_device_zero_is_still_keyboard() -> void:
	var resolver: InputResolver = _make()
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_A, true))
	var key_event: InputEventKey = InputTestSupport.key(KEY_ENTER, true)
	key_event.device = 0
	resolver.feed_event(key_event)
	assert_int(resolver.active_device).is_equal(InputResolver.DeviceKind.KEYBOARD_MOUSE)


## Regression guard: a mouse click stamped device 0 is still keyboard_mouse.
func test_mouse_click_stamped_device_zero_is_keyboard_mouse() -> void:
	var resolver: InputResolver = _make()
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_A, true))
	var click: InputEventMouseButton = InputTestSupport.mouse_button(MOUSE_BUTTON_LEFT, true)
	click.device = 0
	resolver.feed_event(click)
	assert_int(resolver.active_device).is_equal(InputResolver.DeviceKind.KEYBOARD_MOUSE)
