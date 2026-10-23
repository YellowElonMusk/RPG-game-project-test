## Story 007, AC-6: a lookup during Unloaded, Loading or Validating returns
## the type's empty value with last_lookup_error == &"not_ready", for all
## four lookups (get_record, has_record, all_records, resolve_alias). Loading
## is observed via the file_loaded_hook seam; Validating via a test-only
## validator registered through register_record_validator() (ADR-0004
## forbids lookups inside a production validator; a test double is exempt
## because its purpose is to observe the refusal). The final edge case proves
## the guard is state-based, not sticky: the same four lookups succeed once
## the same load reaches READY. Builds a fresh ContentCatalogService (never
## the autoload) and loads the `valid_one_of_each` fixture root directly.
##
## Lambdas capture locals by value (GDScript 4.5+), so state shared with a
## lambda lives in an Array, never a bare int.
extends GdUnitTestSuite

const FIXTURE_ROOT := "res://tests/unit/content_data/fixtures/valid_one_of_each"
const CHARACTER_ID := "char_baguette_thrower"

var _catalog: ContentCatalogService


func before_test() -> void:
	_catalog = auto_free(ContentCatalogService.new())


## Runs all four lookups on catalog and returns one Dictionary per lookup
## recording its return value and the last_lookup_error it set, in call order.
func _run_four_lookups(catalog: ContentCatalogService) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var record: Resource = catalog.get_record(&"character", CHARACTER_ID)
	results.append({"name": "get_record", "value": record, "error": catalog.last_lookup_error})
	var found: bool = catalog.has_record(&"character", CHARACTER_ID)
	results.append({"name": "has_record", "value": found, "error": catalog.last_lookup_error})
	var all: Array[Resource] = catalog.all_records(&"character")
	results.append({"name": "all_records", "value": all, "error": catalog.last_lookup_error})
	var resolved: String = catalog.resolve_alias(CHARACTER_ID)
	results.append({"name": "resolve_alias", "value": resolved, "error": catalog.last_lookup_error})
	return results


func _assert_all_refused_not_ready(results: Array[Dictionary]) -> void:
	for result: Dictionary in results:
		assert_str(String(result["error"])).override_failure_message(
				"%s last_lookup_error" % result["name"]).is_equal("not_ready")
	assert_object(results[0]["value"]).override_failure_message("get_record value").is_null()
	assert_bool(results[1]["value"]).override_failure_message("has_record value").is_false()
	assert_array(results[2]["value"]).override_failure_message("all_records value").is_empty()
	assert_str(results[3]["value"]).override_failure_message("resolve_alias value").is_equal("")


func test_unloaded_lookups_return_empty_with_not_ready_error() -> void:
	var results: Array[Dictionary] = _run_four_lookups(_catalog)

	_assert_all_refused_not_ready(results)
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.UNLOADED)


func test_loading_lookups_return_empty_with_not_ready_error() -> void:
	var recorded: Array = []
	_catalog.file_loaded_hook = func(_file_path: String) -> void:
		assert_int(_catalog.state).override_failure_message(
				"state during file_loaded_hook").is_equal(ContentCatalogService.State.LOADING)
		recorded.append(_run_four_lookups(_catalog))

	_catalog.load_all(FIXTURE_ROOT)

	assert_array(recorded).override_failure_message("file_loaded_hook never ran").is_not_empty()
	for results: Array[Dictionary] in recorded:
		_assert_all_refused_not_ready(results)


func test_validating_lookups_return_empty_with_not_ready_error() -> void:
	var recorded: Array = []
	var run_counter: Array[int] = [0]
	var validator := func(_record: Resource) -> Array[Dictionary]:
		run_counter[0] += 1
		assert_int(_catalog.state).override_failure_message(
				"state during test validator").is_equal(ContentCatalogService.State.VALIDATING)
		recorded.append(_run_four_lookups(_catalog))
		return []
	_catalog.register_record_validator(&"character", validator)

	var result: Error = _catalog.load_all(FIXTURE_ROOT)

	assert_int(run_counter[0]).override_failure_message("test validator never ran").is_greater(0)
	assert_array(recorded).override_failure_message("no lookups recorded during Validating").is_not_empty()
	for results: Array[Dictionary] in recorded:
		_assert_all_refused_not_ready(results)
	# Edge case: the test validator returns [], so it adds no entries, and the
	# catalog still reaches READY cleanly.
	assert_int(result).is_equal(OK)
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.READY)
	var error_count := 0
	for entry: Dictionary in _catalog.report:
		if entry["severity"] == &"error":
			error_count += 1
	assert_int(error_count).override_failure_message("test validator added report entries").is_equal(0)


## Edge case: not sticky -- once the same load reaches READY, the same four
## lookups succeed normally.
func test_lookups_succeed_after_the_same_load_reaches_ready() -> void:
	assert_int(_catalog.load_all(FIXTURE_ROOT)).is_equal(OK)

	var results: Array[Dictionary] = _run_four_lookups(_catalog)

	for result: Dictionary in results:
		assert_str(String(result["error"])).override_failure_message(
				"%s last_lookup_error" % result["name"]).is_equal("")
	assert_object(results[0]["value"]).override_failure_message("get_record value").is_not_null()
	assert_bool(results[1]["value"]).override_failure_message("has_record value").is_true()
	assert_array(results[2]["value"]).override_failure_message("all_records value").is_not_empty()
	assert_str(results[3]["value"]).override_failure_message("resolve_alias value").is_equal(CHARACTER_ID)
