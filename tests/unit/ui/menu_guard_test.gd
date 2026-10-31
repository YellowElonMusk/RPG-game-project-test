## Story 058, AC-54 (GDD rule 9 "When a menu opens"; ADR-0008 §6-§7):
## `MenuGuard` on the mode-time clock at dt = 1/60 with the test config
## `input_guard = 9.5 / 60` s -- presses on frames 1-9 are refused with exactly
## one refusal event each, frame 10+ is accepted; held-at-open actions are
## swallowed until released; echoes are never presses; the `GuardBlocker`
## turns pointer clicks into refusals; `PointerFocusSync` keeps the default
## focus until the pointer has moved `pointer_switch_px`; and each of the four
## required screens' default focus follows the GDD.
extends GdUnitTestSuite

const _DT := 1.0 / 60.0
const _GUARD := 9.5 / 60.0
const _MENU_ACTIONS: Array[StringName] = [&"confirm", &"cancel", &"nav_up", &"nav_down",
		&"nav_left", &"nav_right", &"page_left", &"page_right"]

var _now: float = 0.0
var _held: Array[StringName] = []


func before_test() -> void:
	_now = 100.0
	_held = []


func _guard() -> MenuGuard:
	return MenuGuard.new(func() -> float: return _now,
			func() -> Array[StringName]: return _held, _GUARD)


func _screen() -> Control:
	var root: Control = auto_free(Control.new())
	return root


func _at_frame(t_open: float, frame: int) -> void:
	_now = t_open + float(frame) * _DT


func test_presses_on_frames_one_to_nine_are_refused_with_one_event_each() -> void:
	for action: StringName in _MENU_ACTIONS:
		var guard := _guard()
		var refusals: Array[StringName] = []
		guard.refused.connect(func(a: StringName) -> void: refusals.append(a))
		var t_open: float = _now
		guard.open(_screen())
		for frame: int in range(1, 10):
			_at_frame(t_open, frame)
			assert_int(guard.filter(action, true)).override_failure_message(
					"%s frame %d" % [action, frame]).is_equal(MenuGuard.Verdict.REFUSE)
			assert_int(refusals.size()).is_equal(frame)
		_at_frame(t_open, 10)
		assert_int(guard.filter(action, true)).is_equal(MenuGuard.Verdict.PASS)
		assert_int(refusals.size()).is_equal(9)
		assert_bool(guard.is_guarding()).is_false()
		_now = t_open


func test_releases_always_pass_and_are_not_refusals() -> void:
	var guard := _guard()
	var refusals: Array[int] = [0]
	guard.refused.connect(func(_a: StringName) -> void: refusals[0] += 1)
	guard.open(_screen())
	_now += _DT
	assert_int(guard.filter(&"confirm", false)).is_equal(MenuGuard.Verdict.PASS)
	assert_int(refusals[0]).is_equal(0)


func test_confirm_held_since_before_open_never_confirms_until_released_and_repressed() -> void:
	_held = [&"confirm"]
	var guard := _guard()
	var refusals: Array[int] = [0]
	guard.refused.connect(func(_a: StringName) -> void: refusals[0] += 1)
	var t_open: float = _now
	guard.open(_screen())
	for frame: int in range(1, 600):
		_at_frame(t_open, frame)
		assert_int(guard.filter(&"confirm", true)).is_equal(MenuGuard.Verdict.SWALLOW)
	assert_int(refusals[0]).override_failure_message("held input gives no feedback").is_equal(0)
	_held = []
	guard.on_released(&"confirm")
	assert_int(guard.filter(&"confirm", true)).is_equal(MenuGuard.Verdict.PASS)


func test_direction_held_since_before_open_never_moves_through_repeats() -> void:
	_held = [&"nav_down"]
	var guard := _guard()
	var t_open: float = _now
	guard.open(_screen())
	# Navigation repeats arrive as further nav presses while held.
	for frame: int in range(1, 300, 5):
		_at_frame(t_open, frame)
		assert_int(guard.filter(&"nav_down", true)).is_equal(MenuGuard.Verdict.SWALLOW)
	# Another direction pressed fresh after the guard is accepted.
	assert_int(guard.filter(&"nav_up", true)).is_equal(MenuGuard.Verdict.PASS)
	guard.on_released(&"nav_down")
	assert_int(guard.filter(&"nav_down", true)).is_equal(MenuGuard.Verdict.PASS)


## A held action released and pressed again inside the window is refused
## like any other press (it is a new press during the guard).
func test_held_then_released_inside_the_window_is_refused_not_swallowed() -> void:
	_held = [&"cancel"]
	var guard := _guard()
	var t_open: float = _now
	guard.open(_screen())
	_at_frame(t_open, 2)
	guard.on_released(&"cancel")
	_at_frame(t_open, 4)
	assert_int(guard.filter(&"cancel", true)).is_equal(MenuGuard.Verdict.REFUSE)


func test_key_repeat_echoes_are_never_presses() -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_ENTER
	press.pressed = true
	var echo := press.duplicate() as InputEventKey
	echo.echo = true
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	assert_bool(MenuGuard.is_new_press(press)).is_true()
	assert_bool(MenuGuard.is_new_press(echo)).is_false()
	assert_bool(MenuGuard.is_new_press(release)).is_false()


func test_guard_blocker_turns_clicks_into_refusals_and_goes_away() -> void:
	var guard := _guard()
	var root := _screen()
	var other: Control = Control.new()
	root.add_child(other)
	var refusals: Array[StringName] = []
	guard.refused.connect(func(a: StringName) -> void: refusals.append(a))
	var t_open: float = _now
	guard.open(root)
	var blocker: Control = root.get_child(root.get_child_count() - 1)
	assert_str(String(blocker.name)).is_equal("GuardBlocker")
	assert_int(blocker.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_bool(blocker is Container).is_false()
	assert_float(blocker.anchor_right).is_equal(1.0)
	assert_float(blocker.anchor_bottom).is_equal(1.0)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	for frame: int in range(1, 10):
		_at_frame(t_open, frame)
		blocker.gui_input.emit(click)
	assert_int(refusals.size()).is_equal(9)
	assert_str(String(refusals[0])).is_equal(String(MenuGuard.POINTER_ACTION))
	_at_frame(t_open, 10)
	guard.tick()
	assert_bool(root.has_node("GuardBlocker")).is_false()


func test_reopen_resets_the_window_and_the_held_snapshot() -> void:
	var guard := _guard()
	guard.open(_screen())
	_now += 1.0
	assert_int(guard.filter(&"confirm", true)).is_equal(MenuGuard.Verdict.PASS)
	_held = [&"confirm"]
	guard.open(_screen())
	_now += _DT
	assert_int(guard.filter(&"confirm", true)).is_equal(MenuGuard.Verdict.SWALLOW)


func test_input_guard_knob_lives_in_presentation_config() -> void:
	var config := PresentationConfig.new()
	assert_float(config.input_guard).is_equal_approx(0.15, 1e-6)
	var guard := MenuGuard.new(func() -> float: return _now,
			func() -> Array[StringName]: return _held, config.input_guard)
	assert_float(guard.guard_seconds).is_equal(config.input_guard)


# --- UiFeedback ---------------------------------------------------------------

func test_refuse_records_once_per_call_and_accepts_null() -> void:
	var feedback := UiFeedback.new()
	var seen: Array = []
	feedback.refused.connect(func(c: Control) -> void: seen.append(c))
	var button: Button = auto_free(Button.new())
	feedback.refuse(button)
	feedback.refuse(null)
	assert_int(feedback.refusal_count).is_equal(2)
	assert_object(seen[0]).is_same(button)
	assert_object(seen[1]).is_null()


# --- PointerFocusSync ---------------------------------------------------------

func _menu() -> Array:
	var root: Control = auto_free(Control.new())
	add_child(root)
	var first := Button.new()
	var second := Button.new()
	root.add_child(first)
	root.add_child(second)
	first.grab_focus()
	var sync := PointerFocusSync.new()
	sync.switch_px = InputConfig.new().pointer_switch_px
	root.add_child(sync)
	sync.track(first)
	sync.track(second)
	sync.reset()
	return [root, first, second, sync]


func test_resting_pointer_over_a_button_keeps_the_default_focus() -> void:
	var m: Array = _menu()
	(m[2] as Button).mouse_entered.emit()
	assert_object((m[0] as Control).get_viewport().gui_get_focus_owner()).is_same(m[1])


func test_pointer_one_px_short_keeps_focus_then_reaching_threshold_moves_it() -> void:
	var m: Array = _menu()
	var sync: PointerFocusSync = m[3]
	for i: int in sync.switch_px - 1:
		sync.add_motion(Vector2(1, 0))
	(m[2] as Button).mouse_entered.emit()
	assert_object((m[0] as Control).get_viewport().gui_get_focus_owner()).is_same(m[1])
	sync.add_motion(Vector2(0, 1))
	(m[2] as Button).mouse_entered.emit()
	assert_object((m[0] as Control).get_viewport().gui_get_focus_owner()).is_same(m[2])


func test_menu_guard_open_resets_the_pointer_counter() -> void:
	var m: Array = _menu()
	var sync: PointerFocusSync = m[3]
	for i: int in sync.switch_px + 3:
		sync.add_motion(Vector2(1, 0))
	var guard := _guard()
	guard.opened.connect(sync.reset)
	guard.open(_screen())
	(m[2] as Button).mouse_entered.emit()
	assert_object((m[0] as Control).get_viewport().gui_get_focus_owner()).is_same(m[1])


# --- Default focus on the four required screens --------------------------------

func test_command_menu_focuses_last_used_if_available_and_free_else_attack() -> void:
	var commands: Dictionary = {
		&"attack": {"available": true, "mp_cost": 0},
		&"defend": {"available": true, "mp_cost": 0},
		&"special": {"available": true, "mp_cost": 6},
		&"item": {"available": false, "mp_cost": 0}}
	assert_str(String(MenuDefaultFocus.command_menu(&"defend", commands))).is_equal("defend")
	assert_str(String(MenuDefaultFocus.command_menu(&"special", commands))).is_equal("attack")
	assert_str(String(MenuDefaultFocus.command_menu(&"item", commands))).is_equal("attack")
	assert_str(String(MenuDefaultFocus.command_menu(&"", commands))).is_equal("attack")
	assert_str(String(MenuDefaultFocus.command_menu(&"gone", commands))).is_equal("attack")


func test_target_selection_focuses_the_first_living_target() -> void:
	assert_int(MenuDefaultFocus.target_selection([false, false, true, true])).is_equal(2)
	assert_int(MenuDefaultFocus.target_selection([true, false])).is_equal(0)
	assert_int(MenuDefaultFocus.target_selection([false])).is_equal(-1)


func test_defeat_prompt_focuses_retry_and_results_focus_continue() -> void:
	assert_str(String(MenuDefaultFocus.DEFEAT_PROMPT)).is_equal("retry")
	assert_str(String(MenuDefaultFocus.RESULTS)).is_equal("continue")
	assert_array(MenuDefaultFocus.guarded_screens()).contains_exactly_in_any_order(
			[&"command_menu", &"target_selection", &"defeat_prompt", &"results"])
