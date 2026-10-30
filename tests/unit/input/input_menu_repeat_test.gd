## Menu stick threshold (ADR-0003 §4, §8; GDD rule 6, Tuning Knobs).
## Story 020, AC-9: a stick at `menu_stick_threshold - 1e-6` (after the
## deadzone rescale) along an axis produces no menu step; at
## `threshold + 1e-6` it produces one, immediately inside `feed_event()`.
## The threshold is per axis on the rescaled component, never the length.
## Raw values invert the rescale: `raw = deadzone + target * (1 - deadzone)`.
extends GdUnitTestSuite

const _CONFIGS: Array = [["default"], ["non_default"]]

# The AC's threshold offset (story 020: threshold ± 1e-6).
const _OFFSET: float = 1e-6


func _cfg(config_name: String) -> InputConfig:
	return InputTestSupport.DEFAULT if config_name == "default" else InputTestSupport.NON_DEFAULT


func _make(config: InputConfig) -> Array:
	var resolver := InputResolver.new(InputTestSupport.default_bindings(), config)
	var rec := InputTestSupport.Recorder.new()
	rec.attach(resolver)
	return [resolver, rec]


# The raw single-axis value whose rescaled output is `target`.
func _raw_for(config: InputConfig, target: float) -> float:
	return config.deadzone + target * (1.0 - config.deadzone)


func test_stick_just_below_threshold_produces_no_step(config_name: String,
		test_parameters := _CONFIGS) -> void:
	var config: InputConfig = _cfg(config_name)
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	var raw: float = _raw_for(config, config.menu_stick_threshold - _OFFSET)
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, raw))
	for i: int in ceili(config.repeat_delay / InputTestSupport.DT) + 1:
		resolver.tick(InputTestSupport.DT)
	assert_array(rec.nav_since(0)).is_empty()


func test_stick_just_above_threshold_produces_one_immediate_step(config_name: String,
		test_parameters := _CONFIGS) -> void:
	var config: InputConfig = _cfg(config_name)
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	var raw: float = _raw_for(config, config.menu_stick_threshold + _OFFSET)
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, raw))
	assert_array(rec.nav_since(0)).is_equal([InputActions.NAV_RIGHT])


## Edge case: crossing in steps -- below, then above, fires exactly one step
## at the crossing event.
func test_crossing_from_below_fires_step_at_crossing(config_name: String,
		test_parameters := _CONFIGS) -> void:
	var config: InputConfig = _cfg(config_name)
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	var below: float = _raw_for(config, config.menu_stick_threshold - _OFFSET)
	var above: float = _raw_for(config, config.menu_stick_threshold + _OFFSET)
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, -below))
	assert_array(rec.nav_since(0)).is_empty()
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, -above))
	assert_array(rec.nav_since(0)).is_equal([InputActions.NAV_LEFT])


## Edge case (pinned sign convention): left_y negative gives nav_up.
func test_left_y_negative_past_threshold_is_nav_up(config_name: String,
		test_parameters := _CONFIGS) -> void:
	var config: InputConfig = _cfg(config_name)
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	var raw: float = _raw_for(config, config.menu_stick_threshold + _OFFSET)
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_Y, -raw))
	assert_array(rec.nav_since(0)).is_equal([InputActions.NAV_UP])


## Edge case: dropping back under the threshold is the release -- repeat stops.
func test_dropping_under_threshold_stops_repeat(config_name: String,
		test_parameters := _CONFIGS) -> void:
	var config: InputConfig = _cfg(config_name)
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	var above: float = _raw_for(config, config.menu_stick_threshold + _OFFSET)
	var below: float = _raw_for(config, config.menu_stick_threshold - _OFFSET)
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, above))
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, below))
	var mark: int = rec.mark()
	for i: int in ceili((config.repeat_delay + config.repeat_interval * 3.0) / InputTestSupport.DT):
		resolver.tick(InputTestSupport.DT)
	assert_array(rec.nav_since(mark)).is_empty()


## Edge case: per axis, not length -- a diagonal whose rescaled components are
## each under the threshold, with a length over it, produces no step.
func test_threshold_is_per_axis_not_vector_length(config_name: String,
		test_parameters := _CONFIGS) -> void:
	var config: InputConfig = _cfg(config_name)
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	var component: float = config.menu_stick_threshold * 0.95
	var out_length: float = component * sqrt(2.0)
	assert_float(out_length).is_greater(config.menu_stick_threshold)
	var raw_axis: float = _raw_for(config, out_length) / sqrt(2.0)
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, raw_axis))
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_Y, raw_axis))
	assert_array(rec.nav_since(0)).is_empty()
