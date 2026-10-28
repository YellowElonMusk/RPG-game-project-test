## Story 011 (ADR-0011 §4/§5; ADR-0004 §1 step 2; TR-factionrules-002):
## `ContentBootstrap.run()` builds a `FactionRuleRegistry`, fills it with
## `FactionRules.register_all()`, and wires its `faction_rule` validator --
## so `bureaucratia_permit` and `megacorp_billing` are known classes, a
## fixture record of each with its shipped params loads with no error naming
## it, and each listed defect produces exactly one error on the right field.
## Only error entries are asserted (RC-4): the fixture rules are unreferenced,
## so each also produces the unreferenced-record warning, which is expected
## and not part of this criterion.
extends GdUnitTestSuite

const _ROOT: String = "res://tests/unit/battle/fixtures/rule_classes"

var _last_report: Array[Dictionary] = []


func _errors_for(record_id: String) -> Array[Dictionary]:
	var catalog_errors: Array[Dictionary] = []
	for entry: Dictionary in _last_report:
		if entry["severity"] == &"error" and entry["record_id"] == record_id:
			catalog_errors.append(entry)
	return catalog_errors


func _run_and_capture() -> ContentBootResult:
	var catalog := auto_free(ContentCatalogService.new()) as ContentCatalogService
	var result: ContentBootResult = ContentBootstrap.run(catalog, _ROOT)
	_last_report = catalog.report
	return result


# --- Test: classes known ---

func test_classes_known() -> void:
	var result: ContentBootResult = _run_and_capture()
	var known: PackedStringArray = result.registry.known_rule_classes()
	assert_array(Array(known)).contains([&"bureaucratia_permit", &"megacorp_billing"])


# --- Test: shipped params pass ---

func test_bureaucratia_shipped_params_pass() -> void:
	_run_and_capture()
	var errors: Array[Dictionary] = _errors_for("rule_bureaucratia_permit_ok")
	assert_int(errors.size()).override_failure_message("errors: %s" % [errors]).is_equal(0)


func test_megacorp_shipped_params_pass() -> void:
	_run_and_capture()
	var errors: Array[Dictionary] = _errors_for("rule_megacorp_billing_ok")
	assert_int(errors.size()).override_failure_message("errors: %s" % [errors]).is_equal(0)


# --- Test: one error each (Bureaucratia) ---

func test_bureaucratia_missing_param_errors_once() -> void:
	_run_and_capture()
	var errors: Array[Dictionary] = _errors_for("rule_bureaucratia_permit_missing_param")
	assert_int(errors.size()).override_failure_message("errors: %s" % [errors]).is_equal(1)
	assert_str(errors[0]["field"]).is_equal("params.permit_rounds")


func test_bureaucratia_wrong_type_errors_once() -> void:
	_run_and_capture()
	var errors: Array[Dictionary] = _errors_for("rule_bureaucratia_permit_wrong_type")
	assert_int(errors.size()).override_failure_message("errors: %s" % [errors]).is_equal(1)
	assert_str(errors[0]["field"]).is_equal("params.permit_rounds")


func test_bureaucratia_bad_ref_errors_once() -> void:
	_run_and_capture()
	var errors: Array[Dictionary] = _errors_for("rule_bureaucratia_permit_bad_ref")
	assert_int(errors.size()).override_failure_message("errors: %s" % [errors]).is_equal(1)
	assert_str(errors[0]["field"]).is_equal("params.late_fee_move")


func test_bureaucratia_missing_text_errors_once() -> void:
	_run_and_capture()
	var errors: Array[Dictionary] = _errors_for("rule_bureaucratia_permit_missing_text")
	assert_int(errors.size()).override_failure_message("errors: %s" % [errors]).is_equal(1)
	assert_str(errors[0]["field"]).is_equal("texts.banner_unlocked")


## Edge case: permit_rounds = 0 passes, low_hp_threshold 0.0 passes.
func test_bureaucratia_boundary_low_passes() -> void:
	_run_and_capture()
	var errors: Array[Dictionary] = _errors_for("rule_bureaucratia_boundary_low")
	assert_int(errors.size()).override_failure_message("errors: %s" % [errors]).is_equal(0)


## Edge case: low_hp_threshold 1.0 passes.
func test_bureaucratia_boundary_high_passes() -> void:
	_run_and_capture()
	var errors: Array[Dictionary] = _errors_for("rule_bureaucratia_boundary_high")
	assert_int(errors.size()).override_failure_message("errors: %s" % [errors]).is_equal(0)


## Edge case: permit_rounds = -1 errors.
func test_bureaucratia_permit_rounds_negative_errors() -> void:
	_run_and_capture()
	var errors: Array[Dictionary] = _errors_for("rule_bureaucratia_permit_rounds_neg")
	assert_int(errors.size()).override_failure_message("errors: %s" % [errors]).is_equal(1)
	assert_str(errors[0]["field"]).is_equal("params.permit_rounds")


## Edge case: low_hp_threshold 1.01 errors.
func test_bureaucratia_low_hp_over_errors() -> void:
	_run_and_capture()
	var errors: Array[Dictionary] = _errors_for("rule_bureaucratia_low_hp_over")
	assert_int(errors.size()).override_failure_message("errors: %s" % [errors]).is_equal(1)
	assert_str(errors[0]["field"]).is_equal("params.low_hp_threshold")


# --- Test: one error each (MegaCorp) ---

func test_megacorp_missing_param_errors_once() -> void:
	_run_and_capture()
	var errors: Array[Dictionary] = _errors_for("rule_megacorp_billing_missing_param")
	assert_int(errors.size()).override_failure_message("errors: %s" % [errors]).is_equal(1)
	assert_str(errors[0]["field"]).is_equal("params.bill_mp")


func test_megacorp_wrong_type_errors_once() -> void:
	_run_and_capture()
	var errors: Array[Dictionary] = _errors_for("rule_megacorp_billing_wrong_type")
	assert_int(errors.size()).override_failure_message("errors: %s" % [errors]).is_equal(1)
	assert_str(errors[0]["field"]).is_equal("params.bill_mp")


## Edge case: an ID param missing from `ref_ids`, on a `role.<enemy_id>` key.
func test_megacorp_bad_ref_errors_once() -> void:
	_run_and_capture()
	var errors: Array[Dictionary] = _errors_for("rule_megacorp_billing_bad_ref")
	assert_int(errors.size()).override_failure_message("errors: %s" % [errors]).is_equal(1)
	assert_str(errors[0]["field"]).is_equal("params.role.enemy_middle_manager")


func test_megacorp_missing_text_errors_once() -> void:
	_run_and_capture()
	var errors: Array[Dictionary] = _errors_for("rule_megacorp_billing_missing_text")
	assert_int(errors.size()).override_failure_message("errors: %s" % [errors]).is_equal(1)
	assert_str(errors[0]["field"]).is_equal("texts.note_suspended")
