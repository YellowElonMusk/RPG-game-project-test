## Story 006, AC-6: per-axis arbitration (GDD Edge Cases, ADR-0003 §8).
## Opposite digital directions give 0 on that axis; stick and d-pad on the
## same axis: the larger magnitude wins; at equal magnitude the d-pad wins.
## A stick at rescaled value s is placed by inverting the formula,
## `raw = deadzone + s * (1 - deadzone)`, from the config; every case runs
## with `DEFAULT` and `NON_DEFAULT`.
extends GdUnitTestSuite

const _CONFIGS: Array = [["default"], ["non_default"]]
## A mid-range rescaled stick value used where the exact value is incidental.
const _HALF: float = 0.5


func _config(which: String) -> InputConfig:
	return InputTestSupport.DEFAULT if which == "default" else InputTestSupport.NON_DEFAULT


func _eps() -> Vector2:
	return Vector2(InputTestSupport.EPS_V, InputTestSupport.EPS_V)


func _raw_for(cfg: InputConfig, s: float) -> float:
	return signf(s) * (cfg.deadzone + absf(s) * (1.0 - cfg.deadzone))


func _key(triple_key: String, pressed: bool = true) -> InputEvent:
	return InputTestSupport.key(DefaultBindingEvents.EVENTS[triple_key], pressed)


func _dpad(triple_key: String, pressed: bool = true) -> InputEvent:
	return InputTestSupport.pad_button(0, DefaultBindingEvents.EVENTS[triple_key], pressed)


func test_opposite_digital_directions_cancel(which: String, test_parameters := _CONFIGS) -> void:
	var resolver := InputResolver.new(InputTestSupport.default_bindings(), _config(which))
	resolver.feed_event(_key("move_left:key:Left"))
	resolver.feed_event(_dpad("move_right:pad:dpad_right"))
	resolver.feed_event(_key("move_up:key:W"))
	resolver.feed_event(_key("move_down:key:Down"))
	assert_vector(resolver.get_move_vector()).is_equal(Vector2.ZERO)


func test_stick_alone_gives_rescaled_value(which: String, test_parameters := _CONFIGS) -> void:
	var cfg: InputConfig = _config(which)
	var resolver := InputResolver.new(InputTestSupport.default_bindings(), cfg)
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, _raw_for(cfg, _HALF)))
	assert_vector(resolver.get_move_vector()).is_equal_approx(Vector2(_HALF, 0.0), _eps())


## Larger magnitude wins: d-pad (1) beats a half-deflected opposite stick.
func test_larger_magnitude_dpad_beats_partial_stick(which: String, test_parameters := _CONFIGS) -> void:
	var cfg: InputConfig = _config(which)
	var resolver := InputResolver.new(InputTestSupport.default_bindings(), cfg)
	resolver.feed_event(_dpad("move_right:pad:dpad_right"))
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, _raw_for(cfg, -_HALF)))
	assert_vector(resolver.get_move_vector()).is_equal_approx(Vector2(1.0, 0.0), _eps())


## Larger magnitude wins: with no digital on the axis, the stick wins it.
func test_larger_magnitude_stick_beats_absent_digital(which: String, test_parameters := _CONFIGS) -> void:
	var cfg: InputConfig = _config(which)
	var resolver := InputResolver.new(InputTestSupport.default_bindings(), cfg)
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_Y, _raw_for(cfg, _HALF)))
	assert_vector(resolver.get_move_vector()).is_equal_approx(Vector2(0.0, _HALF), _eps())


## Tie: full-right stick (rescaled 1) and d-pad left: the d-pad wins, x = -1.
func test_tie_dpad_wins(which: String, test_parameters := _CONFIGS) -> void:
	var cfg: InputConfig = _config(which)
	var resolver := InputResolver.new(InputTestSupport.default_bindings(), cfg)
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, _raw_for(cfg, 1.0)))
	resolver.feed_event(_dpad("move_left:pad:dpad_left"))
	assert_vector(resolver.get_move_vector()).is_equal_approx(Vector2(-1.0, 0.0), _eps())


## Recommended reading (owner to confirm): digital cancellation counts as
## magnitude 0, so a deflected stick wins the axis.
func test_cancelled_digital_lets_stick_win(which: String, test_parameters := _CONFIGS) -> void:
	var cfg: InputConfig = _config(which)
	var resolver := InputResolver.new(InputTestSupport.default_bindings(), cfg)
	resolver.feed_event(_dpad("move_left:pad:dpad_left"))
	resolver.feed_event(_dpad("move_right:pad:dpad_right"))
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, _raw_for(cfg, _HALF)))
	assert_vector(resolver.get_move_vector()).is_equal_approx(Vector2(_HALF, 0.0), _eps())


## Two pads: per axis, the stick with the larger absolute rescaled value wins.
func test_two_pads_larger_stick_wins(which: String, test_parameters := _CONFIGS) -> void:
	var cfg: InputConfig = _config(which)
	var small: float = 0.3
	var large: float = -0.7
	var resolver := InputResolver.new(InputTestSupport.default_bindings(), cfg)
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, _raw_for(cfg, small)))
	resolver.feed_event(InputTestSupport.pad_axis(1, JOY_AXIS_LEFT_X, _raw_for(cfg, large)))
	assert_vector(resolver.get_move_vector()).is_equal_approx(Vector2(large, 0.0), _eps())


## Normalization runs after arbitration: d-pad up plus a stick on x gives a
## vector of length 1 along the arbitrated (stick x, -1) direction.
func test_normalization_after_arbitration(which: String, test_parameters := _CONFIGS) -> void:
	var cfg: InputConfig = _config(which)
	var resolver := InputResolver.new(InputTestSupport.default_bindings(), cfg)
	resolver.feed_event(_dpad("move_up:pad:dpad_up"))
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, _raw_for(cfg, _HALF)))
	assert_vector(resolver.get_move_vector()).is_equal_approx(Vector2(_HALF, -1.0).normalized(), _eps())
