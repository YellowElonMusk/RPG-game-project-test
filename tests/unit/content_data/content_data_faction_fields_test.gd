## Story 018, AC-17 (TR-content-001; GDD Rule 8 "Faction rules"): an
## alien-only field on a human_nation, and a base_shape that does not match
## kind, each give one error naming the record and the field. Only
## error-severity entries are counted. Each test builds a fresh
## ContentCatalogService (never the autoload) and loads its own fixture root.
extends GdUnitTestSuite

const ROOT := "res://tests/unit/content_data/fixtures/faction_rules"
const VALID_ONE_OF_EACH := "res://tests/unit/content_data/fixtures/valid_one_of_each"
## The alien faction in valid_one_of_each, which sets all four alien-only fields.
const VALID_ALIEN_ID := "faction_tech_syndicate"

var _catalog: ContentCatalogService


func before_test() -> void:
	_catalog = auto_free(ContentCatalogService.new())


## The report's error-severity entries.
func _errors() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in _catalog.report:
		if entry["severity"] == &"error":
			out.append(entry)
	return out


## Asserts FAILED with exactly one error naming record_id and field.
func _assert_one_error(result: Error, record_id: String, field: String) -> void:
	assert_int(result).is_equal(FAILED)
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.FAILED)
	var errors: Array[Dictionary] = _errors()
	assert_int(errors.size()).override_failure_message("report: %s" % [_catalog.report]).is_equal(1)
	if errors.size() != 1:
		return  # Indexing an empty list would abort the whole suite.
	assert_str(errors[0]["record_id"]).is_equal(record_id)
	assert_str(String(errors[0]["field"])).is_equal(field)


## T1: signature_color on a human_nation is one error on signature_color.
func test_human_nation_with_signature_color_errors() -> void:
	var result: Error = _catalog.load_all(ROOT.path_join("human_signature_color"))

	_assert_one_error(result, "faction_human_x", "signature_color")


## T2: an alien with base_shape organic is one error on base_shape.
func test_alien_with_organic_shape_errors() -> void:
	var result: Error = _catalog.load_all(ROOT.path_join("alien_organic_shape"))

	_assert_one_error(result, "faction_alien_x", "base_shape")


## T3: a human_nation with base_shape square is one error on base_shape.
func test_human_nation_with_square_shape_errors() -> void:
	var result: Error = _catalog.load_all(ROOT.path_join("human_square_shape"))

	_assert_one_error(result, "faction_human_x", "base_shape")


## A human_nation setting two alien-only fields gets one error per field.
func test_human_nation_with_two_alien_only_fields_errors_once_per_field() -> void:
	var result: Error = _catalog.load_all(ROOT.path_join("human_two_alien_fields"))

	assert_int(result).is_equal(FAILED)
	var fields: Array[String] = []
	for entry: Dictionary in _errors():
		assert_str(entry["record_id"]).is_equal("faction_human_x")
		fields.append(String(entry["field"]))
	fields.sort()
	assert_array(fields).is_equal(["backup_icon_id", "patrol_archetype_id"])


## A kind outside the shape table is left to kind validation: no base_shape
## error.
func test_unknown_kind_gives_no_shape_error() -> void:
	_catalog.load_all(ROOT.path_join("unknown_kind"))

	for entry: Dictionary in _errors():
		assert_str(String(entry["field"])).is_not_equal("base_shape")


## Edge case: a valid alien faction with all four alien-only fields set and a
## matching shape gives no error.
func test_alien_with_all_alien_only_fields_loads_without_error() -> void:
	var result: Error = _catalog.load_all(VALID_ONE_OF_EACH)

	assert_int(result).is_equal(OK)
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.READY)
	for entry: Dictionary in _catalog.report:
		assert_str(entry["record_id"]).is_not_equal(VALID_ALIEN_ID)
