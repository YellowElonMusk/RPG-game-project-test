## Story 001, AC-1: every default binding (all 8 actions, keyboard and
## gamepad) emits `pressed` on press and `released` on release; every
## `move_*` triple drives `get_move_vector()` instead and is never emitted as
## a discrete action (ADR-0003 §8, pinned reading). Parametrized with
## gdUnit4 `test_parameters` over every triple in `bindings_default.tres`,
## built from the literal fixture in `fixtures/default_binding_events.gd`
## (never the resolver's own token parser).
extends GdUnitTestSuite

## Each discrete-action triple key, matching `DefaultBindingEvents.EVENTS`.
const _DISCRETE_TRIPLE_KEYS: Array = [
	["confirm:key:Enter"], ["confirm:key:Space"], ["confirm:key:Z"], ["confirm:pad:south"],
	["cancel:key:Escape"], ["cancel:key:Backspace"], ["cancel:key:X"], ["cancel:pad:east"],
	["menu:key:Tab"], ["menu:key:M"], ["menu:pad:start"],
	["inspect:key:I"], ["inspect:key:Q"], ["inspect:pad:north"],
	["page_left:key:1"], ["page_left:pad:left_shoulder"],
	["page_right:key:3"], ["page_right:pad:right_shoulder"],
	["fast_forward:key:Shift"], ["fast_forward:pad:west"],
]

## Each `move_*` triple key, matching `DefaultBindingEvents.EVENTS`.
const _MOVE_TRIPLE_KEYS: Array = [
	["move_up:key:W"], ["move_up:key:Up"], ["move_up:pad:dpad_up"], ["move_up:pad_axis:left_y-"],
	["move_down:key:S"], ["move_down:key:Down"], ["move_down:pad:dpad_down"], ["move_down:pad_axis:left_y+"],
	["move_left:key:A"], ["move_left:key:Left"], ["move_left:pad:dpad_left"], ["move_left:pad_axis:left_x-"],
	["move_right:key:D"], ["move_right:key:Right"], ["move_right:pad:dpad_right"], ["move_right:pad_axis:left_x+"],
]

## Expected unit vector per `move_*` action (ADR-0003 §8 pinned sign convention).
const _MOVE_UNIT_VECTOR: Dictionary = {
	&"move_up": Vector2(0.0, -1.0),
	&"move_down": Vector2(0.0, 1.0),
	&"move_left": Vector2(-1.0, 0.0),
	&"move_right": Vector2(1.0, 0.0),
}


## Edge case: the fixture's row count equals the data's triple count, which
## catches a triple added to `bindings_default.tres` with no literal row.
func test_default_binding_events_row_count_equals_bindings_size() -> void:
	var bindings: InputBindings = InputTestSupport.default_bindings()
	assert_int(DefaultBindingEvents.EVENTS.size()).override_failure_message(
			"fixture rows vs bindings.bindings").is_equal(bindings.bindings.size())


## Guards the two literal lists above against drift from the fixture: every
## fixture key is covered by exactly one of them.
func test_every_fixture_row_is_covered_by_discrete_or_move() -> void:
	var covered: Dictionary = {}
	for row: Array in _DISCRETE_TRIPLE_KEYS:
		covered[row[0]] = true
	for row: Array in _MOVE_TRIPLE_KEYS:
		assert_bool(covered.has(row[0])).override_failure_message(
				"%s listed in both _DISCRETE_TRIPLE_KEYS and _MOVE_TRIPLE_KEYS" % row[0]).is_false()
		covered[row[0]] = true
	for triple_key: String in DefaultBindingEvents.EVENTS:
		assert_bool(covered.has(triple_key)).override_failure_message(
				"%s missing from _DISCRETE_TRIPLE_KEYS/_MOVE_TRIPLE_KEYS" % triple_key).is_true()
	assert_int(covered.size()).is_equal(DefaultBindingEvents.EVENTS.size())


## Test: every default discrete binding emits one pressed and one released.
## Edge cases: physical_keycode matching (keycode left at KEY_NONE via the
## fixture factories); each JoyButton triple fed with device = 0 and again
## with device = 1; row-count parity (asserted separately above).
func test_default_discrete_binding_emits_pressed_then_released(
		triple_key: String, test_parameters := _DISCRETE_TRIPLE_KEYS) -> void:
	var parts: PackedStringArray = triple_key.split(":", true, 2)
	var action: StringName = StringName(parts[0])
	var device: String = parts[1]
	var literal: Variant = DefaultBindingEvents.EVENTS[triple_key]

	if device == "key":
		_assert_discrete_edge(triple_key, action,
				func() -> InputEvent: return InputTestSupport.key(literal, true),
				func() -> InputEvent: return InputTestSupport.key(literal, false))
	elif device == "pad":
		for pad_device: int in [0, 1]:
			_assert_discrete_edge(triple_key, action,
					func() -> InputEvent: return InputTestSupport.pad_button(pad_device, literal, true),
					func() -> InputEvent: return InputTestSupport.pad_button(pad_device, literal, false))
	else:
		fail("unexpected device %s for discrete triple %s" % [device, triple_key])


## Test: every default move binding drives the vector, never a discrete
## action. Edge case: axis triples at raw ±1.0 give exactly ±1 after the
## rescale (no deadzone is implemented yet, so the raw magnitude passes
## through unchanged).
func test_default_move_binding_drives_vector_never_a_discrete_action(
		triple_key: String, test_parameters := _MOVE_TRIPLE_KEYS) -> void:
	_assert_move_binding(triple_key, InputTestSupport.DEFAULT)


## Edge case: the move test runs once with NON_DEFAULT -- the deadzone has
## no effect at raw ±1.0 / a full digital press, since this story reads no
## config value at all.
func test_default_move_binding_drives_vector_with_non_default_config(
		triple_key: String, test_parameters := _MOVE_TRIPLE_KEYS) -> void:
	_assert_move_binding(triple_key, InputTestSupport.NON_DEFAULT)


func _assert_discrete_edge(triple_key: String, action: StringName,
		build_press: Callable, build_release: Callable) -> void:
	var resolver := InputResolver.new(InputTestSupport.default_bindings(), InputTestSupport.DEFAULT)
	var rec := InputTestSupport.Recorder.new()
	rec.attach(resolver)

	resolver.feed_event(build_press.call())
	resolver.feed_event(build_release.call())

	assert_array(rec.entries).override_failure_message(
			"%s: %s" % [triple_key, rec.entries]).is_equal([
			[&"action_pressed", [action]],
			[&"action_released", [action]],
	])


func _assert_move_binding(triple_key: String, config: InputConfig) -> void:
	var parts: PackedStringArray = triple_key.split(":", true, 2)
	var action: StringName = StringName(parts[0])
	var device: String = parts[1]
	var literal: Variant = DefaultBindingEvents.EVENTS[triple_key]
	var expected: Vector2 = _MOVE_UNIT_VECTOR[action]

	var resolver := InputResolver.new(InputTestSupport.default_bindings(), config)
	var rec := InputTestSupport.Recorder.new()
	rec.attach(resolver)

	var press_event: InputEvent
	var release_event: InputEvent
	match device:
		"key":
			press_event = InputTestSupport.key(literal, true)
			release_event = InputTestSupport.key(literal, false)
		"pad":
			press_event = InputTestSupport.pad_button(0, literal, true)
			release_event = InputTestSupport.pad_button(0, literal, false)
		"pad_axis":
			var axis: int = literal[0]
			var value: float = literal[1]
			press_event = InputTestSupport.pad_axis(0, axis, value)
			release_event = InputTestSupport.pad_axis(0, axis, 0.0)
		_:
			fail("unexpected device %s for move triple %s" % [device, triple_key])
			return

	resolver.feed_event(press_event)
	assert_vector(resolver.get_move_vector()).override_failure_message(
			"%s after press" % triple_key).is_equal_approx(
			expected, Vector2(InputTestSupport.EPS_V, InputTestSupport.EPS_V))

	resolver.feed_event(release_event)
	assert_vector(resolver.get_move_vector()).override_failure_message(
			"%s after release" % triple_key).is_equal_approx(
			Vector2.ZERO, Vector2(InputTestSupport.EPS_V, InputTestSupport.EPS_V))

	for entry: Array in rec.entries:
		assert_str(String(entry[0])).override_failure_message(
				"%s produced a discrete signal: %s" % [triple_key, entry]).is_not_equal("action_pressed")
		assert_str(String(entry[0])).override_failure_message(
				"%s produced a discrete signal: %s" % [triple_key, entry]).is_not_equal("action_released")
