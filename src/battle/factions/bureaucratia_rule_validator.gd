## `bureaucratia_permit`'s factory and record validator (ADR-0011 §4/§5, story
## 011). The factory returns the shipped `BureaucratiaRule` unconfigured, on
## the interim "in-code defaults" path ADR-0011 Step 3 allows.
## # TODO(story-026): wire `_configure()` from the record's `params` once it exists.
##
## Usage example:
## [codeblock]
## registry.register(&"bureaucratia_permit", BureaucratiaRuleValidator.create,
##         BureaucratiaRuleValidator.validate_record)
## [/codeblock]
class_name BureaucratiaRuleValidator
extends RefCounted

## `params` keys whose type must be `int`, with the minimum each allows.
const _INT_PARAMS: Dictionary = {"permit_rounds": 0}
## `params` keys whose type must be `float`, with the inclusive `[min, max]` each allows.
const _FLOAT_RANGE_PARAMS: Dictionary = {"low_hp_threshold": {"min": 0.0, "max": 1.0}}
## `params` keys whose String value must be listed in the record's own `ref_ids`.
const _REF_ID_PARAMS: PackedStringArray = [
	"hunker_jab_move", "focus_attack_move", "late_fee_move", "mass_audit_move", "final_notice_move",
]
## Required `texts` keys (ADR-0011 §4).
const _REQUIRED_TEXTS: PackedStringArray = [
	"banner_locked_one", "banner_locked_other", "banner_unlocked", "tooltip_locked", "tooltip_unlocked",
]
## Required `colors` keys (ADR-0011 §4).
const _REQUIRED_COLORS: PackedStringArray = ["banner_unlocked"]


## The shipped rule, unconfigured (story 026 adds `_configure()`).
## Example: [code]var rule: FactionRule = BureaucratiaRuleValidator.create(faction, rule_record)[/code]
static func create(_faction: FactionData, _rule: FactionRuleData) -> FactionRule:
	return BureaucratiaRule.new()


## Pure: looks only at `rule`'s own fields (ADR-0004's validator contract).
## Example: [code]var errors: Array[Dictionary] = BureaucratiaRuleValidator.validate_record(rule)[/code]
static func validate_record(rule: FactionRuleData) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	for key: String in _INT_PARAMS:
		_check_int_min(rule.params, key, _INT_PARAMS[key], errors)
	for key: String in _FLOAT_RANGE_PARAMS:
		var bounds: Dictionary = _FLOAT_RANGE_PARAMS[key]
		_check_float_range(rule.params, key, bounds["min"], bounds["max"], errors)
	for key: String in _REF_ID_PARAMS:
		_check_ref_id_param(rule.params, key, rule.ref_ids, errors)
	for key: String in _REQUIRED_TEXTS:
		_check_required_key(rule.texts, "texts", key, errors)
	for key: String in _REQUIRED_COLORS:
		_check_required_key(rule.colors, "colors", key, errors)
	return errors


static func _check_int_min(params: Dictionary, key: String, minimum: int, errors: Array[Dictionary]) -> void:
	if not params.has(key):
		errors.append({"severity": &"error", "field": "params.%s" % key,
				"message": "params.%s is required." % key})
		return
	var value: Variant = params[key]
	if typeof(value) != TYPE_INT:
		errors.append({"severity": &"error", "field": "params.%s" % key,
				"message": "params.%s must be an int." % key})
		return
	if (value as int) < minimum:
		errors.append({"severity": &"error", "field": "params.%s" % key,
				"message": "params.%s must be >= %d." % [key, minimum]})


static func _check_float_range(params: Dictionary, key: String, minimum: float, maximum: float,
		errors: Array[Dictionary]) -> void:
	if not params.has(key):
		errors.append({"severity": &"error", "field": "params.%s" % key,
				"message": "params.%s is required." % key})
		return
	var value: Variant = params[key]
	if typeof(value) != TYPE_FLOAT:
		errors.append({"severity": &"error", "field": "params.%s" % key,
				"message": "params.%s must be a float." % key})
		return
	if (value as float) < minimum or (value as float) > maximum:
		errors.append({"severity": &"error", "field": "params.%s" % key,
				"message": "params.%s must be between %s and %s." % [key, minimum, maximum]})


static func _check_ref_id_param(params: Dictionary, key: String, ref_ids: PackedStringArray,
		errors: Array[Dictionary]) -> void:
	if not params.has(key):
		errors.append({"severity": &"error", "field": "params.%s" % key,
				"message": "params.%s is required." % key})
		return
	var value: Variant = params[key]
	if typeof(value) != TYPE_STRING:
		errors.append({"severity": &"error", "field": "params.%s" % key,
				"message": "params.%s must be a String." % key})
		return
	if not ref_ids.has(value as String):
		errors.append({"severity": &"error", "field": "params.%s" % key,
				"message": "params.%s (%s) must be listed in ref_ids." % [key, value]})


static func _check_required_key(group: Dictionary, group_name: String, key: String,
		errors: Array[Dictionary]) -> void:
	if not group.has(key):
		errors.append({"severity": &"error", "field": "%s.%s" % [group_name, key],
				"message": "%s.%s is required." % [group_name, key]})
