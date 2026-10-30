## Story 002, AC-2: one `pressed` per physical press, `held` on every
## `tick()` while held, one `released` on release; a one-tick tap emits one
## `pressed` and one `released` and no `held`; OS key-repeat echoes (and a
## repeated non-echo press of an already-held source) never emit a second
## `pressed`. Covered for `fast_forward` (Shift) and `confirm` (Enter, Space,
## Z) as the AC requires (ADR-0003 §8).
extends GdUnitTestSuite

## Number of ticks held in the hold tests (the count is the point of the test).
const _HOLD_TICKS: int = 5
## Number of echo events injected while held.
const _ECHO_COUNT: int = 3

## Every keyboard triple the AC names.
const _KEY_TRIPLES: Array = [
	["fast_forward:key:Shift"], ["confirm:key:Enter"], ["confirm:key:Space"], ["confirm:key:Z"],
]


func _make() -> Array:
	var resolver := InputResolver.new(InputTestSupport.default_bindings(), InputTestSupport.DEFAULT)
	var rec := InputTestSupport.Recorder.new()
	rec.attach(resolver)
	return [resolver, rec]


func _action_of(triple_key: String) -> StringName:
	return StringName(triple_key.split(":")[0])


func _held_entries(action: StringName, count: int) -> Array:
	var out: Array = []
	for i: int in count:
		out.append([&"action_held", [action]])
	return out


## Holding emits exactly one pressed, one held per tick, one released.
func test_hold_key_emits_one_pressed_held_per_tick_one_released(
		triple_key: String, test_parameters := _KEY_TRIPLES) -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	var action: StringName = _action_of(triple_key)
	var code: int = DefaultBindingEvents.EVENTS[triple_key]

	resolver.feed_event(InputTestSupport.key(code, true))
	for i: int in _HOLD_TICKS:
		resolver.tick(InputTestSupport.DT)
	resolver.feed_event(InputTestSupport.key(code, false))
	resolver.tick(InputTestSupport.DT)

	var expected: Array = [[&"action_pressed", [action]]]
	expected.append_array(_held_entries(action, _HOLD_TICKS))
	expected.append([&"action_released", [action]])
	assert_array(rec.since(0)).is_equal(expected)


## A tap pressed and released inside one tick: one pressed, one released, zero held.
func test_one_tick_tap_emits_pressed_released_and_no_held(
		triple_key: String, test_parameters := _KEY_TRIPLES) -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	var action: StringName = _action_of(triple_key)
	var code: int = DefaultBindingEvents.EVENTS[triple_key]

	resolver.feed_event(InputTestSupport.key(code, true))
	resolver.feed_event(InputTestSupport.key(code, false))
	resolver.tick(InputTestSupport.DT)

	assert_array(rec.since(0)).is_equal([
		[&"action_pressed", [action]], [&"action_released", [action]]])


## Echo events injected while a key is held emit no second pressed; held
## still fires once per tick.
func test_key_repeat_echoes_emit_no_second_pressed(
		triple_key: String, test_parameters := _KEY_TRIPLES) -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	var action: StringName = _action_of(triple_key)
	var code: int = DefaultBindingEvents.EVENTS[triple_key]

	resolver.feed_event(InputTestSupport.key(code, true))
	for i: int in _ECHO_COUNT:
		resolver.feed_event(InputTestSupport.key(code, true, true))
		resolver.tick(InputTestSupport.DT)
	resolver.feed_event(InputTestSupport.key(code, false))

	var expected: Array = [[&"action_pressed", [action]]]
	expected.append_array(_held_entries(action, _ECHO_COUNT))
	expected.append([&"action_released", [action]])
	assert_array(rec.since(0)).is_equal(expected)


## Second guard: a non-echo press of a key already held is a no-op.
func test_repeated_non_echo_press_of_held_key_is_noop(
		triple_key: String, test_parameters := _KEY_TRIPLES) -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	var action: StringName = _action_of(triple_key)
	var code: int = DefaultBindingEvents.EVENTS[triple_key]

	resolver.feed_event(InputTestSupport.key(code, true))
	resolver.feed_event(InputTestSupport.key(code, true))
	resolver.feed_event(InputTestSupport.key(code, false))

	assert_array(rec.since(0)).is_equal([
		[&"action_pressed", [action]], [&"action_released", [action]]])


## Gamepad buttons have no echo; the held-set check guards a duplicate press.
func test_repeated_pad_button_press_is_noop() -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	var button: int = DefaultBindingEvents.EVENTS["fast_forward:pad:west"]

	resolver.feed_event(InputTestSupport.pad_button(0, button, true))
	resolver.feed_event(InputTestSupport.pad_button(0, button, true))
	resolver.tick(InputTestSupport.DT)
	resolver.feed_event(InputTestSupport.pad_button(0, button, false))

	assert_array(rec.since(0)).is_equal([
		[&"action_pressed", [InputActions.FAST_FORWARD]],
		[&"action_held", [InputActions.FAST_FORWARD]],
		[&"action_released", [InputActions.FAST_FORWARD]]])


## No action held: tick emits nothing.
func test_tick_with_nothing_held_emits_nothing() -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]

	resolver.tick(InputTestSupport.DT)

	assert_array(rec.since(0)).is_empty()
