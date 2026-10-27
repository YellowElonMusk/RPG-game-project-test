## Story 019, AC-18 (TR-content-003; GDD Edge Cases "Faction rules", "Other
## warnings"): two alien factions sharing signature_color, two sharing
## base_shape, a Character whose signature_move_id is also in its move_ids,
## and a record nothing references each give exactly one warning, and the
## catalog stays READY. Root types never warn as unreferenced. Each test builds
## a fresh ContentCatalogService (never the autoload) and loads its own
## fixture root under warnings/.
extends GdUnitTestSuite

const ROOT := "res://tests/unit/content_data/fixtures/warnings"

var _catalog: ContentCatalogService


func before_test() -> void:
	_catalog = auto_free(ContentCatalogService.new())


## Loads `dir` and asserts OK, READY and exactly one report entry, a warning
## naming record_id and field; returns it (empty when the count is wrong).
func _assert_one_warning(dir: String, record_id: String, field: String) -> Dictionary:
	var result: Error = _catalog.load_all(ROOT.path_join(dir))

	assert_int(result).is_equal(OK)
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.READY)
	assert_int(_catalog.report.size()).override_failure_message(
			"report: %s" % [_catalog.report]).is_equal(1)
	if _catalog.report.size() != 1:
		return {}  # Indexing an empty report would abort the whole suite.
	var entry: Dictionary = _catalog.report[0]
	assert_str(String(entry["severity"])).is_equal("warning")
	assert_str(entry["record_id"]).is_equal(record_id)
	assert_str(String(entry["field"])).is_equal(field)
	return entry


## T1: two aliens sharing signature_color give one warning on the first, with
## the other in related_locations.
func test_two_aliens_sharing_signature_color_warn_once() -> void:
	var entry: Dictionary = _assert_one_warning("shared_color", "faction_alien_a", "signature_color")

	if entry.is_empty():
		return
	var related: Array = entry["related_locations"]
	assert_int(related.size()).is_equal(1)
	if related.size() == 1:
		assert_str((related[0] as Dictionary)["file_path"]).ends_with("faction_alien_b.tres")


## T2: two aliens sharing base_shape give one warning on base_shape.
func test_two_aliens_sharing_base_shape_warn_once() -> void:
	_assert_one_warning("shared_shape", "faction_alien_a", "base_shape")


## T3: a Character whose signature_move_id is also in move_ids warns once.
func test_signature_move_in_move_ids_warns() -> void:
	_assert_one_warning("signature_in_move_ids", "char_x", "signature_move_id")


## T4: a QuirkState nothing references warns once, on the whole record.
func test_unreferenced_record_warns() -> void:
	_assert_one_warning("unreferenced", "quirk_orphan", "")


## A QuirkState used only through a Move's effects is referenced: no warning
## (GDD Edge Cases "Other warnings": "a QuirkState no Move or Combo uses").
func test_record_used_by_move_effect_does_not_warn() -> void:
	var result: Error = _catalog.load_all(ROOT.path_join("effect_referenced"))

	assert_int(result).is_equal(OK)
	assert_array(_catalog.report).override_failure_message(
			"report: %s" % [_catalog.report]).is_empty()


## Two aliens sharing both colour and shape give one warning per field.
func test_aliens_sharing_colour_and_shape_warn_once_per_field() -> void:
	var result: Error = _catalog.load_all(ROOT.path_join("shared_both"))

	assert_int(result).is_equal(OK)
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.READY)
	var fields: Array[String] = []
	for entry: Dictionary in _catalog.report:
		assert_str(String(entry["severity"])).is_equal("warning")
		assert_str(entry["record_id"]).is_equal("faction_alien_a")
		fields.append(String(entry["field"]))
	fields.sort()
	assert_array(fields).is_equal(["base_shape", "signature_color"])


## Edge case: a fixture of only root-type records gives no entry at all.
func test_only_root_type_records_give_no_entry() -> void:
	var result: Error = _catalog.load_all(ROOT.path_join("only_roots"))

	assert_int(result).is_equal(OK)
	assert_array(_catalog.report).override_failure_message(
			"report: %s" % [_catalog.report]).is_empty()


## Edge case: a record referenced only through its alias does not warn.
func test_record_referenced_through_alias_does_not_warn() -> void:
	var result: Error = _catalog.load_all(ROOT.path_join("alias_referenced"))

	assert_int(result).is_equal(OK)
	assert_array(_catalog.report).override_failure_message(
			"report: %s" % [_catalog.report]).is_empty()
