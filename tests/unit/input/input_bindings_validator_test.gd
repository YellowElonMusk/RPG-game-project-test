## Story 003, AC-3 and T-FALLBACK: `InputBindingsValidator.validate()` reports
## an error for an action with no keyboard binding, an action with no gamepad
## binding, and a key bound to two actions; the valid default set reports
## zero errors; the fallback bindings parse and compile; the validator is
## registered with the catalog before `load_all()` (ADR-0003 §6, ADR-0004 §4).
extends GdUnitTestSuite

const _FIXTURE_ROOT: String = "res://tests/unit/input/fixtures/bindings"


# Test-only spy (no class_name, like spy_content_catalog.gd): records the
# order `register_record_validator()` and `load_all()` are called in, so the
# "registered before load_all" QA case can be proven without inspecting the
# catalog's private state. The explicit `return` in load_all() is load-bearing
# on Godot 4.7 (a typed override with a fall-through path hard-errors).
class _RegistrationOrderSpy:
	extends ContentCatalogService

	var calls: Array[String] = []

	func register_record_validator(type: StringName, validator: Callable) -> void:
		calls.append("register_record_validator:%s" % type)
		super(type, validator)

	func load_all(data_root: String = "res://data") -> Error:
		calls.append("load_all")
		return super(data_root)


func _load_fixture(fixture_name: String) -> InputBindings:
	return ResourceLoader.load("%s/%s.tres" % [_FIXTURE_ROOT, fixture_name], "",
			ResourceLoader.CACHE_MODE_IGNORE) as InputBindings


# --- AC-3: the valid default set reports zero errors ---

func test_valid_default_set_reports_zero_errors() -> void:
	var record: InputBindings = InputTestSupport.default_bindings()

	var errors: Array[Dictionary] = InputBindingsValidator.validate(record)

	assert_array(errors).override_failure_message("errors: %s" % [errors]).is_empty()


## Edge case: purity -- running it twice gives the same result.
func test_valid_default_set_validate_is_pure() -> void:
	var record: InputBindings = InputTestSupport.default_bindings()

	var first: Array[Dictionary] = InputBindingsValidator.validate(record)
	var second: Array[Dictionary] = InputBindingsValidator.validate(record)

	assert_array(second).is_equal(first)


# --- AC-3: each invalid fixture reports exactly one error with the right field ---

const _INVALID_FIXTURES: Array = [
	["no_keyboard", "bindings.menu.key"],
	["no_gamepad", "bindings.inspect.pad"],
	["key_double_bound", "bindings.key:Enter"],
]


func test_invalid_fixture_reports_one_error(
		fixture_name: String, expected_field: String, test_parameters := _INVALID_FIXTURES) -> void:
	var record: InputBindings = _load_fixture(fixture_name)

	var errors: Array[Dictionary] = InputBindingsValidator.validate(record)

	assert_array(errors).override_failure_message("%s: %s" % [fixture_name, errors]).has_size(1)
	assert_that(errors[0]["severity"]).is_equal(&"error")
	assert_str(String(errors[0]["field"])).is_equal(expected_field)


## Edge case: the same token on key vs pad is fine -- the valid default set
## already pairs "menu:key:M" beside "menu:pad:start" with no false positive
## (proven by the zero-errors test above; restated here for the record).
func test_same_token_different_device_is_not_double_bound() -> void:
	var record: InputBindings = InputTestSupport.default_bindings()

	var errors: Array[Dictionary] = InputBindingsValidator.validate(record)

	for entry: Dictionary in errors:
		assert_str(String(entry["field"])).override_failure_message(
				"unexpected double-bound entry: %s" % [entry]).does_not_contain("menu")


## Edge case: a pad button double-bound ("cancel:pad:south" added) gives one
## entry, field "bindings.pad:south".
func test_pad_double_bound_reports_one_error() -> void:
	var record: InputBindings = InputTestSupport.default_bindings()
	record.bindings.append({"action": "cancel", "device": "pad", "input": "south"})

	var errors: Array[Dictionary] = InputBindingsValidator.validate(record)

	assert_array(errors).override_failure_message("errors: %s" % [errors]).has_size(1)
	assert_str(String(errors[0]["field"])).is_equal("bindings.pad:south")


## Edge case: an unparseable key token ("confirm:key:NotAKey") gives field
## "bindings[<i>]".
func test_unparseable_key_token_reports_bindings_index() -> void:
	var record: InputBindings = InputTestSupport.default_bindings()
	var index: int = record.bindings.size()
	record.bindings.append({"action": "confirm", "device": "key", "input": "NotAKey"})

	var errors: Array[Dictionary] = InputBindingsValidator.validate(record)

	assert_array(errors).override_failure_message("errors: %s" % [errors]).has_size(1)
	assert_str(String(errors[0]["field"])).is_equal("bindings[%d]" % index)


## Edge cases: a malformed entry, an unknown action and a mouse entry each
## give one "bindings[<i>]" entry.
const _MALFORMED_ENTRIES: Array = [
	[{"action": "confirm"}],
	[{"action": "jump", "device": "key", "input": "J"}],
	[{"action": "confirm", "device": "mouse", "input": "left"}],
]


func test_malformed_entry_reports_bindings_index(
		entry: Dictionary, test_parameters := _MALFORMED_ENTRIES) -> void:
	var record: InputBindings = InputTestSupport.default_bindings()
	var index: int = record.bindings.size()
	record.bindings.append(entry)

	var errors: Array[Dictionary] = InputBindingsValidator.validate(record)

	assert_array(errors).override_failure_message("entry %s: %s" % [entry, errors]).has_size(1)
	assert_str(String(errors[0]["field"])).is_equal("bindings[%d]" % index)


## Edge case: a record missing every keyboard binding for move_left gives
## exactly one entry, "bindings.move_left.key".
func test_missing_move_left_keyboard_reports_one_error() -> void:
	var record: InputBindings = InputTestSupport.default_bindings()
	var kept: Array[Dictionary] = []
	for entry: Dictionary in record.bindings:
		if entry["action"] == "move_left" and entry["device"] == "key":
			continue
		kept.append(entry)
	record.bindings = kept

	var errors: Array[Dictionary] = InputBindingsValidator.validate(record)

	assert_array(errors).override_failure_message("errors: %s" % [errors]).has_size(1)
	assert_str(String(errors[0]["field"])).is_equal("bindings.move_left.key")


# --- T-FALLBACK: the fallback bindings parse and compile ---

func test_fallback_bindings_have_no_unparseable_entries() -> void:
	var fallback: InputBindings = InputResolver.make_fallback_bindings()

	var errors: Array[Dictionary] = InputBindingsValidator.validate(fallback)

	for entry: Dictionary in errors:
		assert_bool(String(entry["field"]).begins_with("bindings[")).override_failure_message(
				"unexpected unparseable entry: %s" % [entry]).is_false()


func test_fallback_bindings_compile_and_emit_confirm_and_cancel() -> void:
	var fallback: InputBindings = InputResolver.make_fallback_bindings()
	var resolver := InputResolver.new(fallback, InputConfig.new())
	var rec := InputTestSupport.Recorder.new()
	rec.attach(resolver)

	resolver.feed_event(InputTestSupport.key(KEY_ENTER, true))
	resolver.feed_event(InputTestSupport.key(KEY_ENTER, false))
	resolver.feed_event(InputTestSupport.key(KEY_ESCAPE, true))
	resolver.feed_event(InputTestSupport.key(KEY_ESCAPE, false))
	resolver.feed_event(InputTestSupport.key(KEY_RIGHT, true))

	assert_array(rec.discrete_since(0)).override_failure_message("%s" % [rec.entries]).is_equal([
			[&"action_pressed", [InputActions.CONFIRM]],
			[&"action_released", [InputActions.CONFIRM]],
			[&"action_pressed", [InputActions.CANCEL]],
			[&"action_released", [InputActions.CANCEL]],
	])
	assert_vector(resolver.get_move_vector()).is_equal_approx(
			Vector2(1.0, 0.0), Vector2(InputTestSupport.EPS_V, InputTestSupport.EPS_V))


## Edge case: pad south and east also emit confirm and cancel.
func test_fallback_bindings_compile_pad_south_and_east() -> void:
	var fallback: InputBindings = InputResolver.make_fallback_bindings()
	var resolver := InputResolver.new(fallback, InputConfig.new())
	var rec := InputTestSupport.Recorder.new()
	rec.attach(resolver)

	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_A, true))
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_A, false))
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_B, true))
	resolver.feed_event(InputTestSupport.pad_button(0, JOY_BUTTON_B, false))

	assert_array(rec.discrete_since(0)).override_failure_message("%s" % [rec.entries]).is_equal([
			[&"action_pressed", [InputActions.CONFIRM]],
			[&"action_released", [InputActions.CONFIRM]],
			[&"action_pressed", [InputActions.CANCEL]],
			[&"action_released", [InputActions.CANCEL]],
	])


# --- Registration: the validator is registered before load_all ---

func test_bindings_validator_registered_before_load_all() -> void:
	var spy: _RegistrationOrderSpy = auto_free(_RegistrationOrderSpy.new())

	ContentBootstrap.run(spy, "res://tests/unit/content_data/fixtures/valid_one_of_each")

	var register_index: int = spy.calls.find("register_record_validator:bindings")
	var load_index: int = spy.calls.find("load_all")
	assert_int(register_index).override_failure_message("calls: %s" % [spy.calls]).is_greater_equal(0)
	assert_int(load_index).override_failure_message("calls: %s" % [spy.calls]).is_greater(register_index)
