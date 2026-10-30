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


# --- Stories 018 and 019: the step_time schedule and direction changes -------
# Story 018 (AC-7): steps on the first tick n with n * DT + EPS_T >=
# step_time(k), catch-up on a hitch tick, stop on release. Story 019 (AC-8):
# a direction change fires one immediate step and restarts from repeat_delay.
# Expected tick indices are computed from config with integer n * DT, never
# a running float sum.

# Case 1 (boundary: repeat_interval 0.05 = 3 ticks, so due times land on
# tick boundaries), case 2 (DEFAULT, 0.08 = 4.8 ticks, a non-multiple), and
# the NON_DEFAULT run.
const _SCHEDULE_CONFIGS: Array = [["boundary"], ["default"], ["non_default"]]

# The boundary case's interval (story 018 pinned case 1).
const _BOUNDARY_INTERVAL: float = 0.05

# The held time T of the schedule test, in seconds (story 018 QA: T = 1.0 s).
const _HOLD_SECONDS: float = 1.0

# Ticks before the hitch (story 018 pinned case 3).
const _HITCH_LEAD_TICKS: int = 24
# The hitch tick's span, in seconds (GDD AC-7).
const _HITCH_SECONDS: float = 0.25


func _schedule_cfg(config_name: String) -> InputConfig:
	if config_name == "boundary":
		return InputTestSupport.make_config({"repeat_interval": _BOUNDARY_INTERVAL})
	return _cfg(config_name)


# The first integer tick n with n * DT + EPS_T >= t.
func _tick_for(t: float) -> int:
	var n: int = maxi(0, floori(t / InputTestSupport.DT) - 1)
	while float(n) * InputTestSupport.DT + InputTestSupport.EPS_T < t:
		n += 1
	return n


# The expected tick index of every step k with step_time(k) inside the first
# `n_ticks` ticks (step 0 at index 0, inside feed_event()).
func _expected_ticks(config: InputConfig, n_ticks: int) -> Array[int]:
	var out: Array[int] = []
	var k: int = 0
	while true:
		var n: int = _tick_for(InputResolver.step_time(k, config))
		if n > n_ticks:
			break
		out.append(n)
		k += 1
	return out


# Ticks `n_ticks` times and returns [tick_index, nav_action] per step, with
# indices counted from `first_index`.
func _stamp_ticks(resolver: InputResolver, rec: InputTestSupport.Recorder,
		n_ticks: int, first_index: int = 1) -> Array:
	var stamps: Array = []
	for i: int in n_ticks:
		var mark: int = rec.mark()
		resolver.tick(InputTestSupport.DT)
		for nav: StringName in rec.nav_since(mark):
			stamps.append([first_index + i, nav])
	return stamps


func _indices(stamps: Array) -> Array[int]:
	var out: Array[int] = []
	for stamp: Array in stamps:
		out.append(stamp[0])
	return out


func _navs(stamps: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for stamp: Array in stamps:
		out.append(stamp[1])
	return out


func _all(action: StringName, count: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for i: int in count:
		out.append(action)
	return out


## Story 018 / AC-7: steps fire on the first tick at or after step_time(k).
## Edge cases: case 1's last step is due exactly at T and counts; every
## step's index is asserted, so none fires a tick early.
func test_held_direction_steps_on_first_tick_at_or_after_step_time(config_name: String,
		test_parameters := _SCHEDULE_CONFIGS) -> void:
	var config: InputConfig = _schedule_cfg(config_name)
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	var n_ticks: int = roundi(_HOLD_SECONDS / InputTestSupport.DT)
	resolver.feed_event(InputTestSupport.key(KEY_S, true))
	var stamps: Array = []
	for nav: StringName in rec.nav_since(0):
		stamps.append([0, nav])
	stamps.append_array(_stamp_ticks(resolver, rec, n_ticks))
	resolver.feed_event(InputTestSupport.key(KEY_S, false))
	var expected: Array[int] = _expected_ticks(config, n_ticks)
	assert_array(_indices(stamps)).is_equal(expected)
	assert_array(_navs(stamps)).is_equal(_all(InputActions.NAV_DOWN, expected.size()))
	# The count, from the closed form: k = 0 plus every k >= 1 with
	# repeat_delay + (k - 1) * repeat_interval <= T.
	var count: int = floori((_HOLD_SECONDS - config.repeat_delay + InputTestSupport.EPS_T)
			/ config.repeat_interval) + 2
	assert_int(stamps.size()).is_equal(count)
	if config_name == "boundary":
		assert_int(_indices(stamps).back()).is_equal(n_ticks)


## Story 018 / AC-7: one hitch tick fires every due step, in order, as
## separate entries. Non-vacuous: more than one step is due.
func test_hitch_tick_fires_every_due_step_separately(config_name: String,
		test_parameters := _CONFIGS) -> void:
	var config: InputConfig = _cfg(config_name)
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.feed_event(InputTestSupport.key(KEY_S, true))
	for i: int in _HITCH_LEAD_TICKS:
		resolver.tick(InputTestSupport.DT)
	var mark: int = rec.mark()
	resolver.tick(_HITCH_SECONDS)
	var start: float = float(_HITCH_LEAD_TICKS) * InputTestSupport.DT
	var due: int = 0
	var k: int = 1
	while InputResolver.step_time(k, config) <= start + _HITCH_SECONDS + InputTestSupport.EPS_T:
		if InputResolver.step_time(k, config) > start + InputTestSupport.EPS_T:
			due += 1
		k += 1
	assert_int(due).is_greater(1)
	var expected: Array = []
	for i: int in due:
		expected.append([&"action_pressed", [InputActions.NAV_DOWN]])
	assert_array(rec.since(mark)).is_equal(expected)


## Story 018 known negative (documented, not the AC test): a hitch tick
## straight after the press covers no due time at DEFAULT.
func test_hitch_straight_after_press_has_no_due_step_at_default() -> void:
	var config: InputConfig = InputTestSupport.DEFAULT
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.feed_event(InputTestSupport.key(KEY_S, true))
	var mark: int = rec.mark()
	resolver.tick(_HITCH_SECONDS)
	assert_float(InputResolver.step_time(1, config)).is_greater(_HITCH_SECONDS)
	assert_array(rec.nav_since(mark)).is_empty()


## Story 018 / AC-7: releasing stops further steps; nothing is ever released
## for nav_*.
func test_release_stops_steps_and_never_releases_nav(config_name: String,
		test_parameters := _CONFIGS) -> void:
	var config: InputConfig = _cfg(config_name)
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.feed_event(InputTestSupport.key(KEY_S, true))
	for i: int in _tick_for(InputResolver.step_time(3, config)):
		resolver.tick(InputTestSupport.DT)
	assert_int(rec.nav_since(0).size()).is_equal(4)
	resolver.feed_event(InputTestSupport.key(KEY_S, false))
	var mark: int = rec.mark()
	for i: int in _tick_for(2.0 * config.repeat_delay):
		resolver.tick(InputTestSupport.DT)
	assert_array(rec.nav_since(mark)).is_empty()
	for entry: Array in rec.since(0):
		assert_bool(entry[0] == &"action_released" and InputTestSupport.NAV.has(entry[1][0])) \
				.is_false()


## Story 018 edge case: a key and a d-pad both hold down -- releasing one
## keeps the repeat going on its original schedule.
func test_release_of_one_of_two_sources_keeps_repeat(config_name: String,
		test_parameters := _CONFIGS) -> void:
	var config: InputConfig = _cfg(config_name)
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.feed_event(InputTestSupport.key(KEY_S, true))
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_DPAD_DOWN, true))
	var n_release: int = _tick_for(InputResolver.step_time(1, config))
	for i: int in n_release:
		resolver.tick(InputTestSupport.DT)
	resolver.feed_event(InputTestSupport.key(KEY_S, false))
	var n_end: int = _tick_for(InputResolver.step_time(4, config))
	var stamps: Array = _stamp_ticks(resolver, rec, n_end - n_release, n_release + 1)
	var expected: Array[int] = []
	for n: int in _expected_ticks(config, n_end):
		if n > n_release:
			expected.append(n)
	assert_int(expected.size()).is_equal(3)
	assert_array(_indices(stamps)).is_equal(expected)
	assert_array(_navs(stamps)).is_equal(_all(InputActions.NAV_DOWN, expected.size()))


## Story 019 / AC-8 (a): down released and right pressed in one frame fires
## an immediate nav_right inside feed_event(), then restarts the schedule
## from repeat_delay after the change; no nav_down after the change.
func test_direction_change_fires_immediate_step_and_restarts(config_name: String,
		test_parameters := _CONFIGS) -> void:
	var config: InputConfig = _cfg(config_name)
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.feed_event(InputTestSupport.key(KEY_S, true))
	for i: int in _tick_for(InputResolver.step_time(3, config)):
		resolver.tick(InputTestSupport.DT)
	var mark: int = rec.mark()
	resolver.feed_event(InputTestSupport.key(KEY_S, false))
	resolver.feed_event(InputTestSupport.key(KEY_D, true))
	assert_array(rec.nav_since(mark)).is_equal([InputActions.NAV_RIGHT])
	_assert_restarted_schedule(config, resolver, rec, InputActions.NAV_RIGHT)


## Story 019 / AC-8 (b): with A and D held (cancelled, no steps), releasing A
## is a new press: an immediate nav_right, then the schedule from
## repeat_delay after the release.
func test_releasing_one_of_two_opposed_keys_counts_as_press(config_name: String,
		test_parameters := _CONFIGS) -> void:
	var config: InputConfig = _cfg(config_name)
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.feed_event(InputTestSupport.key(KEY_A, true))
	resolver.feed_event(InputTestSupport.key(KEY_D, true))
	var mark: int = rec.mark()
	for i: int in _tick_for(2.0 * config.repeat_delay):
		resolver.tick(InputTestSupport.DT)
	assert_array(rec.nav_since(mark)).is_empty()
	mark = rec.mark()
	resolver.feed_event(InputTestSupport.key(KEY_A, false))
	assert_array(rec.nav_since(mark)).is_equal([InputActions.NAV_RIGHT])
	_assert_restarted_schedule(config, resolver, rec, InputActions.NAV_RIGHT)


## Story 019 edge case: pressing D while A repeats stops the x-axis repeat
## immediately (no further nav_left).
func test_opposed_press_while_repeating_stops_axis_repeat(config_name: String,
		test_parameters := _CONFIGS) -> void:
	var config: InputConfig = _cfg(config_name)
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.feed_event(InputTestSupport.key(KEY_A, true))
	for i: int in _tick_for(InputResolver.step_time(1, config)):
		resolver.tick(InputTestSupport.DT)
	assert_array(rec.nav_since(0)).is_equal([InputActions.NAV_LEFT, InputActions.NAV_LEFT])
	var mark: int = rec.mark()
	resolver.feed_event(InputTestSupport.key(KEY_D, true))
	for i: int in _tick_for(2.0 * config.repeat_delay):
		resolver.tick(InputTestSupport.DT)
	assert_array(rec.nav_since(mark)).is_empty()


# After a change at tick 0 (step 0 already asserted), ticks until
# repeat_delay + 2 * repeat_interval and asserts every later step lands on
# the schedule measured from the change, all as `nav`.
func _assert_restarted_schedule(config: InputConfig, resolver: InputResolver,
		rec: InputTestSupport.Recorder, nav: StringName) -> void:
	var n_end: int = _tick_for(config.repeat_delay + 2.0 * config.repeat_interval)
	var stamps: Array = _stamp_ticks(resolver, rec, n_end)
	var expected: Array[int] = _expected_ticks(config, n_end)
	expected.remove_at(0)
	assert_int(expected.size()).is_equal(3)
	assert_array(_indices(stamps)).is_equal(expected)
	assert_array(_navs(stamps)).is_equal(_all(nav, expected.size()))
