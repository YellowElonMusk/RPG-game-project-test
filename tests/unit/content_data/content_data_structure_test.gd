## Story 015, AC-14 (TR-content-006; ADR-0001 "Validation mechanism",
## "Vocabulary ownership"): an unknown field, a missing / wrong-typed / empty /
## whitespace-only required field and an unknown EffectDescriptor `type` each
## give exactly one error naming the record and the field, and the catalog
## settles FAILED. Controls: an empty optional text field and a type with no
## required fields both load READY. Edge cases: multi-line values, a quoted
## string spanning lines, and the engine-written `script` key never give a
## false unknown-field entry; a record script with an Object-typed export is
## rejected. Each test builds a fresh ContentCatalogService (never the
## autoload) and loads its own fixture root under `structure_defects/`.
extends GdUnitTestSuite

const ReportFilters := preload("res://tests/unit/content_data/helpers/report_filters.gd")

const ROOT := "res://tests/unit/content_data/fixtures/structure_defects"
const VALID_ONE_OF_EACH := "res://tests/unit/content_data/fixtures/valid_one_of_each"

## The five migrated EffectDescriptor types, registered as a test double for
## Turn Battle System (which owns the real call).
const TURN_BATTLE_TYPES: Array[String] = ["stun", "heal_party", "heal_single", "damage_debuff", "direct_damage"]

var _catalog: ContentCatalogService


func before_test() -> void:
	_catalog = auto_free(ContentCatalogService.new())


## Asserts the load failed with exactly one error entry naming record_id and field.
func _assert_one_error(result: Error, record_id: String, field: String) -> void:
	assert_int(result).is_equal(FAILED)
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.FAILED)
	assert_int(ReportFilters.errors(_catalog.report).size()).is_equal(1)
	if ReportFilters.errors(_catalog.report).size() != 1:
		return  # Indexing an empty report would abort the whole suite.
	var entry: Dictionary = ReportFilters.errors(_catalog.report)[0]
	assert_str(String(entry["severity"])).is_equal("error")
	assert_str(entry["record_id"]).is_equal(record_id)
	assert_str(String(entry["field"])).is_equal(field)


## Asserts the load reached READY with no report entry at all.
func _assert_ready_and_clean(result: Error) -> void:
	assert_int(result).is_equal(OK)
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.READY)
	assert_array(ReportFilters.errors(_catalog.report)).is_empty()


func test_unknown_field_reports_error_naming_the_field() -> void:
	var result: Error = _catalog.load_all(ROOT + "/unknown_field")

	_assert_one_error(result, "char_structure_unknown", "stat_blok")


func test_missing_required_field_reports_error_naming_the_field() -> void:
	var result: Error = _catalog.load_all(ROOT + "/missing_required")

	_assert_one_error(result, "move_missing_display_name", "display_name")


func test_wrong_typed_required_field_reports_error_naming_the_field() -> void:
	var result: Error = _catalog.load_all(ROOT + "/wrong_typed_required")

	_assert_one_error(result, "move_wrong_typed_display_name", "display_name")


func test_empty_required_text_reports_error_naming_the_field() -> void:
	var result: Error = _catalog.load_all(ROOT + "/empty_required_text")

	_assert_one_error(result, "move_empty_display_name", "display_name")


func test_whitespace_only_required_text_reports_error_naming_the_field() -> void:
	var result: Error = _catalog.load_all(ROOT + "/whitespace_required_text")

	_assert_one_error(result, "move_whitespace_display_name", "display_name")


func test_unknown_effect_descriptor_type_reports_error_on_effects() -> void:
	_catalog.register_known_effect_types(&"turn_battle", PackedStringArray(TURN_BATTLE_TYPES))

	var result: Error = _catalog.load_all(ROOT + "/unknown_effect_type")

	_assert_one_error(result, "move_unknown_effect_type", "effects")


## Control: an optional text field (flavor_text) left empty is not an error.
## The fixture also carries the engine-written `resource_name` and
## `metadata/_edit_lock` keys, which are never reported as unknown fields.
func test_optional_text_field_empty_loads_ready_with_no_entry() -> void:
	var result: Error = _catalog.load_all(ROOT + "/optional_text_empty")

	_assert_ready_and_clean(result)


## Control 2: FactionRule declares REQUIRED_FIELDS = [], so an absent `texts`
## gives no required-field entry.
func test_type_with_no_required_fields_loads_ready_with_no_entry() -> void:
	var result: Error = _catalog.load_all(ROOT + "/no_required_fields")

	_assert_ready_and_clean(result)


## Edge case: the inner keys of multi-line values (effects, bindings, texts,
## params, typed dictionaries) in valid_one_of_each are never read as
## top-level keys. No vocabulary is registered: its provisional effect types
## (apply_quirk_state, ...) are outside the five migrated ones.
func test_multiline_values_produce_no_false_unknown_field_entries() -> void:
	var result: Error = _catalog.load_all(VALID_ONE_OF_EACH)

	assert_int(result).is_equal(OK)
	assert_array(ReportFilters.errors(_catalog.report)).is_empty()


## Edge case: every fixture file carries `script = ExtResource(...)`, which is
## not a script export; it is never reported.
func test_script_key_is_never_reported() -> void:
	_catalog.load_all(VALID_ONE_OF_EACH)

	for entry: Dictionary in _catalog.report:
		assert_str(String(entry["field"])).is_not_equal("script")
	assert_array(ReportFilters.errors(_catalog.report)).is_empty()


## Edge case (Engine Notes): Godot 4.7.2 writes a String holding a newline
## with a literal line break inside the quotes, so the fixture's flavor_text
## puts a `foo = bar` line inside the [resource] section. It is not a key.
func test_quoted_string_spanning_lines_produces_no_false_unknown_field_entry() -> void:
	var result: Error = _catalog.load_all(ROOT + "/multiline_string")

	_assert_ready_and_clean(result)


## Edge case (ADR-0001 Implementation Guidelines): a record script declaring
## an Object/Resource-typed export is one error naming that export.
func test_object_typed_export_reports_error_naming_the_export() -> void:
	var result: Error = _catalog.load_all(ROOT + "/object_export")

	_assert_one_error(result, "move_object_export", "bad_field")


## Code review regression: the Object-export entry is located at the file
## whose path sorts first, never at whichever file the folder listed first, and
## the second offending file of the type is not reported again. Reversing the
## discovery order (story 003 seam) must not move the entry.
func test_object_typed_export_reversed_discovery_order_reports_sorted_first_file() -> void:
	_catalog.discovery_order_transform = func(listing: PackedStringArray) -> PackedStringArray:
		var reversed: PackedStringArray = listing.duplicate()
		reversed.reverse()
		return reversed

	var result: Error = _catalog.load_all(ROOT + "/object_export")

	_assert_one_error(result, "move_object_export", "bad_field")
