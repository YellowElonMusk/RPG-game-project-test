## Story 006, AC-5: a caller's edit to a value returned by get_record() or
## all_records() -- including a nested list and a nested EffectDescriptor --
## never leaks back into a later lookup. Each test builds a fresh
## ContentCatalogService (never the autoload) and loads the
## `valid_one_of_each` fixture root directly (ADR-0004 Implementation
## Guidelines allow this for the catalog's own unit tests).
extends GdUnitTestSuite

const FIXTURE_ROOT := "res://tests/unit/content_data/fixtures/valid_one_of_each"
const MOVE_ID := "move_notarize_strike"
const CHARACTER_ID := "char_baguette_thrower"

var _catalog: ContentCatalogService


func before_test() -> void:
	_catalog = auto_free(ContentCatalogService.new())
	_catalog.load_all(FIXTURE_ROOT)


func _fixture_path(type: StringName, id: String) -> String:
	var dir: String = ContentCatalogService.TYPE_TABLE[type]["dir"]
	return "%s/%s/%s.tres" % [FIXTURE_ROOT, dir, id]


func _fresh_fixture(type: StringName, id: String) -> Resource:
	return ResourceLoader.load(_fixture_path(type, id), "", ResourceLoader.CACHE_MODE_IGNORE)


## Names of every stored script export on a record instance (story 002's
## content_data_load_test.gd pattern).
func _export_names(record: Resource) -> PackedStringArray:
	var names := PackedStringArray()
	for prop: Dictionary in (record.get_script() as Script).get_script_property_list():
		if prop["usage"] & PROPERTY_USAGE_STORAGE:
			names.append(prop["name"])
	return names


## Asserts every exported field of `record` deep-equals a fresh
## CACHE_MODE_IGNORE load of the fixture for `type`/`id` (story 002's generic
## reflective sweep, reused here as the "did not leak" assertion).
func _assert_deep_equals_fixture(record: Resource, type: StringName, id: String) -> void:
	var fixture: Resource = _fresh_fixture(type, id)
	for name: String in _export_names(fixture):
		assert_that(record.get(name)).override_failure_message(
				"%s.%s differs from the fixture" % [type, name]).is_equal(fixture.get(name))


## AC-5 / T1, the deep-copy evidence for this story: a scalar edit (`cost`),
## an appended effect and a mutation one level inside the existing
## `effects[0]` dictionary (`effects[0]["scaling"]["multiplier"]`), plus a
## direct top-level key change on that same dictionary (`effects[0]["type"]`),
## on a returned Move all fail to leak -- the next get_record() for the same
## id still deep-equals a fresh fixture load. The nested-dictionary mutation
## is what actually discriminates duplicate_deep() from a shallow copy:
## `effects` is `Array[Dictionary]`, and `Dictionary` has reference
## semantics, so a shallow copy would share the inner dictionaries and this
## edit would leak.
func test_move_scalar_list_and_nested_dict_edits_do_not_leak() -> void:
	var first: Resource = _catalog.get_record(&"move", MOVE_ID)

	first.set("cost", (first.get("cost") as int) + 999)
	var effects: Array[Dictionary] = first.get("effects")
	effects.append({"type": "test_only_injected_effect"})
	effects[0]["type"] = "test_only_mutated_type"
	(effects[0]["scaling"] as Dictionary)["multiplier"] = 999.0

	var second: Resource = _catalog.get_record(&"move", MOVE_ID)

	assert_bool(is_same(first, second)).override_failure_message(
			"get_record() returned the same instance twice").is_false()
	_assert_deep_equals_fixture(second, &"move", MOVE_ID)


## AC-5 / T2, instance-independence evidence: get_record() and all_records()
## each hand out a fresh instance per call, so an edit to one borrowed
## Character never surfaces through a later call to either entry point.
## `move_ids` is a `PackedStringArray` -- a value type under GDScript's
## copy-on-write semantics -- so this test does not discriminate deep-copy
## correctness the way test_move_scalar_list_and_nested_dict_edits_do_not_leak
## does; that is T1's job. This one proves instance independence across
## get_record() and all_records(), both directions.
func test_character_move_ids_edits_do_not_leak_across_get_record_and_all_records() -> void:
	# get_record() edit must not leak into a later get_record() call.
	var first: Resource = _catalog.get_record(&"character", CHARACTER_ID)
	var first_ids: PackedStringArray = first.get("move_ids")
	first_ids.append("test_only_injected_move")
	first.set("move_ids", first_ids)

	var second: Resource = _catalog.get_record(&"character", CHARACTER_ID)
	assert_bool(is_same(first, second)).override_failure_message(
			"get_record() returned the same instance twice").is_false()
	_assert_deep_equals_fixture(second, &"character", CHARACTER_ID)

	# ...nor into a later all_records() call. valid_one_of_each has exactly
	# one record per type, so index 0 is the Character fixture.
	var all_after_get_record_edit: Array[Resource] = _catalog.all_records(&"character")
	_assert_deep_equals_fixture(all_after_get_record_edit[0], &"character", CHARACTER_ID)

	# all_records() edit must not leak into a later get_record() call either.
	var all_records_list: Array[Resource] = _catalog.all_records(&"character")
	var via_all: Resource = all_records_list[0]
	var via_all_ids: PackedStringArray = via_all.get("move_ids")
	via_all_ids.append("test_only_injected_via_all")
	via_all.set("move_ids", via_all_ids)

	var third: Resource = _catalog.get_record(&"character", CHARACTER_ID)
	_assert_deep_equals_fixture(third, &"character", CHARACTER_ID)


## Observational only (Implementation Notes -- not a pass/fail gate): records
## the per-call cost of get_record() on the fixture so /story-done can
## confirm the "construction time, never per frame" assumption. The
## Completion Notes carry the printed figure; nothing is asserted on it.
func test_get_record_cost_observation() -> void:
	const ITERATIONS := 1000
	var start_usec: int = Time.get_ticks_usec()
	for i: int in ITERATIONS:
		_catalog.get_record(&"move", MOVE_ID)
	var elapsed_usec: int = Time.get_ticks_usec() - start_usec

	print("get_record() cost observation: %.2f usec/call over %d calls (%d usec total)" % [
			float(elapsed_usec) / ITERATIONS, ITERATIONS, elapsed_usec])
