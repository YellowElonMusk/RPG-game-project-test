## Pad disconnect and reconnect (ADR-0003 §8; GDD States and Transitions).
## Story 022 (AC-14): the active pad's held actions are released, then
## `device_lost()`, then `active_device_changed(KEYBOARD_MOUSE, <unchanged
## style>)`. Story 023 (AC-15): a non-active pad's disconnect emits no
## `device_lost`, and releases only actions no other device still holds.
## Story 024 (AC-16): every pad connection emits `device_restored()`, also
## while unfocused, after which that pad's input is ignored until focus
## returns.
extends GdUnitTestSuite

const PAD := InputResolver.DeviceKind.GAMEPAD
const KBM := InputResolver.DeviceKind.KEYBOARD_MOUSE


func _make() -> Array:
	var resolver := InputResolver.new(InputTestSupport.default_bindings(), InputTestSupport.DEFAULT)
	var rec := InputTestSupport.Recorder.new()
	rec.attach(resolver)
	return [resolver, rec]


# --- Story 022 ---------------------------------------------------------------

## AC-14: releases precede device_lost, then the kind change.
func test_active_pad_lost_releases_then_device_lost_then_kind_change() -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.on_joy_connection(0, true, JoyNames.XBOX_NAME)
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_X, true))
	var mark: int = rec.mark()
	resolver.on_joy_connection(0, false, "")
	assert_array(rec.since(mark)).is_equal([
		[&"action_released", [InputActions.FAST_FORWARD]],
		[&"device_lost", []],
		[&"active_device_changed", [KBM, &"xbox"]],
	])
	assert_int(resolver.active_pad).is_equal(-1)
	assert_int(resolver.active_device).is_equal(KBM)


## Edge case: west, south and the left stick all held -- both releases come
## before device_lost, and a device_lost handler reads a zero move vector.
func test_every_release_precedes_device_lost_and_stick_is_zeroed() -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.on_joy_connection(0, true, JoyNames.XBOX_NAME)
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_X, true))
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_A, true))
	resolver.feed_event(InputTestSupport.pad_axis(0, JOY_AXIS_LEFT_X, 1.0))
	assert_vector(resolver.get_move_vector()).is_not_equal(Vector2.ZERO)
	var seen: Array = [null]
	# Through a WeakRef: a lambda capturing the resolver, connected to the
	# resolver's own signal, is a RefCounted cycle that never frees.
	var resolver_ref: WeakRef = weakref(resolver)
	resolver.device_lost.connect(func() -> void: seen[0] = resolver_ref.get_ref().get_move_vector())
	var mark: int = rec.mark()
	resolver.on_joy_connection(0, false, "")
	var entries: Array = rec.discrete_since(mark)
	assert_int(entries.size()).is_equal(3)
	assert_array(entries.slice(0, 2)).contains_exactly_in_any_order([
		[&"action_released", [InputActions.FAST_FORWARD]],
		[&"action_released", [InputActions.CONFIRM]],
	])
	assert_array(entries[2]).is_equal([&"device_lost", []])
	assert_vector(seen[0]).is_equal(Vector2.ZERO)


## Edge case: fast_forward also held on Shift -- no released(fast_forward);
## device_lost is still emitted.
func test_shared_hold_is_not_released_but_device_lost_fires() -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.on_joy_connection(0, true, JoyNames.XBOX_NAME)
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_X, true))
	resolver.feed_event(InputTestSupport.key(KEY_SHIFT, true))
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_A, true))
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_A, false))
	var mark: int = rec.mark()
	resolver.on_joy_connection(0, false, "")
	assert_array(rec.discrete_since(mark)).is_equal([[&"device_lost", []]])


## Edge case: the repeat state is cleared -- no nav_* after the disconnect
## while ticking.
func test_disconnect_clears_menu_repeat() -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.on_joy_connection(0, true, JoyNames.XBOX_NAME)
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_DPAD_DOWN, true))
	assert_array(rec.nav_since(0)).is_equal([InputActions.NAV_DOWN])
	resolver.on_joy_connection(0, false, "")
	var mark: int = rec.mark()
	for i: int in ceili(2.0 * InputTestSupport.DEFAULT.repeat_delay / InputTestSupport.DT):
		resolver.tick(InputTestSupport.DT)
	assert_array(rec.nav_since(mark)).is_empty()


# --- Story 023 ---------------------------------------------------------------

# Pads 0 and 1 connected, pad 0 made active by a press-and-release, then
# pad 1 holds south (confirm).
func _two_pads_pad1_holds_confirm(resolver: InputResolver) -> void:
	resolver.on_joy_connection(0, true, JoyNames.XBOX_NAME)
	resolver.on_joy_connection(1, true, JoyNames.PLAYSTATION_NAME)
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_A, true))
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_A, false))
	resolver.feed_event(InputTestSupport.pad_button(1, JOY_BUTTON_A, true))


## AC-15 case 1: the non-active pad's sole-held confirm is released; no
## device_lost and no active_device_changed.
func test_non_active_pad_lost_releases_sole_held_action_only() -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	_two_pads_pad1_holds_confirm(resolver)
	var mark: int = rec.mark()
	resolver.on_joy_connection(1, false, "")
	assert_array(rec.since(mark)).is_equal([[&"action_released", [InputActions.CONFIRM]]])
	assert_int(resolver.active_pad).is_equal(0)


## AC-15 case 2: Enter also holds confirm -- nothing is emitted, and the
## next tick emits held(confirm).
func test_non_active_pad_lost_keeps_action_held_by_keyboard() -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	_two_pads_pad1_holds_confirm(resolver)
	resolver.feed_event(InputTestSupport.key(KEY_ENTER, true))
	var mark: int = rec.mark()
	resolver.on_joy_connection(1, false, "")
	assert_array(rec.since(mark)).is_empty()
	resolver.tick(InputTestSupport.DT)
	assert_array(rec.since(mark)).is_equal([[&"action_held", [InputActions.CONFIRM]]])


## Edge case: pad 1's stick deflection disappears from get_move_vector().
func test_non_active_pad_lost_drops_its_stick() -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	resolver.on_joy_connection(0, true, JoyNames.XBOX_NAME)
	resolver.on_joy_connection(1, true, JoyNames.PLAYSTATION_NAME)
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_A, true))
	resolver.feed_event(InputTestSupport.pad_axis(1, JOY_AXIS_LEFT_X, 1.0))
	assert_vector(resolver.get_move_vector()).is_equal(Vector2.RIGHT)
	resolver.on_joy_connection(1, false, "")
	assert_vector(resolver.get_move_vector()).is_equal(Vector2.ZERO)


## Edge case: pad 1 disconnecting with nothing held emits nothing.
func test_non_active_pad_lost_with_nothing_held_emits_nothing() -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.on_joy_connection(0, true, JoyNames.XBOX_NAME)
	resolver.on_joy_connection(1, true, JoyNames.PLAYSTATION_NAME)
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_A, true))
	var mark: int = rec.mark()
	resolver.on_joy_connection(1, false, "")
	assert_array(rec.since(mark)).is_empty()


# --- Story 024 ---------------------------------------------------------------

## AC-16: a reconnect emits device_restored.
func test_reconnect_emits_device_restored() -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.on_joy_connection(0, true, JoyNames.XBOX_NAME)
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_A, true))
	resolver.on_joy_connection(0, false, "")
	var mark: int = rec.mark()
	resolver.on_joy_connection(0, true, JoyNames.XBOX_NAME)
	assert_array(rec.since(mark)).is_equal([[&"device_restored", []]])


## Edge cases: a non-active pad reconnecting, and the first connection at
## boot, also emit it (adopted reading).
func test_non_active_and_boot_connections_emit_device_restored() -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.on_joy_connection(0, true, JoyNames.XBOX_NAME)
	assert_array(rec.since(0)).is_equal([[&"device_restored", []]])
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_A, true))
	resolver.on_joy_connection(1, true, JoyNames.PLAYSTATION_NAME)
	resolver.on_joy_connection(1, false, "")
	var mark: int = rec.mark()
	resolver.on_joy_connection(1, true, JoyNames.PLAYSTATION_NAME)
	assert_array(rec.since(mark)).is_equal([[&"device_restored", []]])


## AC-16: device_restored fires while unfocused, and the pad's input is then
## ignored.
func test_device_restored_while_unfocused_and_pad_input_ignored() -> void:
	var made: Array = _make()
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.set_window_focused(false)
	var mark: int = rec.mark()
	resolver.on_joy_connection(1, true, JoyNames.PLAYSTATION_NAME)
	resolver.feed_event(InputTestSupport.pad_button(1, JOY_BUTTON_A, true))
	assert_array(rec.since(mark)).is_equal([[&"device_restored", []]])
