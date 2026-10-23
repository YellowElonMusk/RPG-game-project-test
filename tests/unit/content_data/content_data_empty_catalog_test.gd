## Story 004, AC-3: a fixture with zero records of every type loads READY,
## never FAILED, and `all_records(type)` returns `[]` for each of the 12
## types with `last_lookup_error == &""`. Two fixtures exercise the two ways
## a type can have zero records: present-but-empty directories
## (`empty_catalog/`) and directories that do not exist at all
## (`empty_catalog_absent/`). Each test builds a fresh ContentCatalogService
## (never the autoload) and loads the fixture root directly (ADR-0004
## Implementation Guidelines allow this for the catalog's own unit tests).
##
## `ResourceLoader.list_directory()` on a path that does not exist was probed
## on Godot 4.7.2 outside this suite: it returns an empty `PackedStringArray`
## with no engine error or warning pushed to the console. T2 therefore needs
## no error-expectation wrapper — see the story's Completion Notes.
extends GdUnitTestSuite

const FIXTURE_ROOT_EMPTY := "res://tests/unit/content_data/fixtures/empty_catalog"
const FIXTURE_ROOT_ABSENT := "res://tests/unit/content_data/fixtures/empty_catalog_absent"


## Shared assertions for T1 and T2: `load_all(fixture_root)` must settle
## READY with an empty report and every type reporting zero records with no
## lookup error.
func _assert_zero_record_catalog_is_ready(fixture_root: String) -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	var result: Error = catalog.load_all(fixture_root)

	assert_int(result).override_failure_message(
			"load_all(%s) return value" % fixture_root).is_equal(OK)
	assert_int(catalog.state).override_failure_message(
			"%s state" % fixture_root).is_equal(ContentCatalogService.State.READY)

	var error_count := 0
	for entry: Dictionary in catalog.report:
		if entry["severity"] == &"error":
			error_count += 1
	assert_int(error_count).override_failure_message(
			"%s report error count" % fixture_root).is_equal(0)

	for type: StringName in ContentCatalogService.TYPE_TABLE:
		assert_array(catalog.all_records(type)).override_failure_message(
				"%s all_records(%s)" % [fixture_root, type]).is_empty()
		assert_str(String(catalog.last_lookup_error)).override_failure_message(
				"%s last_lookup_error after all_records(%s)" % [fixture_root, type]).is_equal("")


## AC-3 / T1: every type directory present and empty (just a
## `.gdignore_placeholder`, which is not a `.tres` and so never listed).
func test_load_all_empty_type_directories_reaches_ready_with_no_records() -> void:
	_assert_zero_record_catalog_is_ready(FIXTURE_ROOT_EMPTY)


## AC-3 / T2: no type subdirectories at all under the fixture root. A
## missing type directory is not an error (control manifest, this layer).
func test_load_all_absent_type_directories_reaches_ready_with_no_records() -> void:
	_assert_zero_record_catalog_is_ready(FIXTURE_ROOT_ABSENT)
