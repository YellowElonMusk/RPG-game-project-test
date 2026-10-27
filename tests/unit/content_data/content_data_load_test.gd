## Story 002, AC-1: one record of each of the 12 types loads READY and every
## exported field round-trips deep-equal to its fixture file. Each test builds
## a fresh ContentCatalogService (never the autoload) and loads the
## `valid_one_of_each` fixture root directly (ADR-0004 Implementation
## Guidelines allow this for the catalog's own unit tests).
extends GdUnitTestSuite

const ReportFilters := preload("res://tests/unit/content_data/helpers/report_filters.gd")

const FIXTURE_ROOT := "res://tests/unit/content_data/fixtures/valid_one_of_each"

## type → the one fixture record id of that type.
const FIXTURE_IDS: Dictionary = {
	&"faction": "faction_tech_syndicate",
	&"character": "char_baguette_thrower",
	&"enemy": "enemy_bureaucrat_drone",
	&"move": "move_notarize_strike",
	&"quirk_state": "quirk_complained",
	&"combo": "combo_overdue_notice",
	&"item": "item_expired_coupon",
	&"bindings": "bindings_default",
	&"faction_rule": "rule_red_tape",
	&"map": "map_outskirts",
	&"encounter": "enc_checkpoint_ambush",
	&"occupation_stage": "ostage_outskirts_stage1",
}

var _catalog: ContentCatalogService
var _load_result: Error


func before_test() -> void:
	_catalog = auto_free(ContentCatalogService.new())
	_load_result = _catalog.load_all(FIXTURE_ROOT)


func _fixture_path(type: StringName) -> String:
	var dir: String = ContentCatalogService.TYPE_TABLE[type]["dir"]
	return "%s/%s/%s.tres" % [FIXTURE_ROOT, dir, FIXTURE_IDS[type]]


func _fresh_fixture(type: StringName) -> Resource:
	return ResourceLoader.load(_fixture_path(type), "", ResourceLoader.CACHE_MODE_IGNORE)


## Names of every stored script export on a record instance.
func _export_names(record: Resource) -> PackedStringArray:
	var names := PackedStringArray()
	for prop: Dictionary in (record.get_script() as Script).get_script_property_list():
		if prop["usage"] & PROPERTY_USAGE_STORAGE:
			names.append(prop["name"])
	return names


func test_load_all_valid_one_of_each_returns_ok_and_ready() -> void:
	assert_int(_load_result).is_equal(OK)
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.READY)
	var error_count := 0
	for entry: Dictionary in _catalog.report:
		if entry["severity"] == &"error":
			error_count += 1
	assert_int(error_count).is_equal(0)


func test_fixture_covers_all_twelve_types() -> void:
	assert_int(FIXTURE_IDS.size()).is_equal(12)
	assert_array(FIXTURE_IDS.keys()).contains_exactly_in_any_order(ContentCatalogService.TYPE_TABLE.keys())


func test_get_record_each_type_returns_record_with_no_lookup_error() -> void:
	for type: StringName in FIXTURE_IDS:
		var record: Resource = _catalog.get_record(type, FIXTURE_IDS[type])
		assert_object(record).override_failure_message("get_record(%s) returned null" % type).is_not_null()
		assert_str(String(_catalog.last_lookup_error)).override_failure_message(
				"last_lookup_error after get_record(%s)" % type).is_equal("")


func test_get_record_each_type_deep_equals_fixture_on_every_export() -> void:
	for type: StringName in FIXTURE_IDS:
		var fixture: Resource = _fresh_fixture(type)
		var record: Resource = _catalog.get_record(type, FIXTURE_IDS[type])
		assert_object(record).is_not_null()
		assert_object(record.get_script()).is_same(fixture.get_script())
		var names: PackedStringArray = _export_names(fixture)
		assert_int(names.size()).override_failure_message("%s declares no exports" % type).is_greater(0)
		for name: String in names:
			assert_that(record.get(name)).override_failure_message(
					"%s.%s differs from the fixture" % [type, name]).is_equal(fixture.get(name))


func test_get_record_move_ids_deep_equal_fixture() -> void:
	for type: StringName in [&"character", &"enemy"]:
		var fixture: Resource = _fresh_fixture(type)
		var record: Resource = _catalog.get_record(type, FIXTURE_IDS[type])
		var expected: PackedStringArray = fixture.get("move_ids")
		assert_int(expected.size()).is_greater(0)
		assert_array(record.get("move_ids")).contains_exactly(expected)


func test_get_record_effects_dictionaries_deep_equal_fixture() -> void:
	for type: StringName in [&"move", &"quirk_state", &"combo", &"item"]:
		var fixture: Resource = _fresh_fixture(type)
		var record: Resource = _catalog.get_record(type, FIXTURE_IDS[type])
		var expected: Array[Dictionary] = fixture.get("effects")
		var actual: Array[Dictionary] = record.get("effects")
		assert_int(actual.size()).override_failure_message("%s.effects size" % type).is_equal(expected.size())
		for i: int in expected.size():
			assert_dict(actual[i]).override_failure_message(
					"%s.effects[%d]" % [type, i]).is_equal(expected[i])


func test_move_and_quirk_state_fixtures_carry_two_or_more_nested_effects() -> void:
	for type: StringName in [&"move", &"quirk_state"]:
		var effects: Array[Dictionary] = _catalog.get_record(type, FIXTURE_IDS[type]).get("effects")
		assert_int(effects.size()).override_failure_message("%s.effects" % type).is_greater_equal(2)
		for effect: Dictionary in effects:
			assert_bool(effect.has("type")).is_true()
			var has_nested := false
			for value: Variant in effect.values():
				if value is Dictionary:
					has_nested = true
			assert_bool(has_nested).override_failure_message(
					"%s effect %s has no nested parameter dictionary" % [type, effect["type"]]).is_true()


func test_has_record_each_type_returns_true_with_no_lookup_error() -> void:
	for type: StringName in FIXTURE_IDS:
		assert_bool(_catalog.has_record(type, FIXTURE_IDS[type])).override_failure_message(
				"has_record(%s)" % type).is_true()
		assert_str(String(_catalog.last_lookup_error)).is_equal("")


func test_bootstrap_run_on_fixture_root_reaches_ready() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	ContentBootstrap.run(catalog, FIXTURE_ROOT)
	assert_int(catalog.state).is_equal(ContentCatalogService.State.READY)
	assert_object(catalog.get_record(&"faction", FIXTURE_IDS[&"faction"])).is_not_null()


## The one validation rule this story implements beyond the null check: a
## record whose filename differs from its `id` is an error naming the record
## and the `id` field, the catalog settles FAILED, and the record is not stored.
func test_load_all_filename_not_equal_to_id_fails_with_id_error() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	var result: Error = catalog.load_all("res://tests/unit/content_data/fixtures/filename_mismatch")
	assert_int(result).is_equal(FAILED)
	assert_int(catalog.state).is_equal(ContentCatalogService.State.FAILED)
	assert_int(ReportFilters.errors(catalog.report).size()).is_equal(1)
	var entry: Dictionary = ReportFilters.errors(catalog.report)[0]
	assert_str(String(entry["severity"])).is_equal("error")
	assert_str(entry["record_id"]).is_equal("item_declared_id")
	assert_str(String(entry["field"])).is_equal("id")
	assert_str(entry["location"]["file_path"]).ends_with("items/item_wrong_filename.tres")
	assert_int(entry["location"]["record_index"]).is_equal(0)
