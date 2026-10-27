## Story 017, AC-27 (TR-content-001; ADR-0012 §3, ADR-0011 §4): at most one
## Map sets new_game_entry, no two OccupationStage records share one
## (faction_id, stage) pair, a human_nation Faction may not set
## patrol_archetype_id, and a registered faction_rule loads. The two
## uniqueness checks and the alien-only-field check are catalog-wide generic
## passes, never registered validators; the faction_rule check goes through
## ContentBootstrap.register_faction_rule_validator() with a stub
## FactionRuleRegistry registering &"test_rule_ok", never a real rule class.
## Each test builds a fresh ContentCatalogService (never the autoload).
extends GdUnitTestSuite

const ROOT := "res://tests/unit/content_data/fixtures/overworld_and_rules"

var _catalog: ContentCatalogService


func before_test() -> void:
	_catalog = auto_free(ContentCatalogService.new())


## Registers a FactionRuleRegistry knowing one stub rule class,
## &"test_rule_ok", whose validator returns `validator_entries` (none = it
## passes), through the same ContentBootstrap path run() will use.
func _register_stub_faction_rule_validator(validator_entries: Array[Dictionary] = []) -> void:
	var registry := FactionRuleRegistry.new()
	var stub_factory := func(_faction: FactionData, _rule: FactionRuleData) -> FactionRule:
		return FactionRule.new()
	var stub_validator := func(_record: FactionRuleData) -> Array[Dictionary]:
		return validator_entries
	registry.register(&"test_rule_ok", stub_factory, stub_validator)
	ContentBootstrap.register_faction_rule_validator(_catalog, registry)


## Asserts FAILED with exactly one error naming record_id and field, and
## returns that entry (or an empty Dictionary when the count is wrong).
func _assert_one_error(result: Error, record_id: String, field: String) -> Dictionary:
	assert_int(result).is_equal(FAILED)
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.FAILED)
	assert_int(_catalog.report.size()).override_failure_message(
			"report: %s" % [_catalog.report]).is_equal(1)
	if _catalog.report.size() != 1:
		return {}  # Indexing an empty report would abort the whole suite.
	var entry: Dictionary = _catalog.report[0]
	assert_str(String(entry["severity"])).is_equal("error")
	assert_str(entry["record_id"]).is_equal(record_id)
	assert_str(String(entry["field"])).is_equal(field)
	return entry


## Asserts entry's location ends with first_file and its one related
## location ends with other_file.
func _assert_located(entry: Dictionary, first_file: String, other_file: String) -> void:
	if entry.is_empty():
		return
	assert_str((entry["location"] as Dictionary)["file_path"]).ends_with(first_file)
	var related: Array = entry["related_locations"]
	assert_int(related.size()).is_equal(1)
	if related.size() == 1:
		assert_str((related[0] as Dictionary)["file_path"]).ends_with(other_file)


# --- T1: two Maps with new_game_entry ---

func test_two_maps_with_new_game_entry_errors_naming_both() -> void:
	var result: Error = _catalog.load_all(ROOT.path_join("two_new_game_entry"))

	var entry: Dictionary = _assert_one_error(result, "map_a", "new_game_entry")
	_assert_located(entry, "map_a.tres", "map_b.tres")


## Edge case: two Maps with no new_game_entry at all is valid.
func test_two_maps_without_new_game_entry_loads_ready() -> void:
	var result: Error = _catalog.load_all(ROOT.path_join("two_new_game_entry/none_set"))

	assert_int(result).is_equal(OK)
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.READY)
	assert_array(_catalog.report).override_failure_message(
			"report: %s" % [_catalog.report]).is_empty()


# --- T2: duplicate (faction_id, stage) ---

func test_duplicate_faction_stage_pair_errors_naming_both() -> void:
	var result: Error = _catalog.load_all(ROOT.path_join("duplicate_faction_stage"))

	var entry: Dictionary = _assert_one_error(result, "ostage_x_1", "stage")
	_assert_located(entry, "ostage_x_1.tres", "ostage_x_1b.tres")


# --- T3: human_nation with patrol_archetype_id ---

func test_human_nation_with_patrol_archetype_id_errors() -> void:
	var result: Error = _catalog.load_all(ROOT.path_join("human_patrol_archetype"))

	var entry: Dictionary = _assert_one_error(result, "faction_human_y", "patrol_archetype_id")
	if not entry.is_empty():
		assert_str((entry["location"] as Dictionary)["file_path"]).ends_with("faction_human_y.tres")


# --- T4: a registered faction_rule loads ---

func test_registered_rule_class_loads_ready() -> void:
	_register_stub_faction_rule_validator()

	var result: Error = _catalog.load_all(ROOT.path_join("registered_rule_ok"))

	assert_int(result).is_equal(OK)
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.READY)
	assert_array(_catalog.report).override_failure_message(
			"report: %s" % [_catalog.report]).is_empty()
	assert_object(_catalog.get_record(&"faction_rule", "rule_ok")).is_not_null()


## A registered rule class's own validator error reaches the report on the
## rule record (ADR-0011 §4 Boot: validator_for(rule_class) must pass).
func test_registered_rule_validator_error_reaches_report() -> void:
	_register_stub_faction_rule_validator([{"severity": &"error", "field": "params", "message": "m"}])

	var result: Error = _catalog.load_all(ROOT.path_join("registered_rule_ok"))

	_assert_one_error(result, "rule_ok", "params")


## Edge case: rule_ok with rule_class &"not_registered" is one error on
## rule_class (ADR-0011 Verification).
func test_unregistered_rule_class_errors_naming_rule_class_field() -> void:
	_register_stub_faction_rule_validator()

	var result: Error = _catalog.load_all(ROOT.path_join("unregistered_rule"))

	_assert_one_error(result, "rule_ok", "rule_class")
