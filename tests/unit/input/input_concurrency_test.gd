## Concurrency of discrete actions (ADR-0003 §1, §3, §8).
## Story 007, AC-18: `confirm` and `cancel` pressed in the same frame (two
## `feed_event()` calls, no `tick()` between) are both emitted, in input
## order. Story 008, AC-19: the same action held on two sources -- releasing
## one emits nothing, releasing the last emits exactly one `released`; every
## new source press emits `pressed` (AC-19/AC-27 ruling 2026-10-23); `held`
## fires once per tick however many sources hold the action.
extends GdUnitTestSuite


func _make() -> Array:
	var resolver := InputResolver.new(InputTestSupport.default_bindings(), InputTestSupport.DEFAULT)
	var rec := InputTestSupport.Recorder.new()
	rec.attach(resolver)
	return [resolver, rec]


func _ev(triple_key: String, pressed: bool, device: int = 0) -> InputEvent:
	var literal: int = DefaultBindingEvents.EVENTS[triple_key]
	if triple_key.contains(":pad:"):
		return InputTestSupport.pad_button(device, literal, pressed)
	return InputTestSupport.key(literal, pressed)


func test_same_frame_confirm_then_cancel_emitted_in_order() -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.feed_event(_ev("confirm:key:Enter", true))
	resolver.feed_event(_ev("cancel:key:Escape", true))
	assert_array(rec.since(0)).is_equal([
		[&"action_pressed", [InputActions.CONFIRM]], [&"action_pressed", [InputActions.CANCEL]]])


func test_same_frame_cancel_then_confirm_emitted_in_order() -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.feed_event(_ev("cancel:pad:east", true))
	resolver.feed_event(_ev("confirm:pad:south", true))
	assert_array(rec.since(0)).is_equal([
		[&"action_pressed", [InputActions.CANCEL]], [&"action_pressed", [InputActions.CONFIRM]]])


## Emission is synchronous in feed_event: nothing is deferred to tick().
func test_same_frame_presses_emit_before_tick() -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.feed_event(_ev("confirm:key:Enter", true))
	assert_int(rec.mark()).is_equal(1)
	resolver.feed_event(_ev("cancel:key:Escape", true))
	assert_int(rec.mark()).is_equal(2)


# Shared AC-19 body: source A then B press, A release (nothing), B release
# (exactly one released); one held per tick while both hold.
func _assert_two_source_hold(first: InputEvent, second: InputEvent,
		first_up: InputEvent, second_up: InputEvent) -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.feed_event(first)
	resolver.feed_event(second)
	resolver.tick(InputTestSupport.DT)
	assert_array(rec.since(0)).is_equal([
		[&"action_pressed", [InputActions.CONFIRM]],
		[&"action_pressed", [InputActions.CONFIRM]],
		[&"action_held", [InputActions.CONFIRM]]])
	var mark: int = rec.mark()
	resolver.feed_event(first_up)
	assert_array(rec.since(mark)).is_empty()
	resolver.tick(InputTestSupport.DT)
	assert_array(rec.since(mark)).is_equal([[&"action_held", [InputActions.CONFIRM]]])
	mark = rec.mark()
	resolver.feed_event(second_up)
	resolver.tick(InputTestSupport.DT)
	assert_array(rec.since(mark)).is_equal([[&"action_released", [InputActions.CONFIRM]]])


func test_keyboard_and_pad_release_one_emits_nothing_then_one_released() -> void:
	_assert_two_source_hold(
			_ev("confirm:key:Enter", true), _ev("confirm:pad:south", true),
			_ev("confirm:key:Enter", false), _ev("confirm:pad:south", false))


func test_two_pads_release_one_emits_nothing_then_one_released() -> void:
	_assert_two_source_hold(
			_ev("confirm:pad:south", true, 0), _ev("confirm:pad:south", true, 1),
			_ev("confirm:pad:south", false, 1), _ev("confirm:pad:south", false, 0))


func test_two_keys_release_one_emits_nothing_then_one_released() -> void:
	_assert_two_source_hold(
			_ev("confirm:key:Enter", true), _ev("confirm:key:Space", true),
			_ev("confirm:key:Space", false), _ev("confirm:key:Enter", false))


## A stray release of a source that never pressed emits nothing.
func test_release_of_unheld_source_emits_nothing() -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.feed_event(_ev("confirm:key:Enter", true))
	var mark: int = rec.mark()
	resolver.feed_event(_ev("confirm:pad:south", false))
	assert_array(rec.since(mark)).is_empty()
