## Story 022, AC-16 (TR-content-003; ADR-0001 "Validation mechanism" step 3):
## a file `ResourceLoader.load()` returns null for is one error naming the
## file, with an empty record_id (no id could be read), and loading continues
## over the rest of the set — including Char_Bad's own id-format error
## (story 010, TR-content-001 F1). Builds a fresh ContentCatalogService
## (never the autoload).
extends GdUnitTestSuite

const ROOT := "res://tests/unit/content_data/fixtures/unparsable_file"
## Carries the unknown key `stat_blok`: had the raw-text unknown-field scan
## (story 015) run on it, a second entry would name this path.
const CORRUPT_PATH := ROOT + "/characters/corrupt_file.tres"
## A second unparsable file, in another type directory.
const CORRUPT_MOVE_PATH := ROOT + "/moves/corrupt_move.tres"

var _catalog: ContentCatalogService


func before_test() -> void:
	_catalog = auto_free(ContentCatalogService.new())


## T1: the corrupt file gives one error naming it with an empty record_id,
## Char_Bad's own id-format error is still reported, the catalog is FAILED,
## and nothing from the corrupt file is retrievable.
func test_unparsable_file_errors_and_other_errors_still_reported() -> void:
	var result: Error = _catalog.load_all(ROOT)

	assert_int(result).is_equal(FAILED)
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.FAILED)

	var corrupt_entries: Array[Dictionary] = []
	var char_bad_entries: Array[Dictionary] = []
	for entry: Dictionary in _catalog.report:
		if (entry["location"] as Dictionary)["file_path"] == CORRUPT_PATH:
			corrupt_entries.append(entry)
		if entry["record_id"] == "Char_Bad":
			char_bad_entries.append(entry)

	assert_int(corrupt_entries.size()).override_failure_message(
			"report: %s" % [_catalog.report]).is_equal(1)
	if corrupt_entries.size() == 1:
		assert_str(String(corrupt_entries[0]["severity"])).is_equal("error")
		assert_str(corrupt_entries[0]["record_id"]).is_equal("")

	assert_int(char_bad_entries.size()).is_equal(1)

	assert_object(_catalog.get_record(&"character", "corrupt_file")).is_null()


## Two unparsable files in one load each give their own single error; the
## first does not stop the second from being reported.
func test_each_unparsable_file_gets_its_own_error() -> void:
	_catalog.load_all(ROOT)

	var move_entries: Array[Dictionary] = []
	for entry: Dictionary in _catalog.report:
		if (entry["location"] as Dictionary)["file_path"] == CORRUPT_MOVE_PATH:
			move_entries.append(entry)
	assert_int(move_entries.size()).override_failure_message(
			"report: %s" % [_catalog.report]).is_equal(1)
	if move_entries.size() == 1:
		assert_str(move_entries[0]["record_id"]).is_equal("")
	assert_object(_catalog.get_record(&"move", "corrupt_move")).is_null()
