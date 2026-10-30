## Invalid player overrides (story 026, GDD AC-22 [VS]; ADR-0003 §3,
## ADR-0009 §7). An invalid override set is discarded with exactly one
## `binding_override_discarded` notice and the defaults stay active; on the
## next load (a fresh resolver given the cleared set) no notice fires. The
## "next load" is tested against a stub settings participant; the real file
## round-trip belongs to the Save/Load epic. Every invalid fixture is
## invalid under any merge rule (the add-vs-replace ruling is open).
extends GdUnitTestSuite

## Each invalid override fixture (story 026 Implementation Notes).
const _INVALID: Array = [
	[["confirm:key:NotAKey"]],
	[["confirm"]],
	[["jump:key:J"]],
	[["confirm:mouse:left"]],
	[["inspect:key:E", "confirm:key:NotAKey", "cancel"]],
]

## The mixed set: one otherwise-valid triple binding the unbound key E plus
## two bad ones.
const _MIXED: Array[String] = ["inspect:key:E", "confirm:key:NotAKey", "cancel"]


## The stub settings participant (ADR-0009 §7): GameRoot connects
## binding_override_discarded to clear_bindings(), which stores [] and
## queues one notice.
class StubSettings:
	extends RefCounted

	var stored: PackedStringArray = PackedStringArray()

	func get_value(_key: StringName) -> PackedStringArray:
		return stored

	func clear_bindings(_reason: String = "") -> void:
		stored = PackedStringArray()


func _make(bindings: InputBindings) -> Array:
	var resolver := InputResolver.new(bindings, InputTestSupport.DEFAULT)
	var rec := InputTestSupport.Recorder.new()
	rec.attach(resolver)
	return [resolver, rec]


func _notices(rec: InputTestSupport.Recorder, mark_index: int = 0) -> int:
	var count: int = 0
	for entry: Array in rec.since(mark_index):
		if entry[0] == &"binding_override_discarded":
			count += 1
	return count


# Every default discrete binding still emits its action (story 001's literal
# table, DefaultBindingEvents).
func _assert_defaults_active(resolver: InputResolver, rec: InputTestSupport.Recorder) -> void:
	for triple_key: String in DefaultBindingEvents.EVENTS:
		var parts: PackedStringArray = triple_key.split(":", true, 2)
		var action: StringName = StringName(parts[0])
		if not InputActions.DISCRETE.has(action):
			continue
		var literal: int = DefaultBindingEvents.EVENTS[triple_key]
		var mark: int = rec.mark()
		if parts[1] == "key":
			resolver.feed_event(InputTestSupport.key(literal, true))
			resolver.feed_event(InputTestSupport.key(literal, false))
		else:
			resolver.feed_event(InputTestSupport.pad_button(0, literal, true))
			resolver.feed_event(InputTestSupport.pad_button(0, literal, false))
		assert_array(rec.discrete_since(mark)).override_failure_message(triple_key).is_equal([
			[&"action_pressed", [action]], [&"action_released", [action]],
		])


## AC-22: an invalid override set is discarded with exactly one notice, and
## every default binding still emits its action. The reason string is not
## asserted.
func test_invalid_override_set_discarded_with_one_notice(overrides: Array,
		test_parameters := _INVALID) -> void:
	var made: Array = _make(InputTestSupport.default_bindings())
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.apply_overrides(PackedStringArray(overrides))
	assert_int(_notices(rec)).is_equal(1)
	_assert_defaults_active(resolver, rec)


## AC-22: after the mixed set, pressing E (the valid-looking triple's key)
## emits nothing.
func test_mixed_set_leaves_e_unbound() -> void:
	var made: Array = _make(InputTestSupport.default_bindings())
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.apply_overrides(PackedStringArray(_MIXED))
	var mark: int = rec.mark()
	resolver.feed_event(InputTestSupport.key(KEY_E, true))
	resolver.feed_event(InputTestSupport.key(KEY_E, false))
	assert_array(rec.discrete_since(mark)).is_empty()


## Edge case: an empty override array gives 0 signals and leaves the
## defaults unchanged.
func test_empty_overrides_is_a_no_op() -> void:
	var made: Array = _make(InputTestSupport.default_bindings())
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.apply_overrides(PackedStringArray())
	assert_array(rec.since(0)).is_empty()
	_assert_defaults_active(resolver, rec)


## AC-22: the next load emits no notice.
func test_next_load_emits_no_notice() -> void:
	var stub := StubSettings.new()
	stub.stored = PackedStringArray(_MIXED)
	var made: Array = _make(InputTestSupport.default_bindings())
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.binding_override_discarded.connect(stub.clear_bindings)
	resolver.apply_overrides(stub.get_value(&"bindings"))
	assert_int(_notices(rec)).is_equal(1)
	assert_array(Array(stub.get_value(&"bindings"))).is_empty()
	var made2: Array = _make(InputTestSupport.default_bindings())
	var resolver2: InputResolver = made2[0]
	var rec2: InputTestSupport.Recorder = made2[1]
	resolver2.apply_overrides(stub.get_value(&"bindings"))
	assert_int(_notices(rec2)).is_equal(0)


## Edge case (fallback guard): a resolver built from the fallback bindings
## ignores apply_overrides (0 signals) and Enter still emits confirm.
func test_fallback_bindings_ignore_overrides() -> void:
	var made: Array = _make(InputResolver.make_fallback_bindings())
	var resolver: InputResolver = made[0]
	var rec: InputTestSupport.Recorder = made[1]
	resolver.apply_overrides(PackedStringArray(["confirm:key:NotAKey"]))
	assert_int(_notices(rec)).is_equal(0)
	resolver.feed_event(InputTestSupport.key(KEY_ENTER, true))
	assert_array(rec.discrete_since(0)).is_equal([[&"action_pressed", [InputActions.CONFIRM]]])
