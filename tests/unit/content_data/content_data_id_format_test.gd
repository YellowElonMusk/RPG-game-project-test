## Story 010, AC-9: a malformed id (uppercase, a space, no type prefix, 65
## characters) is one error naming that id, and the catalog settles FAILED; an
## id of exactly 64 characters loads READY (GDD F1). Each test builds a fresh
## ContentCatalogService (never the autoload) and loads one `id_defects/*`
## fixture root directly. Every fixture's filename equals its declared id, so
## the filename = id check passes and F1 is the only rule that can fire.
## ResourceLoader.list_directory() was observed to return `char_Bad.tres` and
## `char_bad id.tres` unchanged on Windows, so the exact-count assertion holds
## and the story's `field == &"id"` filter fallback is not used.
extends GdUnitTestSuite

const FIXTURE_ROOT := "res://tests/unit/content_data/fixtures/id_defects"


## `char_` (5) + 59 letters: exactly ID_MAX_LENGTH, must load.
func _id_64() -> String:
	return "char_" + "a".repeat(59)


## `char_` (5) + 60 letters: one over ID_MAX_LENGTH, must fail.
func _id_65() -> String:
	return "char_" + "a".repeat(60)


# Loads `sub_dir` into a fresh catalog and asserts AC-9's failure shape:
# FAILED, exactly one report entry, an error on `id` naming `expected_id`.
func _assert_one_id_error(sub_dir: String, expected_id: String) -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	var result: Error = catalog.load_all(FIXTURE_ROOT.path_join(sub_dir))
	assert_int(result).is_equal(FAILED)
	assert_int(catalog.state).is_equal(ContentCatalogService.State.FAILED)
	assert_int(catalog.report.size()).is_equal(1)
	var entry: Dictionary = catalog.report[0]
	assert_str(String(entry["severity"])).is_equal("error")
	assert_str(entry["record_id"]).is_equal(expected_id)
	assert_str(String(entry["field"])).is_equal("id")


func test_boundary_ids_are_64_and_65_characters_long() -> void:
	assert_int(_id_64().length()).is_equal(64)
	assert_int(_id_65().length()).is_equal(65)


func test_load_all_uppercase_id_fails_with_one_id_error() -> void:
	_assert_one_id_error("uppercase", "char_Bad")


func test_load_all_id_with_space_fails_with_one_id_error() -> void:
	_assert_one_id_error("space", "char_bad id")


func test_load_all_id_without_type_prefix_fails_with_one_id_error() -> void:
	_assert_one_id_error("no_prefix", "bad_no_prefix")


func test_load_all_65_character_id_fails_with_one_id_error() -> void:
	_assert_one_id_error("len_65", _id_65())


func test_load_all_64_character_id_loads_ready() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	var result: Error = catalog.load_all(FIXTURE_ROOT.path_join("len_64"))
	assert_int(result).is_equal(OK)
	assert_int(catalog.state).is_equal(ContentCatalogService.State.READY)
	var error_count := 0
	for entry: Dictionary in catalog.report:
		if entry["severity"] == &"error":
			error_count += 1
	assert_int(error_count).is_equal(0)
	assert_object(catalog.get_record(&"character", _id_64())).is_not_null()
