## Story 008, AC-7: a second load_all() on a Ready or a Failed catalog is
## rejected with ERR_ALREADY_IN_USE and changes nothing -- not the state, not
## any stored record, not the report -- and a second ContentBootstrap.run()
## never reaches load_all() a second time, on either terminal state. Each
## test builds a fresh ContentCatalogService, or the test-only
## spy_content_catalog.gd subclass, (never the autoload) and loads fixture
## roots directly (ADR-0004 Implementation Guidelines).
extends GdUnitTestSuite

const VALID_ROOT := "res://tests/unit/content_data/fixtures/valid_one_of_each"
const OTHER_VALID_ROOT := "res://tests/unit/content_data/fixtures/sort_order"
const FAILED_ROOT := "res://tests/unit/content_data/fixtures/one_error_rest_valid"

const SpyContentCatalog := preload("res://tests/unit/content_data/helpers/spy_content_catalog.gd")


## The `id` sequence of `all_records(type)` on `catalog` (content_data_sort_order_test.gd's pattern).
func _ids(catalog: ContentCatalogService, type: StringName) -> Array[String]:
	var ids: Array[String] = []
	for record: Resource in catalog.all_records(type):
		ids.append(record.get("id"))
	return ids


## Asserts `actual` holds the same report entries, in the same order, as `expected`.
func _assert_same_report(actual: Array[Dictionary], expected: Array[Dictionary]) -> void:
	assert_int(actual.size()).override_failure_message("report size changed").is_equal(expected.size())
	for i: int in expected.size():
		assert_dict(actual[i]).override_failure_message("report[%d] changed" % i).is_equal(expected[i])


func test_second_load_all_on_ready_catalog_is_rejected_and_changes_nothing() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	assert_int(catalog.load_all(VALID_ROOT)).is_equal(OK)
	assert_int(catalog.state).is_equal(ContentCatalogService.State.READY)
	var ids_before: Dictionary = {}
	for type: StringName in ContentCatalogService.TYPE_TABLE:
		ids_before[type] = _ids(catalog, type)
	var report_before: Array[Dictionary] = catalog.report.duplicate(true)

	var result: Error = catalog.load_all(OTHER_VALID_ROOT)

	assert_int(result).is_equal(ERR_ALREADY_IN_USE)
	assert_int(catalog.state).is_equal(ContentCatalogService.State.READY)
	for type: StringName in ContentCatalogService.TYPE_TABLE:
		assert_array(_ids(catalog, type)).override_failure_message(
				"all_records(%s) id list changed after a rejected reload" % type).contains_exactly(ids_before[type])
	_assert_same_report(catalog.report, report_before)


func test_second_load_all_on_failed_catalog_is_rejected_and_changes_nothing() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	assert_int(catalog.load_all(FAILED_ROOT)).is_equal(FAILED)
	assert_int(catalog.state).is_equal(ContentCatalogService.State.FAILED)
	var report_before: Array[Dictionary] = catalog.report.duplicate(true)

	var result: Error = catalog.load_all(VALID_ROOT)

	assert_int(result).is_equal(ERR_ALREADY_IN_USE)
	assert_int(catalog.state).override_failure_message(
			"state must stay FAILED, never LOADING or READY").is_equal(ContentCatalogService.State.FAILED)
	_assert_same_report(catalog.report, report_before)


func test_bootstrap_run_twice_on_ready_catalog_calls_load_all_once() -> void:
	var spy: ContentCatalogService = auto_free(SpyContentCatalog.new())

	ContentBootstrap.run(spy, VALID_ROOT)
	var state_after_first: int = spy.state
	ContentBootstrap.run(spy, VALID_ROOT)

	assert_int(spy.load_all_call_count).override_failure_message(
			"load_all() must run exactly once across two run() calls").is_equal(1)
	assert_int(spy.state).is_equal(state_after_first)
	assert_int(spy.state).is_equal(ContentCatalogService.State.READY)


## Edge case: a second run() on a Failed catalog also leaves the counter at 1.
func test_bootstrap_run_twice_on_failed_catalog_calls_load_all_once() -> void:
	var spy: ContentCatalogService = auto_free(SpyContentCatalog.new())

	ContentBootstrap.run(spy, FAILED_ROOT)
	var state_after_first: int = spy.state
	ContentBootstrap.run(spy, VALID_ROOT)

	assert_int(spy.load_all_call_count).override_failure_message(
			"load_all() must run exactly once across two run() calls").is_equal(1)
	assert_int(spy.state).is_equal(state_after_first)
	assert_int(spy.state).is_equal(ContentCatalogService.State.FAILED)
