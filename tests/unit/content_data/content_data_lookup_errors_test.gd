## Story 005, AC-4: a missing ID returns not-found, and an unknown type
## returns an error, not an empty list. One error channel distinguishes the
## two causes via `last_lookup_error` (ADR-0001 Amendment 2026-10-23): a known
## type with a missing id sets `&"missing_id"`, an unknown type sets
## `&"unknown_type"`, and a successful lookup resets it to `&""`. Builds a
## fresh ContentCatalogService (never the autoload) and loads the
## `valid_one_of_each` fixture root directly (ADR-0004 Implementation
## Guidelines allow this for the catalog's own unit tests).
extends GdUnitTestSuite

const FIXTURE_ROOT := "res://tests/unit/content_data/fixtures/valid_one_of_each"

var _catalog: ContentCatalogService


func before_test() -> void:
	_catalog = auto_free(ContentCatalogService.new())
	_catalog.load_all(FIXTURE_ROOT)


func test_get_record_missing_id_returns_null_with_missing_id_error() -> void:
	var record: Resource = _catalog.get_record(&"character", "char_does_not_exist")

	assert_object(record).is_null()
	assert_str(String(_catalog.last_lookup_error)).is_equal("missing_id")
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.READY)


func test_all_records_unknown_type_returns_empty_array_with_unknown_type_error() -> void:
	var records: Array[Resource] = _catalog.all_records(&"charcter")

	assert_array(records).is_empty()
	assert_str(String(_catalog.last_lookup_error)).is_equal("unknown_type")
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.READY)


func test_all_records_known_type_returns_fixture_record_with_no_error() -> void:
	var records: Array[Resource] = _catalog.all_records(&"item")

	assert_int(records.size()).is_equal(1)
	assert_str(records[0].get("id")).is_equal("item_expired_coupon")
	assert_str(String(_catalog.last_lookup_error)).is_equal("")
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.READY)


func test_has_record_missing_id_returns_false_with_missing_id_error() -> void:
	var found: bool = _catalog.has_record(&"character", "char_does_not_exist")

	assert_bool(found).is_false()
	assert_str(String(_catalog.last_lookup_error)).is_equal("missing_id")
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.READY)


func test_get_record_unknown_type_returns_null_with_unknown_type_error() -> void:
	var record: Resource = _catalog.get_record(&"charcter", "char_x")

	assert_object(record).is_null()
	assert_str(String(_catalog.last_lookup_error)).is_equal("unknown_type")
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.READY)


func test_successful_lookup_after_failed_lookup_resets_last_lookup_error() -> void:
	_catalog.get_record(&"charcter", "char_x")
	assert_str(String(_catalog.last_lookup_error)).is_equal("unknown_type")

	var record: Resource = _catalog.get_record(&"item", "item_expired_coupon")

	assert_object(record).is_not_null()
	assert_str(String(_catalog.last_lookup_error)).is_equal("")
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.READY)
