## Story 002, T-LOC (TR-content-012 / ADR-0013 §4): every string-typed export
## on each of the 12 record scripts is listed in exactly one of the script's
## LOC_FIELDS / NON_LOC_FIELDS constants, the lists do not intersect, every
## listed name is a real export, and the text-holding Dictionary
## FactionRuleData.texts is a LOC field. Structural check only; the
## LocFieldsValidator itself is ADR-0013's own implementation.
extends GdUnitTestSuite

## The 12 record scripts under src/data/records/. A class reference is not a
## constant expression in GDScript, so this is a var, not a const.
var RECORD_SCRIPTS: Array[Script] = [
	FactionData, CharacterData, EnemyData, MoveData, QuirkStateData, ComboData,
	ItemData, InputBindings, FactionRuleData, MapData, EncounterData,
	OccupationStageData,
]

const STRING_TYPES: Array[int] = [TYPE_STRING, TYPE_STRING_NAME, TYPE_PACKED_STRING_ARRAY]


## Every stored export of the script, optionally only the string-typed ones.
func _export_names(script: Script, string_only: bool) -> Array[StringName]:
	var names: Array[StringName] = []
	for prop: Dictionary in script.get_script_property_list():
		if not (prop["usage"] & PROPERTY_USAGE_STORAGE):
			continue
		if string_only and not STRING_TYPES.has(prop["type"]):
			continue
		names.append(StringName(prop["name"]))
	return names


func _loc_fields(script: Script) -> Array[StringName]:
	return script.get_script_constant_map()["LOC_FIELDS"]


func _non_loc_fields(script: Script) -> Array[StringName]:
	return script.get_script_constant_map()["NON_LOC_FIELDS"]


func test_twelve_record_scripts_are_checked() -> void:
	assert_int(RECORD_SCRIPTS.size()).is_equal(12)


func test_every_record_script_declares_both_constants() -> void:
	for script: Script in RECORD_SCRIPTS:
		var constants: Dictionary = script.get_script_constant_map()
		assert_bool(constants.has("LOC_FIELDS")).override_failure_message(
				"%s lacks LOC_FIELDS" % script.resource_path).is_true()
		assert_bool(constants.has("NON_LOC_FIELDS")).override_failure_message(
				"%s lacks NON_LOC_FIELDS" % script.resource_path).is_true()


func test_every_string_export_is_in_exactly_one_list() -> void:
	for script: Script in RECORD_SCRIPTS:
		var loc: Array[StringName] = _loc_fields(script)
		var non_loc: Array[StringName] = _non_loc_fields(script)
		for name: StringName in _export_names(script, true):
			var hits: int = int(loc.has(name)) + int(non_loc.has(name))
			assert_int(hits).override_failure_message(
					"%s.%s is in %d lists, expected exactly 1" % [script.resource_path, name, hits]).is_equal(1)


func test_loc_and_non_loc_lists_do_not_intersect() -> void:
	for script: Script in RECORD_SCRIPTS:
		var non_loc: Array[StringName] = _non_loc_fields(script)
		for name: StringName in _loc_fields(script):
			assert_bool(non_loc.has(name)).override_failure_message(
					"%s.%s is in both lists" % [script.resource_path, name]).is_false()


func test_every_listed_name_is_a_real_export() -> void:
	for script: Script in RECORD_SCRIPTS:
		var exports: Array[StringName] = _export_names(script, false)
		for name: StringName in _loc_fields(script) + _non_loc_fields(script):
			assert_bool(exports.has(name)).override_failure_message(
					"%s lists %s, which is not an export" % [script.resource_path, name]).is_true()


func test_faction_rule_texts_dictionary_is_a_loc_field() -> void:
	assert_bool(_loc_fields(FactionRuleData).has(&"texts")).is_true()
	assert_bool(_non_loc_fields(FactionRuleData).has(&"texts")).is_false()


func test_scripts_without_player_text_still_declare_empty_loc_fields() -> void:
	for script: Script in [InputBindings, EncounterData]:
		assert_array(_loc_fields(script)).override_failure_message(
				"%s should have no LOC fields" % script.resource_path).is_empty()
		assert_bool(_non_loc_fields(script).has(&"id")).is_true()
