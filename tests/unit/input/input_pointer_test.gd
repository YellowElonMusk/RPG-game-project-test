## Raw pointer events (ADR-0003 §5, §8; ADR-0008 §6).
## Story 009, AC-20: with no consumer attached, a left click emits
## `pointer_confirm` with its position, a right click `pointer_cancel`, and
## wheel up/down emit steps of opposite sign. Press edge only; releases,
## middle, X1/X2 and wheel left/right emit no pointer signal.
## Story 010, AC-21: no pointer event ever produces a `move` (or the derived
## `nav_*`) action.
extends GdUnitTestSuite

const _CLICK_POS := Vector2(123.0, 45.0)

# Every mouse button kind a pointer can report (story 010 feeds them all).
const _ALL_BUTTONS: Array[int] = [
	MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE,
	MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN,
	MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT,
	MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2,
]

const _CONFIGS: Array = [["default"], ["non_default"]]


func _cfg(config_name: String) -> InputConfig:
	return InputTestSupport.DEFAULT if config_name == "default" else InputTestSupport.NON_DEFAULT


func _make(config: InputConfig = InputTestSupport.DEFAULT) -> Array:
	var resolver := InputResolver.new(InputTestSupport.default_bindings(), config)
	var rec := InputTestSupport.Recorder.new()
	rec.attach(resolver)
	return [resolver, rec]


func test_left_click_emits_pointer_confirm_with_position_on_press_only() -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.feed_event(InputTestSupport.mouse_button(MOUSE_BUTTON_LEFT, true, _CLICK_POS))
	resolver.feed_event(InputTestSupport.mouse_button(MOUSE_BUTTON_LEFT, false, _CLICK_POS))
	assert_array(rec.since(0)).is_equal([[&"pointer_confirm", [_CLICK_POS]]])
	assert_vector(resolver.pointer_position).is_equal(_CLICK_POS)


func test_right_click_emits_pointer_cancel_with_position_on_press_only() -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.feed_event(InputTestSupport.mouse_button(MOUSE_BUTTON_RIGHT, true, _CLICK_POS))
	resolver.feed_event(InputTestSupport.mouse_button(MOUSE_BUTTON_RIGHT, false, _CLICK_POS))
	assert_array(rec.since(0)).is_equal([[&"pointer_cancel", [_CLICK_POS]]])


func test_wheel_up_and_down_emit_opposite_sign_steps() -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	# Godot delivers each notch as a pressed + released pair.
	resolver.feed_event(InputTestSupport.mouse_button(MOUSE_BUTTON_WHEEL_UP, true))
	resolver.feed_event(InputTestSupport.mouse_button(MOUSE_BUTTON_WHEEL_UP, false))
	resolver.feed_event(InputTestSupport.mouse_button(MOUSE_BUTTON_WHEEL_DOWN, true))
	resolver.feed_event(InputTestSupport.mouse_button(MOUSE_BUTTON_WHEEL_DOWN, false))
	assert_array(rec.since(0)).is_equal([[&"wheel_step", [1]], [&"wheel_step", [-1]]])


## Edge case: wheel `factor` is ignored -- one step per notch event.
func test_wheel_factor_is_ignored() -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	var notch := InputTestSupport.mouse_button(MOUSE_BUTTON_WHEEL_DOWN, true)
	notch.factor = 3.0
	resolver.feed_event(notch)
	assert_array(rec.since(0)).is_equal([[&"wheel_step", [-1]]])


## Edge case: middle, X1/X2 and wheel left/right emit no pointer signal.
func test_other_buttons_emit_no_pointer_signal() -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	for button: int in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2,
			MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		resolver.feed_event(InputTestSupport.mouse_button(button, true, _CLICK_POS))
		resolver.feed_event(InputTestSupport.mouse_button(button, false, _CLICK_POS))
	assert_array(rec.since(0)).is_empty()


## Edge case: a click is raw -- it never emits `action_pressed(confirm)`.
func test_click_never_emits_confirm_action() -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.feed_event(InputTestSupport.mouse_button(MOUSE_BUTTON_LEFT, true, _CLICK_POS))
	for entry: Array in rec.since(0):
		assert_str(String(entry[0])).is_not_equal("action_pressed")


func test_pointer_position_tracks_motion() -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var motion := InputTestSupport.mouse_motion(Vector2(3.0, 4.0))
	motion.position = _CLICK_POS
	resolver.feed_event(motion)
	assert_vector(resolver.pointer_position).is_equal(_CLICK_POS)


# Feeds every mouse event kind: a large motion, then press and release of
# every button. After each event the move vector must equal `expected`.
func _feed_every_pointer_event(resolver: InputResolver, expected: Vector2) -> void:
	var eps := Vector2(InputTestSupport.EPS_V, InputTestSupport.EPS_V)
	resolver.feed_event(InputTestSupport.mouse_motion(Vector2(500.0, -500.0)))
	assert_vector(resolver.get_move_vector()).is_equal_approx(expected, eps)
	for button: int in _ALL_BUTTONS:
		for pressed: bool in [true, false]:
			resolver.feed_event(InputTestSupport.mouse_button(button, pressed, _CLICK_POS))
			assert_vector(resolver.get_move_vector()).is_equal_approx(expected, eps)


func test_pointer_events_never_produce_move_or_nav(config_name: String,
		test_parameters := _CONFIGS) -> void:
	var made: Array = _make(_cfg(config_name))
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	_feed_every_pointer_event(resolver, Vector2.ZERO)
	resolver.tick(InputTestSupport.DT)
	for entry: Array in rec.since(0):
		assert_str(String(entry[0])).override_failure_message(
				"pointer produced %s" % [entry]).is_not_equal("action_pressed")


# The story-018 step count for a direction held over `ticks` ticks of DT:
# every k with step_time(k) <= n * DT (+ 1e-9), with n an integer.
func _expected_steps(config: InputConfig, ticks: int) -> int:
	var held_for: float = float(ticks) * InputTestSupport.DT
	var count: int = 0
	while InputResolver.step_time(count, config) <= held_for + InputTestSupport.EPS_T:
		count += 1
	return count


## Edge case: while a key holds move_right, pointer events leave the vector
## at exactly (1, 0) and the nav_right count at the story-018 value.
func test_pointer_events_do_not_disturb_held_move(config_name: String,
		test_parameters := _CONFIGS) -> void:
	var config: InputConfig = _cfg(config_name)
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	var right_key: int = DefaultBindingEvents.EVENTS["move_right:key:Right"]
	var ticks: int = 60
	resolver.feed_event(InputTestSupport.key(right_key, true))
	for i: int in ticks:
		_feed_every_pointer_event(resolver, Vector2.RIGHT)
		resolver.tick(InputTestSupport.DT)
	var steps: Array[StringName] = rec.nav_since(0)
	assert_int(steps.size()).is_equal(_expected_steps(config, ticks))
	for step: StringName in steps:
		assert_str(String(step)).is_equal(String(InputActions.NAV_RIGHT))
	for entry: Array in rec.discrete_since(0):
		assert_str(String(entry[0])).is_not_equal("action_pressed")
