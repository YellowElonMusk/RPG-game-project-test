## Story 011, AC-10: two or more records sharing one id across different files
## is exactly one error -- never one per offending file, never "last one
## wins" (ADR-0001 Rule 2; control manifest). The error's location is the
## file whose res:// path sorts first (case-sensitive string order); every
## other file holding that id lands in related_locations, in the same sorted
## order. `duplicate_id_two_files` holds characters/a/char_dup.tres and
## characters/b/char_dup.tres (both valid Characters, id "char_dup", plus
## their faction); `duplicate_id_three_files` adds a third location c/ for
## the three-way edge case. Each test builds a fresh ContentCatalogService
## (never the autoload) and loads a fixture root directly.
extends GdUnitTestSuite

const ReportFilters := preload("res://tests/unit/content_data/helpers/report_filters.gd")

const TWO_FILES_ROOT := "res://tests/unit/content_data/fixtures/duplicate_id_two_files"
const THREE_FILES_ROOT := "res://tests/unit/content_data/fixtures/duplicate_id_three_files"

const PATH_A := "res://tests/unit/content_data/fixtures/duplicate_id_two_files/characters/a/char_dup.tres"
const PATH_B := "res://tests/unit/content_data/fixtures/duplicate_id_two_files/characters/b/char_dup.tres"

const PATH3_A := "res://tests/unit/content_data/fixtures/duplicate_id_three_files/characters/a/char_dup.tres"
const PATH3_B := "res://tests/unit/content_data/fixtures/duplicate_id_three_files/characters/b/char_dup.tres"
const PATH3_C := "res://tests/unit/content_data/fixtures/duplicate_id_three_files/characters/c/char_dup.tres"


func test_two_files_sharing_an_id_loads_failed() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())

	var result: Error = catalog.load_all(TWO_FILES_ROOT)

	assert_int(result).is_equal(FAILED)
	assert_int(catalog.state).is_equal(ContentCatalogService.State.FAILED)


func test_two_files_sharing_an_id_reports_one_error_located_at_the_first_path() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	catalog.load_all(TWO_FILES_ROOT)

	assert_int(ReportFilters.errors(catalog.report).size()).is_equal(1)
	if ReportFilters.errors(catalog.report).size() != 1:
		return  # Indexing an empty report would abort the whole suite.
	var entry: Dictionary = ReportFilters.errors(catalog.report)[0]
	assert_str(String(entry["severity"])).is_equal("error")
	assert_str(entry["record_id"]).is_equal("char_dup")
	assert_str(String(entry["field"])).is_equal("id")
	assert_str((entry["location"] as Dictionary)["file_path"]).is_equal(PATH_A)


func test_two_files_sharing_an_id_names_the_other_file_in_related_locations() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	catalog.load_all(TWO_FILES_ROOT)

	assert_int(ReportFilters.errors(catalog.report).size()).is_equal(1)
	if ReportFilters.errors(catalog.report).size() != 1:
		return  # Indexing an empty report would abort the whole suite.
	var related: Array = ReportFilters.errors(catalog.report)[0]["related_locations"]

	assert_int(related.size()).is_equal(1)
	assert_str((related[0] as Dictionary)["file_path"]).is_equal(PATH_B)


## Edge case: three files sharing one id give one entry with two
## related_locations, sorted the same way as the primary location.
func test_three_files_sharing_an_id_reports_one_error_with_two_sorted_related_locations() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())

	var result: Error = catalog.load_all(THREE_FILES_ROOT)

	assert_int(result).is_equal(FAILED)
	assert_int(ReportFilters.errors(catalog.report).size()).is_equal(1)
	if ReportFilters.errors(catalog.report).size() != 1:
		return  # Indexing an empty report would abort the whole suite.
	var entry: Dictionary = ReportFilters.errors(catalog.report)[0]
	assert_str((entry["location"] as Dictionary)["file_path"]).is_equal(PATH3_A)
	var related: Array = entry["related_locations"]
	assert_int(related.size()).is_equal(2)
	assert_str((related[0] as Dictionary)["file_path"]).is_equal(PATH3_B)
	assert_str((related[1] as Dictionary)["file_path"]).is_equal(PATH3_C)


## Edge case: the "first" location never depends on listing order (story
## 003's discovery_order_transform seam, reversed here).
func test_reversed_discovery_order_still_reports_the_first_path_by_sort() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	catalog.discovery_order_transform = func(listing: PackedStringArray) -> PackedStringArray:
		var reversed: PackedStringArray = listing.duplicate()
		reversed.reverse()
		return reversed

	var result: Error = catalog.load_all(TWO_FILES_ROOT)

	assert_int(result).is_equal(FAILED)
	assert_int(ReportFilters.errors(catalog.report).size()).is_equal(1)
	if ReportFilters.errors(catalog.report).size() != 1:
		return  # Indexing an empty report would abort the whole suite.
	var entry: Dictionary = ReportFilters.errors(catalog.report)[0]
	assert_str((entry["location"] as Dictionary)["file_path"]).is_equal(PATH_A)
	var related: Array = entry["related_locations"]
	assert_int(related.size()).is_equal(1)
	assert_str((related[0] as Dictionary)["file_path"]).is_equal(PATH_B)
