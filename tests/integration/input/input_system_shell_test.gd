## Story 025, T-SHELL (folded, ADR-0003 §2, §5, §9; Migration Plan step 2
## items 2-3): the InputSystem shell strips the `ui_*` device bindings,
## forwards events without consuming them, ignores InputEventAction, and
## maps focus notifications and joypad connections onto the resolver.
## Written to the QA Test Cases in
## `production/epics/input-system/story-025-focus-lost-and-gained.md` --
## no new cases invented. Real OS delivery of
## NOTIFICATION_APPLICATION_FOCUS_OUT/IN is deferred to manual verification
## (production/qa/evidence/); this suite drives `_notification()` directly.
extends GdUnitTestSuite

const _STRIPPED_ACTIONS: Array[StringName] = [
	&"ui_accept", &"ui_cancel",
	&"ui_up", &"ui_down", &"ui_left", &"ui_right",
	&"ui_focus_next", &"ui_focus_prev",
	&"ui_page_up", &"ui_page_down", &"ui_home", &"ui_end",
]

var _resolver: InputResolver
var _rec: InputTestSupport.Recorder
var _node: InputSystem


func before_test() -> void:
	_resolver = InputResolver.new(InputTestSupport.default_bindings(), InputTestSupport.DEFAULT)
	_rec = InputTestSupport.Recorder.new()
	_rec.attach(_resolver)
	_node = auto_free(InputSystem.new())
	add_child(_node)
	_node.setup(_resolver)


func after_test() -> void:
	# Restore the global InputMap this suite mutated (ADR-0003 §5 strip).
	InputMap.load_from_project_settings()


func test_ui_actions_have_no_device_events() -> void:
	for action: StringName in _STRIPPED_ACTIONS:
		assert_array(InputMap.action_get_events(action)).override_failure_message(
				"%s still has device events" % action).is_empty()
	# ui_select's presence on 4.7.2 is unverified (ADR-0003 Engine Notes).
	if InputMap.has_action(&"ui_select"):
		assert_array(InputMap.action_get_events(&"ui_select")).override_failure_message(
				"ui_select still has device events").is_empty()


func test_ui_text_backspace_keeps_its_events() -> void:
	assert_array(InputMap.action_get_events(&"ui_text_backspace")).override_failure_message(
			"ui_text_backspace lost its device events").is_not_empty()


func test_ignore_joypad_on_unfocused_application_project_setting_is_true() -> void:
	assert_bool(ProjectSettings.get_setting(
			"input_devices/joypads/ignore_joypad_on_unfocused_application", false)).is_true()


func test_input_event_action_produces_no_resolver_signal() -> void:
	var mark: int = _rec.mark()

	var action_event := InputEventAction.new()
	action_event.action = &"ui_accept"
	action_event.pressed = true
	_node._input(action_event)

	assert_array(_rec.since(mark)).is_empty()


func test_focus_out_then_in_are_recorded() -> void:
	var mark: int = _rec.mark()

	_node._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_node._notification(NOTIFICATION_APPLICATION_FOCUS_IN)

	assert_array(_rec.since(mark)).contains_exactly([
		[&"focus_lost", []],
		[&"focus_gained", []],
	])


func test_joy_connection_changed_is_forwarded_to_resolver() -> void:
	var mark: int = _rec.mark()

	_node._on_joy_connection_changed(0, true)

	assert_array(_rec.since(mark)).contains_exactly([[&"device_restored", []]])


func test_process_mode_is_always() -> void:
	assert_int(_node.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


## Edge case: _input never calls set_input_as_handled -- an InputEventKey
## forwarded through the shell is still unhandled (viewport check).
func test_input_never_marks_a_key_event_as_handled() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ENTER
	event.pressed = true

	get_viewport().push_input(event)

	assert_bool(get_viewport().is_input_handled()).override_failure_message(
			"InputSystem._input() must never call set_input_as_handled()").is_false()


## Edge case: a forwarded key event still reaches the resolver (not consumed).
func test_input_forwards_key_events_to_the_resolver() -> void:
	var mark: int = _rec.mark()

	_node._input(InputTestSupport.key(KEY_ENTER, true))

	assert_array(_rec.since(mark)).contains_exactly([[&"action_pressed", [InputActions.CONFIRM]]])
