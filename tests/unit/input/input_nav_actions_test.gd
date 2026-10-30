## nav_* are pressed-only (story 021, resolver half of GDD AC-25; ADR-0003
## §8). Over long holds with repeat, each direction emits exactly story
## 018's computed step count as `action_pressed(nav_*)`, and never an
## `action_held(nav_*)` or `action_released(nav_*)`. The UI half
## (`UiNavigator.route()` re-injecting `ui_*` pairs) belongs to the
## ui-framework epic and is not tested here.
extends GdUnitTestSuite

const _CONFIGS: Array = [["default"], ["non_default"]]

# The hold per direction, in seconds (story 021 QA: 1.0 s each).
const _HOLD_SECONDS: float = 1.0

# Each direction as [key, nav action, stick axis, stick sign], in the QA
# order S, D, W, A.
const _DIRECTIONS: Array = [
	[KEY_S, InputActions.NAV_DOWN, JOY_AXIS_LEFT_Y, 1.0],
	[KEY_D, InputActions.NAV_RIGHT, JOY_AXIS_LEFT_X, 1.0],
	[KEY_W, InputActions.NAV_UP, JOY_AXIS_LEFT_Y, -1.0],
	[KEY_A, InputActions.NAV_LEFT, JOY_AXIS_LEFT_X, -1.0],
]


func _cfg(config_name: String) -> InputConfig:
	return InputTestSupport.DEFAULT if config_name == "default" else InputTestSupport.NON_DEFAULT


func _make(config: InputConfig) -> Array:
	var resolver := InputResolver.new(InputTestSupport.default_bindings(), config)
	var rec := InputTestSupport.Recorder.new()
	rec.attach(resolver)
	return [resolver, rec]


func _hold_ticks() -> int:
	return roundi(_HOLD_SECONDS / InputTestSupport.DT)


# Story 018's step count for a hold of `n_ticks`: every k with step_time(k)
# at or before n_ticks * DT (+ EPS_T).
func _expected_steps(config: InputConfig, n_ticks: int) -> int:
	var held_for: float = float(n_ticks) * InputTestSupport.DT + InputTestSupport.EPS_T
	var k: int = 0
	while InputResolver.step_time(k, config) <= held_for:
		k += 1
	return k


func _count(rec: InputTestSupport.Recorder, signal_name: StringName, action: StringName) -> int:
	var count: int = 0
	for entry: Array in rec.since(0):
		if entry[0] == signal_name and entry[1].size() > 0 and entry[1][0] == action:
			count += 1
	return count


func _assert_pressed_only(config: InputConfig, rec: InputTestSupport.Recorder) -> void:
	var expected: int = _expected_steps(config, _hold_ticks())
	assert_int(expected).is_greater(1)
	for direction: Array in _DIRECTIONS:
		var nav: StringName = direction[1]
		assert_int(_count(rec, &"action_pressed", nav)).is_equal(expected)
		assert_int(_count(rec, &"action_held", nav)).is_equal(0)
		assert_int(_count(rec, &"action_released", nav)).is_equal(0)


## AC-25 resolver half: holding each key in turn for 1.0 s emits only
## pressed(nav_*), the computed count per direction.
func test_key_holds_emit_nav_pressed_only(config_name: String,
		test_parameters := _CONFIGS) -> void:
	var config: InputConfig = _cfg(config_name)
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	for direction: Array in _DIRECTIONS:
		resolver.feed_event(InputTestSupport.key(direction[0], true))
		for i: int in _hold_ticks():
			resolver.tick(InputTestSupport.DT)
		resolver.feed_event(InputTestSupport.key(direction[0], false))
	_assert_pressed_only(config, rec)


## Edge case: the stick path gives the same result.
func test_stick_holds_emit_nav_pressed_only(config_name: String,
		test_parameters := _CONFIGS) -> void:
	var config: InputConfig = _cfg(config_name)
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	for direction: Array in _DIRECTIONS:
		resolver.feed_event(InputTestSupport.pad_axis(0, direction[2], direction[3]))
		for i: int in _hold_ticks():
			resolver.tick(InputTestSupport.DT)
		resolver.feed_event(InputTestSupport.pad_axis(0, direction[2], 0.0))
	_assert_pressed_only(config, rec)


## Edge case: focus loss during a hold emits no released(nav_*), and the
## repeat stops.
func test_focus_loss_during_hold_emits_no_nav_release() -> void:
	var config: InputConfig = InputTestSupport.DEFAULT
	var made: Array = _make(config)
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.feed_event(InputTestSupport.key(KEY_S, true))
	for i: int in _hold_ticks():
		resolver.tick(InputTestSupport.DT)
	resolver.set_window_focused(false)
	var mark: int = rec.mark()
	for i: int in _hold_ticks():
		resolver.tick(InputTestSupport.DT)
	assert_array(rec.nav_since(mark)).is_empty()
	for nav: StringName in InputTestSupport.NAV:
		assert_int(_count(rec, &"action_released", nav)).is_equal(0)
		assert_int(_count(rec, &"action_held", nav)).is_equal(0)
