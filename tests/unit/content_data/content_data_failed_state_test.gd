## Story 009, AC-8: one error anywhere fails the whole catalog, even for
## records that were valid by themselves. The `one_error_rest_valid` fixture
## (built in story 008) holds five valid Characters, their faction and moves,
## plus one Move (`moves/move_wrong_name.tres`) whose filename does not match
## its declared `id` -- a rule story 002 already checks, so this is the
## fixture's only error. `load_all()` must settle in FAILED with exactly that
## one report entry, and every lookup -- including on `char_valid_one`, a
## record that was itself valid -- must refuse with
## `last_lookup_error == &"not_ready"`, the same guard story 007 proved for
## Unloaded, Loading and Validating (ADR-0001 F3 and the Amendment
## 2026-10-23). Builds a fresh ContentCatalogService (never the autoload) and
## loads the fixture root directly.
extends GdUnitTestSuite

const ReportFilters := preload("res://tests/unit/content_data/helpers/report_filters.gd")

const FIXTURE_ROOT := "res://tests/unit/content_data/fixtures/one_error_rest_valid"
const MISMATCHED_FILE_PATH := "res://tests/unit/content_data/fixtures/one_error_rest_valid/moves/move_wrong_name.tres"

var _catalog: ContentCatalogService
var _load_result: Error


func before_test() -> void:
	_catalog = auto_free(ContentCatalogService.new())
	_load_result = _catalog.load_all(FIXTURE_ROOT)


func test_load_all_with_one_error_returns_failed() -> void:
	assert_int(_load_result).is_equal(FAILED)
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.FAILED)


func test_report_holds_exactly_the_one_filename_mismatch_error() -> void:
	assert_int(ReportFilters.errors(_catalog.report).size()).is_equal(1)

	var entry: Dictionary = ReportFilters.errors(_catalog.report)[0]
	assert_str(String(entry["severity"])).is_equal("error")
	assert_str(entry["record_id"]).is_equal("move_real_name")
	assert_str(String(entry["field"])).is_equal("id")
	assert_str((entry["location"] as Dictionary)["file_path"]).is_equal(MISMATCHED_FILE_PATH)


func test_get_record_on_failed_catalog_returns_null_with_not_ready_error() -> void:
	var record: Resource = _catalog.get_record(&"character", "char_valid_one")

	assert_object(record).is_null()
	assert_str(String(_catalog.last_lookup_error)).is_equal("not_ready")


func test_has_record_on_failed_catalog_returns_false_with_not_ready_error() -> void:
	var found: bool = _catalog.has_record(&"character", "char_valid_one")

	assert_bool(found).is_false()
	assert_str(String(_catalog.last_lookup_error)).is_equal("not_ready")


func test_all_records_on_failed_catalog_returns_empty_with_not_ready_error() -> void:
	var records: Array[Resource] = _catalog.all_records(&"character")

	assert_array(records).is_empty()
	assert_str(String(_catalog.last_lookup_error)).is_equal("not_ready")


## Edge case: char_valid_one is a live id, not an alias, so this confirms the
## guard fires on state before any alias lookup is attempted.
func test_resolve_alias_on_failed_catalog_returns_empty_string_with_not_ready_error() -> void:
	var resolved: String = _catalog.resolve_alias("char_valid_one")

	assert_str(resolved).is_equal("")
	assert_str(String(_catalog.last_lookup_error)).is_equal("not_ready")
