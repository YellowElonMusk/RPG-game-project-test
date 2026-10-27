## Story 012, AC-11 and AC-11b. AC-11: a record's declared alias resolves to
## its live id in one hop (ADR-0001; GDD Rule 2). `alias_basic` holds
## characters/char_new.tres declaring aliases ["char_old", "char_older"], plus
## its faction. AC-11b: an alias that breaks GDD F1 (pattern, the declaring
## type's prefix, over 64 characters) is one error on field `aliases` naming
## the declaring record, and it is never added to the alias map (GDD Rule 8).
## Each `alias_format_defects/*` subdirectory holds characters/char_new.tres
## (a valid id) declaring one alias, plus its faction, so the alias check is
## the only rule that can fire. The live-id passthrough and alias shadowing
## are story 013's. Each test builds a fresh ContentCatalogService (never the
## autoload) and loads a fixture root directly.
extends GdUnitTestSuite

const ReportFilters := preload("res://tests/unit/content_data/helpers/report_filters.gd")

const BASIC_ROOT := "res://tests/unit/content_data/fixtures/alias_basic"
const DEFECTS_ROOT := "res://tests/unit/content_data/fixtures/alias_format_defects"
const LIVE_ID := "char_new"


## `char_` (5) + 59 letters: exactly ID_MAX_LENGTH, a well-formed alias.
func _alias_64() -> String:
	return "char_" + "a".repeat(59)


## `char_` (5) + 60 letters: one over ID_MAX_LENGTH, a malformed alias.
func _alias_65() -> String:
	return "char_" + "a".repeat(60)


# Loads `sub_dir` into a fresh catalog and asserts AC-11b's failure shape:
# FAILED, exactly one report entry, an error on `aliases` naming the declaring
# record (never the malformed alias string).
func _assert_one_alias_error(sub_dir: String) -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())

	var result: Error = catalog.load_all(DEFECTS_ROOT.path_join(sub_dir))

	assert_int(result).is_equal(FAILED)
	assert_int(catalog.state).is_equal(ContentCatalogService.State.FAILED)
	assert_int(ReportFilters.errors(catalog.report).size()).is_equal(1)
	if ReportFilters.errors(catalog.report).size() != 1:
		return  # Indexing an empty report would abort the whole suite.
	var entry: Dictionary = ReportFilters.errors(catalog.report)[0]
	assert_str(String(entry["severity"])).is_equal("error")
	assert_str(String(entry["field"])).is_equal("aliases")
	assert_str(entry["record_id"]).is_equal(LIVE_ID)


func test_boundary_aliases_are_64_and_65_characters_long() -> void:
	assert_int(_alias_64().length()).is_equal(64)
	assert_int(_alias_65().length()).is_equal(65)


func test_resolve_alias_declared_alias_returns_live_id() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	assert_int(catalog.load_all(BASIC_ROOT)).is_equal(OK)
	assert_int(catalog.state).is_equal(ContentCatalogService.State.READY)

	var resolved: String = catalog.resolve_alias("char_old")

	assert_str(resolved).is_equal(LIVE_ID)
	assert_str(String(catalog.last_lookup_error)).is_equal("")
	assert_object(catalog.get_record(&"character", resolved)).is_not_null()


## Edge case: a record with two aliases resolves both.
func test_resolve_alias_both_declared_aliases_resolve_to_live_id() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	assert_int(catalog.load_all(BASIC_ROOT)).is_equal(OK)

	var resolved_old: String = catalog.resolve_alias("char_old")
	var old_error: StringName = catalog.last_lookup_error
	var resolved_older: String = catalog.resolve_alias("char_older")
	var older_error: StringName = catalog.last_lookup_error

	assert_str(resolved_old).is_equal(LIVE_ID)
	assert_str(String(old_error)).is_equal("")
	assert_str(resolved_older).is_equal(LIVE_ID)
	assert_str(String(older_error)).is_equal("")


## Edge case: an id that is neither live nor an alias is missing_id.
func test_resolve_alias_unknown_id_returns_empty_with_missing_id_error() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	assert_int(catalog.load_all(BASIC_ROOT)).is_equal(OK)

	var resolved: String = catalog.resolve_alias("char_never_existed")

	assert_str(resolved).is_equal("")
	assert_str(String(catalog.last_lookup_error)).is_equal("missing_id")


func test_load_all_uppercase_alias_fails_with_one_aliases_error() -> void:
	_assert_one_alias_error("uppercase")


func test_load_all_alias_with_space_fails_with_one_aliases_error() -> void:
	_assert_one_alias_error("space")


func test_load_all_alias_without_type_prefix_fails_with_one_aliases_error() -> void:
	_assert_one_alias_error("no_prefix")


func test_load_all_65_character_alias_fails_with_one_aliases_error() -> void:
	_assert_one_alias_error("len_65")


## Edge case: an alias of exactly 64 characters is well-formed and resolves.
func test_load_all_64_character_alias_loads_ready_and_resolves() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())

	var result: Error = catalog.load_all(DEFECTS_ROOT.path_join("len_64"))

	assert_int(result).is_equal(OK)
	assert_int(catalog.state).is_equal(ContentCatalogService.State.READY)
	assert_str(catalog.resolve_alias(_alias_64())).is_equal(LIVE_ID)
	assert_str(String(catalog.last_lookup_error)).is_equal("")


## Edge case: in the FAILED `uppercase` catalog every lookup is refused before
## the alias map is consulted, so the malformed alias gives not_ready.
func test_resolve_alias_on_failed_catalog_returns_empty_with_not_ready_error() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	catalog.load_all(DEFECTS_ROOT.path_join("uppercase"))

	var resolved: String = catalog.resolve_alias("Char_Old")

	assert_str(resolved).is_equal("")
	assert_str(String(catalog.last_lookup_error)).is_equal("not_ready")


## Edge case: two malformed aliases on one record give one entry each, never
## one entry naming both (the loop continues past a malformed alias).
func test_load_all_two_malformed_aliases_give_two_aliases_errors() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())

	var result: Error = catalog.load_all(DEFECTS_ROOT.path_join("two_malformed"))

	assert_int(result).is_equal(FAILED)
	assert_int(ReportFilters.errors(catalog.report).size()).is_equal(2)
	for entry: Dictionary in catalog.report:
		assert_str(String(entry["field"])).is_equal("aliases")
		assert_str(entry["record_id"]).is_equal(LIVE_ID)
