## Story 025, AC-17: focus loss releases every held action before
## `focus_lost`, pad input is dropped while unfocused, and a key still held
## after `focus_gained` needs a fresh press. Written to the QA Test Cases in
## `production/epics/input-system/story-025-focus-lost-and-gained.md` --
## no new cases invented.
extends GdUnitTestSuite


func _make_resolver() -> InputResolver:
	var resolver := InputResolver.new(InputTestSupport.default_bindings(), InputTestSupport.DEFAULT)
	return resolver


func test_focus_loss_releases_every_held_action_before_focus_lost() -> void:
	# Arrange: Enter and Shift held, and the stick raw (1, 0) on pad 0.
	var resolver: InputResolver = _make_resolver()
	var rec := InputTestSupport.Recorder.new()
	rec.attach(resolver)
	resolver.feed_event(InputTestSupport.key(KEY_ENTER, true))
	resolver.feed_event(InputTestSupport.key(KEY_SHIFT, true))
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, 1.0))
	var mark: int = rec.mark()

	# Act
	resolver.set_window_focused(false)

	# Assert: both releases before focus_lost, in either order.
	var since: Array = rec.since(mark)
	assert_int(since.size()).is_equal(3)
	assert_array(since).override_failure_message(
			"expected two releases then focus_lost: %s" % [since]).contains_exactly_in_any_order([
				[&"action_released", [InputActions.CONFIRM]],
				[&"action_released", [InputActions.FAST_FORWARD]],
				[&"focus_lost", []],
			])
	assert_int(since.find([&"focus_lost", []])).is_equal(since.size() - 1)
	assert_vector(resolver.get_move_vector()).is_equal_approx(
			Vector2.ZERO, Vector2(InputTestSupport.EPS_V, InputTestSupport.EPS_V))


func test_pad_input_while_unfocused_emits_nothing() -> void:
	# Arrange: R unfocused.
	var resolver: InputResolver = _make_resolver()
	var rec := InputTestSupport.Recorder.new()
	rec.attach(resolver)
	resolver.set_window_focused(false)
	var mark: int = rec.mark()

	# Act: pad south press and release, left_x at raw 1.0, then tick through repeat_delay.
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_A, true))
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_A, false))
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, 1.0))
	resolver.tick(InputTestSupport.DEFAULT.repeat_delay)

	# Assert: no entries at all; get_move_vector() stays ZERO.
	assert_array(rec.since(mark)).is_empty()
	assert_vector(resolver.get_move_vector()).is_equal_approx(
			Vector2.ZERO, Vector2(InputTestSupport.EPS_V, InputTestSupport.EPS_V))


func test_keyboard_input_while_unfocused_is_processed_normally() -> void:
	# Arrange: R unfocused (documented reading: the OS doesn't normally
	# deliver keyboard input while unfocused, so any received key is normal).
	var resolver: InputResolver = _make_resolver()
	var rec := InputTestSupport.Recorder.new()
	rec.attach(resolver)
	resolver.set_window_focused(false)
	var mark: int = rec.mark()

	# Act
	resolver.feed_event(InputTestSupport.key(KEY_ENTER, true))

	# Assert
	assert_array(rec.since(mark)).contains_exactly([[&"action_pressed", [InputActions.CONFIRM]]])


func test_key_still_held_after_focus_return_needs_a_fresh_press() -> void:
	# Arrange: Enter held; focus lost then regained.
	var resolver: InputResolver = _make_resolver()
	var rec := InputTestSupport.Recorder.new()
	rec.attach(resolver)
	resolver.feed_event(InputTestSupport.key(KEY_ENTER, true))
	resolver.set_window_focused(false)
	resolver.set_window_focused(true)
	var mark: int = rec.mark()

	# Act: 3 echo events, tick x3, the release, then a fresh press.
	resolver.feed_event(InputTestSupport.key(KEY_ENTER, true, true))
	resolver.tick(InputTestSupport.DT)
	resolver.feed_event(InputTestSupport.key(KEY_ENTER, true, true))
	resolver.tick(InputTestSupport.DT)
	resolver.feed_event(InputTestSupport.key(KEY_ENTER, true, true))
	resolver.tick(InputTestSupport.DT)
	resolver.feed_event(InputTestSupport.key(KEY_ENTER, false))
	resolver.feed_event(InputTestSupport.key(KEY_ENTER, true))

	# Assert: pressed(confirm) only at the fresh press, nothing before it.
	assert_array(rec.since(mark)).contains_exactly([[&"action_pressed", [InputActions.CONFIRM]]])


func test_pad_button_held_through_focus_cycle_needs_a_fresh_press() -> void:
	# Edge case: the pad south button held through the cycle.
	var resolver: InputResolver = _make_resolver()
	var rec := InputTestSupport.Recorder.new()
	rec.attach(resolver)
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_A, true))
	resolver.set_window_focused(false)
	resolver.set_window_focused(true)
	var mark: int = rec.mark()

	# Act: its release (post-return) emits nothing, a fresh press emits pressed.
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_A, false))
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_A, true))

	# Assert
	assert_array(rec.since(mark)).contains_exactly([[&"action_pressed", [InputActions.CONFIRM]]])


func test_stick_recentre_latch_blocks_nav_until_inside_deadzone() -> void:
	# Edge case: left_x held at raw 1.0 through focus return gives ZERO and
	# no nav until a value inside the deadzone is fed, then raw 1.0 counts again.
	var resolver: InputResolver = _make_resolver()
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, 1.0))
	resolver.set_window_focused(false)
	resolver.set_window_focused(true)

	# Still held through focus return: latched, ZERO.
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, 1.0))
	assert_vector(resolver.get_move_vector()).is_equal_approx(
			Vector2.ZERO, Vector2(InputTestSupport.EPS_V, InputTestSupport.EPS_V))

	# A value inside the deadzone clears the latch.
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, 0.0))
	assert_vector(resolver.get_move_vector()).is_equal_approx(
			Vector2.ZERO, Vector2(InputTestSupport.EPS_V, InputTestSupport.EPS_V))

	# Raw 1.0 counts again.
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, 1.0))
	assert_vector(resolver.get_move_vector()).is_equal_approx(
			Vector2(1.0, 0.0), Vector2(InputTestSupport.EPS_V, InputTestSupport.EPS_V))


func test_focus_gained_is_emitted_exactly_once() -> void:
	var resolver: InputResolver = _make_resolver()
	var rec := InputTestSupport.Recorder.new()
	rec.attach(resolver)
	resolver.set_window_focused(false)
	var mark: int = rec.mark()

	resolver.set_window_focused(true)
	# A repeated call with the same value must not re-emit.
	resolver.set_window_focused(true)

	assert_array(rec.since(mark)).contains_exactly([[&"focus_gained", []]])
