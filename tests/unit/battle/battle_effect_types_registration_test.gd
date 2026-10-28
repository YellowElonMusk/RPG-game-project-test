## Story 010 (ADR-0001 Vocabulary ownership; ADR-0004 §1 step 1; ADR-0010 §8;
## TR-content-006): `ContentBootstrap.run()` registers the six effect types
## the migrated moves use (the five Turn Battle types via `BattleEffectTypes`,
## plus `damage` on Stats' behalf), so a Move carrying any of them loads
## clean and an unregistered type is a validation error. Only error entries
## are asserted (RC-4): the fixture Moves are unreferenced, so each also
## produces the unreferenced-record warning, which is expected and not part
## of this criterion.
extends GdUnitTestSuite

const _VALID_ROOT: String = "res://tests/unit/battle/fixtures/effect_types/valid"
const _TYPO_ROOT: String = "res://tests/unit/battle/fixtures/effect_types/typo"


func _error_entries(catalog: ContentCatalogService) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	for entry: Dictionary in catalog.report:
		if entry["severity"] == &"error":
			errors.append(entry)
	return errors


# --- Test: six types load ---

func test_six_types_load_with_no_errors() -> void:
	var catalog := auto_free(ContentCatalogService.new()) as ContentCatalogService

	ContentBootstrap.run(catalog, _VALID_ROOT)

	var errors: Array[Dictionary] = _error_entries(catalog)
	assert_int(errors.size()).override_failure_message("errors: %s" % [errors]).is_equal(0)
	assert_int(catalog.state).override_failure_message(
			"report: %s" % [catalog.report]).is_equal(ContentCatalogService.State.READY)


## Edge case: `BattleEffectTypes.TURN_BATTLE` equals the 5 migrated names.
func test_turn_battle_equals_the_five_migrated_names() -> void:
	assert_array(Array(BattleEffectTypes.TURN_BATTLE)).is_equal(
			["stun", "heal_party", "heal_single", "damage_debuff", "direct_damage"])


# --- Test: typo errors once ---

func test_typo_errors_once() -> void:
	var catalog := auto_free(ContentCatalogService.new()) as ContentCatalogService

	ContentBootstrap.run(catalog, _TYPO_ROOT)

	assert_int(catalog.state).override_failure_message(
			"report: %s" % [catalog.report]).is_equal(ContentCatalogService.State.FAILED)
	var errors: Array[Dictionary] = _error_entries(catalog)
	assert_int(errors.size()).override_failure_message("errors: %s" % [errors]).is_equal(1)
	assert_str(errors[0]["record_id"]).is_equal("move_typo")
	assert_str(errors[0]["field"]).is_equal("effects")


## Edge case: `src/data/` never references `battle_effect_types.gd` or
## `BattleEffectTypes` -- it is called from `src/boot/` only (Forbidden rule,
## this layer).
func test_battle_effect_types_is_not_referenced_from_src_data() -> void:
	var dir: DirAccess = DirAccess.open("res://src/data")
	var offending: Array[String] = _scan_for_reference(dir, "res://src/data")
	assert_int(offending.size()).override_failure_message(
			"files referencing BattleEffectTypes: %s" % [offending]).is_equal(0)


func _scan_for_reference(dir: DirAccess, path: String) -> Array[String]:
	var offending: Array[String] = []
	# An unopenable directory is a failure, so the scan can never pass vacuously.
	if dir == null:
		offending.append("%s (could not open)" % path)
		return offending
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = path.path_join(entry)
		if dir.current_is_dir():
			offending.append_array(_scan_for_reference(DirAccess.open(full), full))
		elif entry.ends_with(".gd"):
			var content: String = FileAccess.get_file_as_string(full)
			if content.contains("battle_effect_types.gd") or content.contains("BattleEffectTypes"):
				offending.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return offending
