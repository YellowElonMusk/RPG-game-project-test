## Story 014, AC-13: a reference to a missing id, a wrong-type reference
## (`move_ids` naming a `char_` id; a Character `nation_id` naming an `alien`
## faction), a self-reference, a 2-record cycle, a 3-record cycle and a
## duplicate list entry each produce an error (TR-content-005; ADR-0001 Rule 3;
## ADR-0011 §4–§5). T3 and T4 call the pure cycle detector with synthetic edge
## maps; every other test loads one `reference_defects/*` fixture into a fresh
## ContentCatalogService (never the autoload). Each defect fixture is otherwise
## valid, so the reference rule under test is the only one that can fire.
extends GdUnitTestSuite

const ROOT := "res://tests/unit/content_data/fixtures/reference_defects"
const CYCLE3_ROOT := ROOT + "/cycle_3"
const CYCLE3_ENEMY_PATH := CYCLE3_ROOT + "/enemies/enemy_a.tres"
const CYCLE3_FACTION_PATH := CYCLE3_ROOT + "/factions/faction_a.tres"
const CYCLE3_RULE_PATH := CYCLE3_ROOT + "/faction_rules/rule_a.tres"


# Error entries only (severity == &"error"), in report order.
func _errors(catalog: ContentCatalogService) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in catalog.report:
		if entry["severity"] == &"error":
			out.append(entry)
	return out


# Loads `sub_dir` into a fresh catalog and asserts AC-13's failure shape:
# FAILED and exactly one error entry on `expected_field` of `expected_id`.
func _assert_one_reference_error(sub_dir: String, expected_id: String, expected_field: String) -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())

	var result: Error = catalog.load_all(ROOT.path_join(sub_dir))

	assert_int(result).is_equal(FAILED)
	assert_int(catalog.state).is_equal(ContentCatalogService.State.FAILED)
	var errors: Array[Dictionary] = _errors(catalog)
	assert_int(errors.size()).is_equal(1)
	if errors.size() != 1:
		return  # Indexing an empty report would abort the whole suite.
	assert_str(errors[0]["record_id"]).is_equal(expected_id)
	assert_str(String(errors[0]["field"])).is_equal(expected_field)


# Loads `sub_dir` into a fresh catalog and asserts READY with 0 error entries.
func _assert_ready_with_no_errors(sub_dir: String) -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())

	var result: Error = catalog.load_all(ROOT.path_join(sub_dir))

	assert_int(result).is_equal(OK)
	assert_int(catalog.state).is_equal(ContentCatalogService.State.READY)
	assert_int(_errors(catalog).size()).is_equal(0)


## T1: char_x.move_ids = ["move_nobody"].
func test_missing_id_reference_reports_one_error() -> void:
	_assert_one_reference_error("missing_id", "char_x", "move_ids")


## T2a: char_x.move_ids = ["char_y"], and char_y is a real Character.
func test_wrong_type_reference_in_move_ids_reports_one_error() -> void:
	_assert_one_reference_error("wrong_type_move_ids", "char_x", "move_ids")


## T2b: char_x.nation_id = "faction_alien_a", whose kind is alien.
func test_wrong_kind_nation_id_reference_reports_one_error() -> void:
	_assert_one_reference_error("wrong_kind_nation_id", "char_x", "nation_id")


## T3: a self-edge is a cycle of one.
func test_find_reference_cycles_self_edge_returns_one_cycle_of_one() -> void:
	var cycles: Array = ContentCatalogService.find_reference_cycles({"char_x": ["char_x"]})

	assert_int(cycles.size()).is_equal(1)
	if cycles.size() != 1:
		return  # Indexing an empty result would abort the whole suite.
	assert_array(cycles[0]).contains_exactly(["char_x"])


## T4: a 2-record cycle is returned once, starting at the member that sorts first.
func test_find_reference_cycles_two_node_cycle_returns_one_cycle_starting_at_sorted_first() -> void:
	var cycles: Array = ContentCatalogService.find_reference_cycles(
			{"node_b": ["node_a"], "node_a": ["node_b"]})

	assert_int(cycles.size()).is_equal(1)
	if cycles.size() != 1:
		return  # Indexing an empty result would abort the whole suite.
	assert_array(cycles[0]).contains_exactly(["node_a", "node_b"])


## T4 edge case: the walk enters the cycle from outside, at node_c, which does
## not sort first. The cycle is still returned once, starting at node_b.
func test_find_reference_cycles_cycle_entered_mid_way_starts_at_sorted_first() -> void:
	var cycles: Array = ContentCatalogService.find_reference_cycles(
			{"node_a": ["node_c"], "node_c": ["node_b"], "node_b": ["node_c"]})

	assert_int(cycles.size()).is_equal(1)
	if cycles.size() != 1:
		return  # Indexing an empty result would abort the whole suite.
	assert_array(cycles[0]).contains_exactly(["node_b", "node_c"])


## Regression: a recursive walk overflowed GDScript's call stack on a chain of
## about 1,100 records and silently returned no cycles. 3,000 is well past it.
func test_find_reference_cycles_3000_record_chain_returns_one_full_cycle() -> void:
	var edges: Dictionary = {}
	var chain_length := 3000
	for i in range(chain_length):
		edges["node_%05d" % i] = ["node_%05d" % ((i + 1) % chain_length)]

	var cycles: Array = ContentCatalogService.find_reference_cycles(edges)

	assert_int(cycles.size()).is_equal(1)
	if cycles.size() != 1:
		return  # Indexing an empty result would abort the whole suite.
	assert_int((cycles[0] as Array).size()).is_equal(chain_length)
	assert_str(cycles[0][0]).is_equal("node_00000")


## T5: faction_a → rule_id → rule_a → ref_ids → enemy_a → faction_id → faction_a,
## with all three fields registered (test-only), is one error located at
## enemy_a (its path sorts first), field faction_id, the other two members in
## related_locations in cycle order.
func test_three_record_cycle_with_registered_fields_reports_one_error() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	catalog.register_acyclic_field(&"faction", &"rule_id")
	catalog.register_acyclic_field(&"faction_rule", &"ref_ids")
	catalog.register_acyclic_field(&"enemy", &"faction_id")

	var result: Error = catalog.load_all(CYCLE3_ROOT)

	assert_int(result).is_equal(FAILED)
	var errors: Array[Dictionary] = _errors(catalog)
	assert_int(errors.size()).is_equal(1)
	if errors.size() != 1:
		return  # Indexing an empty report would abort the whole suite.
	var entry: Dictionary = errors[0]
	assert_str(entry["record_id"]).is_equal("enemy_a")
	assert_str(String(entry["field"])).is_equal("faction_id")
	assert_str((entry["location"] as Dictionary)["file_path"]).is_equal(CYCLE3_ENEMY_PATH)
	var related: Array = entry["related_locations"]
	assert_int(related.size()).is_equal(2)
	if related.size() != 2:
		return
	assert_str((related[0] as Dictionary)["file_path"]).is_equal(CYCLE3_FACTION_PATH)
	assert_str((related[1] as Dictionary)["file_path"]).is_equal(CYCLE3_RULE_PATH)


## T5 control: without the registrations the same chain is legal.
func test_three_record_cycle_without_registration_loads_ready_with_no_errors() -> void:
	_assert_ready_with_no_errors("cycle_3")


## T6: char_x.move_ids = ["move_a", "move_a"], and move_a is a real Move.
func test_duplicate_list_entry_reports_one_error() -> void:
	_assert_one_reference_error("duplicate_list_entry", "char_x", "move_ids")


## Edge case: char_x.move_ids names move_a by its alias move_a_old.
func test_reference_through_alias_loads_ready_with_no_errors() -> void:
	_assert_ready_with_no_errors("alias_reference_ok")


## Edge case: every REFERENCE_SCHEMA field resolves, so 0 error entries.
func test_valid_references_fixture_loads_ready_with_no_errors() -> void:
	_assert_ready_with_no_errors("valid_references")


## Edge case: a real self-reference through load_all(). char_x.move_ids names
## char_x itself, which is also a wrong type for move_ids; the value gives
## exactly one error, never a self-reference plus a wrong-type entry.
func test_self_reference_through_load_all_reports_one_error() -> void:
	_assert_one_reference_error("self_reference", "char_x", "move_ids")


## Edge case: a value that is both missing and repeated gives two errors on
## the same field, one for each rule, because the two checks are independent.
func test_repeated_missing_value_reports_missing_and_duplicate_errors() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())

	var result: Error = catalog.load_all(ROOT.path_join("duplicate_missing"))

	assert_int(result).is_equal(FAILED)
	var errors: Array[Dictionary] = _errors(catalog)
	assert_int(errors.size()).is_equal(2)
	for entry: Dictionary in errors:
		assert_str(entry["record_id"]).is_equal("char_x")
		assert_str(String(entry["field"])).is_equal("move_ids")
