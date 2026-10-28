## Spike item 1 regression (ADR-0003 Engine Notes, Migration Plan step 2):
## pins the synthetic-event defaults the spike verified on 4.7.2, headless,
## 2026-10-21, so a later engine patch that changes them is caught here
## rather than surfacing as a mysterious failure in every other Input test.
extends GdUnitTestSuite


func test_input_event_key_defaults_to_keyboard_device() -> void:
	var event := InputEventKey.new()
	assert_int(event.device).is_equal(InputEvent.DEVICE_ID_KEYBOARD)
	assert_int(InputEvent.DEVICE_ID_KEYBOARD).is_equal(16)


func test_input_event_mouse_button_defaults_to_mouse_device() -> void:
	var event := InputEventMouseButton.new()
	assert_int(event.device).is_equal(InputEvent.DEVICE_ID_MOUSE)
	assert_int(InputEvent.DEVICE_ID_MOUSE).is_equal(32)


func test_input_event_joypad_button_device_zero_feeds_resolver_without_error() -> void:
	var resolver := InputResolver.new(InputTestSupport.default_bindings(), InputTestSupport.DEFAULT)
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	resolver.feed_event(event)
	assert_bool(true).is_true()
