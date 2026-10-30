## Story 005, AC-5: the radial deadzone rescale (GDD Formulas,
## `stick_output`). Every expected value is computed from `config.deadzone`
## through the formula, and every case runs with `DEFAULT` and `NON_DEFAULT`
## (deadzone 0.25). Asserted both through `InputResolver.stick_output()` and
## through the composed `get_move_vector()` fed by `left_x`/`left_y` events.
extends GdUnitTestSuite

## Config selector per run.
const _CONFIGS: Array = [["default"], ["non_default"]]
## ε pinned by the QA spec.
const _EPSILON: float = 0.01
## The GDD's worked-example raw x (expected value derived, never hardcoded).
const _GDD_EXAMPLE_RAW_X: float = 0.60


func _config(which: String) -> InputConfig:
	return InputTestSupport.DEFAULT if which == "default" else InputTestSupport.NON_DEFAULT


func _eps() -> Vector2:
	return Vector2(InputTestSupport.EPS_V, InputTestSupport.EPS_V)


# The formula, written out independently of the resolver.
func _formula(raw: Vector2, deadzone: float) -> Vector2:
	var m: float = raw.length()
	if m < deadzone or m == 0.0:
		return Vector2.ZERO
	return raw / m * minf(1.0, (m - deadzone) / (1.0 - deadzone))


# A resolver with pad 0's left stick at `raw`.
func _stick(cfg: InputConfig, raw: Vector2) -> InputResolver:
	var resolver := InputResolver.new(InputTestSupport.default_bindings(), cfg)
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, raw.x))
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_Y, raw.y))
	return resolver


func test_raw_exactly_deadzone_gives_zero(which: String, test_parameters := _CONFIGS) -> void:
	var cfg: InputConfig = _config(which)
	var raw := Vector2(cfg.deadzone, 0.0)
	assert_vector(InputResolver.stick_output(raw, cfg.deadzone)).is_equal(Vector2.ZERO)
	assert_vector(_stick(cfg, raw).get_move_vector()).is_equal(Vector2.ZERO)


func test_raw_just_above_deadzone_is_at_most_scaled_epsilon(which: String, test_parameters := _CONFIGS) -> void:
	var cfg: InputConfig = _config(which)
	var raw := Vector2(cfg.deadzone + _EPSILON, 0.0)
	var bound: float = _EPSILON / (1.0 - cfg.deadzone) + InputTestSupport.EPS_V
	assert_float(InputResolver.stick_output(raw, cfg.deadzone).length()).is_less_equal(bound)
	var got: Vector2 = _stick(cfg, raw).get_move_vector()
	assert_float(got.length()).is_less_equal(bound)
	assert_float(got.length()).is_greater(0.0)


func test_diagonal_keeps_direction(which: String, test_parameters := _CONFIGS) -> void:
	var cfg: InputConfig = _config(which)
	var raw: Vector2 = Vector2(1.0, -1.0).normalized() * (cfg.deadzone + 0.3)
	var got: Vector2 = _stick(cfg, raw).get_move_vector()
	assert_vector(got.normalized()).is_equal_approx(raw.normalized(), _eps())
	assert_vector(got).is_equal_approx(_formula(raw, cfg.deadzone), _eps())


## Radial, not per axis: each component is below the deadzone but the
## length is above it, so the output is non-zero.
func test_deadzone_is_radial_not_per_axis(which: String, test_parameters := _CONFIGS) -> void:
	var cfg: InputConfig = _config(which)
	var component: float = cfg.deadzone * 0.75
	var raw := Vector2(component, component)
	assert_float(raw.length()).is_greater(cfg.deadzone)
	var got: Vector2 = _stick(cfg, raw).get_move_vector()
	assert_float(got.length()).is_greater(0.0)
	assert_vector(got).is_equal_approx(_formula(raw, cfg.deadzone), _eps())


func test_gdd_example_matches_formula(which: String, test_parameters := _CONFIGS) -> void:
	var cfg: InputConfig = _config(which)
	var raw := Vector2(_GDD_EXAMPLE_RAW_X, 0.0)
	var expected := Vector2((_GDD_EXAMPLE_RAW_X - cfg.deadzone) / (1.0 - cfg.deadzone), 0.0)
	assert_vector(InputResolver.stick_output(raw, cfg.deadzone)).is_equal_approx(expected, _eps())
	assert_vector(_stick(cfg, raw).get_move_vector()).is_equal_approx(expected, _eps())


func test_raw_above_one_is_clamped_to_one(which: String, test_parameters := _CONFIGS) -> void:
	var cfg: InputConfig = _config(which)
	var raw := Vector2(1.0, 1.0)
	var got: Vector2 = _stick(cfg, raw).get_move_vector()
	assert_float(got.length()).is_equal_approx(1.0, InputTestSupport.EPS_V)
	assert_vector(got).is_equal_approx(raw.normalized(), _eps())


## Centering the stick returns the vector to zero.
func test_stick_recentred_gives_zero(which: String, test_parameters := _CONFIGS) -> void:
	var cfg: InputConfig = _config(which)
	var resolver: InputResolver = _stick(cfg, Vector2(1.0, 0.0))
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, 0.0))
	assert_vector(resolver.get_move_vector()).is_equal(Vector2.ZERO)
