## Story 013, AC-12. T1: an alias equal to a live id errors, naming both
## records -- `shadowing/` holds characters/char_a.tres (live, no aliases) and
## characters/char_b.tres (`aliases: ["char_a"]`), plus their shared faction.
## T2: the same alias declared on two records errors, naming both --
## `declared_twice/` holds characters/char_c.tres and characters/char_d.tres,
## both `aliases: ["char_gone"]`, plus their shared faction. T3: a reference
## through an alias resolves in one hop, and a live id passes through --
## `alias_reference/` holds moves/move_new.tres (`aliases: ["move_old"]`) and
## characters/char_user.tres (`move_ids: ["move_old"]`), plus their shared
## faction. Each test builds a fresh ContentCatalogService (never the
## autoload) and loads a fixture root directly.
extends GdUnitTestSuite

const ROOT := "res://tests/unit/content_data/fixtures/alias_rules"

const SHADOWING_ROOT := ROOT + "/shadowing"
const SHADOWING_CHAR_A_PATH := SHADOWING_ROOT + "/characters/char_a.tres"
const SHADOWING_CHAR_B_PATH := SHADOWING_ROOT + "/characters/char_b.tres"

const DECLARED_TWICE_ROOT := ROOT + "/declared_twice"
const DECLARED_TWICE_CHAR_C_PATH := DECLARED_TWICE_ROOT + "/characters/char_c.tres"
const DECLARED_TWICE_CHAR_D_PATH := DECLARED_TWICE_ROOT + "/characters/char_d.tres"

const ALIAS_REFERENCE_ROOT := ROOT + "/alias_reference"


# Error entries only (severity == &"error"), in report order.
func _errors(catalog: ContentCatalogService) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in catalog.report:
		if entry["severity"] == &"error":
			out.append(entry)
	return out


## T1: char_b.aliases == ["char_a"], and char_a is char_a's own live id.
func test_alias_equal_to_live_id_loads_failed() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())

	var result: Error = catalog.load_all(SHADOWING_ROOT)

	assert_int(result).is_equal(FAILED)
	assert_int(catalog.state).is_equal(ContentCatalogService.State.FAILED)


## T1: the entry is located at char_b, the declaring record -- "it does not
## matter which record sorts first, the declaring record owns the entry".
func test_alias_equal_to_live_id_reports_one_error_located_at_declaring_record() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	catalog.load_all(SHADOWING_ROOT)

	var errors: Array[Dictionary] = _errors(catalog)
	assert_int(errors.size()).is_equal(1)
	if errors.size() != 1:
		return  # Indexing an empty report would abort the whole suite.
	var entry: Dictionary = errors[0]
	assert_str(entry["record_id"]).is_equal("char_b")
	assert_str(String(entry["field"])).is_equal("aliases")
	assert_str((entry["location"] as Dictionary)["file_path"]).is_equal(SHADOWING_CHAR_B_PATH)


## T1: the shadowed live record, char_a, is named in related_locations.
func test_alias_equal_to_live_id_names_live_record_in_related_locations() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	catalog.load_all(SHADOWING_ROOT)

	var errors: Array[Dictionary] = _errors(catalog)
	assert_int(errors.size()).is_equal(1)
	if errors.size() != 1:
		return  # Indexing an empty report would abort the whole suite.
	var related: Array = errors[0]["related_locations"]
	assert_int(related.size()).is_equal(1)
	assert_str((related[0] as Dictionary)["file_path"]).is_equal(SHADOWING_CHAR_A_PATH)


## T1 edge case: reversed discovery order (story 003 seam) reports the same
## shape, because the shadowing check reads the fully-populated post-load
## maps, never load order.
func test_alias_equal_to_live_id_reversed_discovery_order_reports_same_error() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	catalog.discovery_order_transform = func(listing: PackedStringArray) -> PackedStringArray:
		var reversed: PackedStringArray = listing.duplicate()
		reversed.reverse()
		return reversed

	var result: Error = catalog.load_all(SHADOWING_ROOT)

	assert_int(result).is_equal(FAILED)
	var errors: Array[Dictionary] = _errors(catalog)
	assert_int(errors.size()).is_equal(1)
	if errors.size() != 1:
		return  # Indexing an empty report would abort the whole suite.
	var entry: Dictionary = errors[0]
	assert_str(entry["record_id"]).is_equal("char_b")
	assert_str((entry["location"] as Dictionary)["file_path"]).is_equal(SHADOWING_CHAR_B_PATH)
	var related: Array = entry["related_locations"]
	assert_int(related.size()).is_equal(1)
	assert_str((related[0] as Dictionary)["file_path"]).is_equal(SHADOWING_CHAR_A_PATH)


## T2: char_c and char_d both declare alias "char_gone".
func test_alias_declared_twice_loads_failed() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())

	var result: Error = catalog.load_all(DECLARED_TWICE_ROOT)

	assert_int(result).is_equal(FAILED)
	assert_int(catalog.state).is_equal(ContentCatalogService.State.FAILED)


## T2: the entry is located at char_c (its path sorts first), same shape as
## story 011's duplicate-id check.
func test_alias_declared_twice_reports_one_error_located_at_first_sorting_path() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	catalog.load_all(DECLARED_TWICE_ROOT)

	var errors: Array[Dictionary] = _errors(catalog)
	assert_int(errors.size()).is_equal(1)
	if errors.size() != 1:
		return  # Indexing an empty report would abort the whole suite.
	var entry: Dictionary = errors[0]
	assert_str(String(entry["field"])).is_equal("aliases")
	assert_str((entry["location"] as Dictionary)["file_path"]).is_equal(DECLARED_TWICE_CHAR_C_PATH)


## T2: char_d, the other declaring record, is named in related_locations.
func test_alias_declared_twice_names_other_record_in_related_locations() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	catalog.load_all(DECLARED_TWICE_ROOT)

	var errors: Array[Dictionary] = _errors(catalog)
	assert_int(errors.size()).is_equal(1)
	if errors.size() != 1:
		return  # Indexing an empty report would abort the whole suite.
	var related: Array = errors[0]["related_locations"]
	assert_int(related.size()).is_equal(1)
	assert_str((related[0] as Dictionary)["file_path"]).is_equal(DECLARED_TWICE_CHAR_D_PATH)


## T3: char_user.move_ids == ["move_old"], move_old is move_new's alias.
func test_alias_reference_loads_ready_with_no_errors() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())

	var result: Error = catalog.load_all(ALIAS_REFERENCE_ROOT)

	assert_int(result).is_equal(OK)
	assert_int(catalog.state).is_equal(ContentCatalogService.State.READY)
	assert_int(_errors(catalog).size()).is_equal(0)


## T3: resolve_alias resolves the alias to its live record in one hop, and
## the live record is reachable through the resolved id.
func test_alias_reference_resolve_alias_returns_live_move_id() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	assert_int(catalog.load_all(ALIAS_REFERENCE_ROOT)).is_equal(OK)

	var resolved: String = catalog.resolve_alias("move_old")

	assert_str(resolved).is_equal("move_new")
	assert_object(catalog.get_record(&"move", resolved)).is_not_null()


## T3: resolve_alias of a live id returns that id unchanged, with no error.
func test_resolve_alias_live_id_returns_itself_unchanged() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	assert_int(catalog.load_all(ALIAS_REFERENCE_ROOT)).is_equal(OK)

	var resolved: String = catalog.resolve_alias("move_new")

	assert_str(resolved).is_equal("move_new")
	assert_str(String(catalog.last_lookup_error)).is_equal("")


## Regression (code review): char_e lists "char_same" twice in its own
## aliases. That is one duplicate-entry error on char_e, never a
## double-declaration naming char_e's own file as the other record.
func test_alias_listed_twice_in_one_record_reports_one_duplicate_error() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())

	var result: Error = catalog.load_all(ROOT + "/listed_twice")

	assert_int(result).is_equal(FAILED)
	var errors: Array[Dictionary] = _errors(catalog)
	assert_int(errors.size()).is_equal(1)
	if errors.size() != 1:
		return  # Indexing an empty report would abort the whole suite.
	assert_str(errors[0]["record_id"]).is_equal("char_e")
	assert_str(String(errors[0]["field"])).is_equal("aliases")
	assert_int((errors[0]["related_locations"] as Array).size()).is_equal(0)


## Regression (code review): char_b lists "char_a", a live id, twice. That is
## one duplicate-entry error plus one shadowing error, never the shadowing
## error twice and never a double-declaration.
func test_shadowing_alias_listed_twice_reports_duplicate_and_one_shadowing_error() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())

	catalog.load_all(ROOT + "/listed_twice_shadowing")

	var errors: Array[Dictionary] = _errors(catalog)
	assert_int(errors.size()).is_equal(2)
	var with_related := 0
	for entry: Dictionary in errors:
		assert_str(entry["record_id"]).is_equal("char_b")
		assert_str(String(entry["field"])).is_equal("aliases")
		if not (entry["related_locations"] as Array).is_empty():
			with_related += 1
	# Only the shadowing entry names another record (char_a).
	assert_int(with_related).is_equal(1)
