## `megacorp_billing`'s factory and record validator (ADR-0011 §4/§5, story
## 011). The factory returns the shipped `MegaCorpRule` unconfigured, on the
## interim "in-code defaults" path ADR-0011 Step 3 allows.
## # TODO(story-026): wire `_configure()` from the record's `params` once it exists.
##
## Usage example:
## [codeblock]
## registry.register(&"megacorp_billing", MegaCorpRuleValidator.create,
##         MegaCorpRuleValidator.validate_record)
## [/codeblock]
class_name MegaCorpRuleValidator
extends RefCounted

## `params` keys whose type must be `int`, with the minimum each allows.
const _INT_PARAMS: Dictionary = {"bill_mp": 0}
## `params` keys whose String value must be listed in the record's own `ref_ids`.
const _REF_ID_PARAMS: PackedStringArray = [
	"laser_scan_move", "upsell_move", "layoffs_move", "hostile_takeover_move",
]
## Prefix of the enemy -> move role keys (Q5 flat keys: `"role.<enemy_id>": "<move>"`).
const _ROLE_KEY_PREFIX: String = "role."
## Required `texts` keys (ADR-0011 §4).
const _REQUIRED_TEXTS: PackedStringArray = ["banner", "tooltip", "note_suspended"]


## The shipped rule, unconfigured (story 026 adds `_configure()`).
## Example: [code]var rule: FactionRule = MegaCorpRuleValidator.create(faction, rule_record)[/code]
static func create(_faction: FactionData, _rule: FactionRuleData) -> FactionRule:
	return MegaCorpRule.new()


## Pure: looks only at `rule`'s own fields (ADR-0004's validator contract).
## Example: [code]var errors: Array[Dictionary] = MegaCorpRuleValidator.validate_record(rule)[/code]
static func validate_record(rule: FactionRuleData) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	for key: String in _INT_PARAMS:
		_check_int_min(rule.params, key, _INT_PARAMS[key], errors)
	for key: String in _REF_ID_PARAMS:
		_check_ref_id_param(rule.params, key, rule.ref_ids, errors)
	for key: String in rule.params:
		if key.begins_with(_ROLE_KEY_PREFIX):
			_check_role_enemy_id(key, rule.ref_ids, errors)
	for key: String in _REQUIRED_TEXTS:
		_check_required_key(rule.texts, "texts", key, errors)
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


## The enemy ID is the part of the key after "role." (Q5 flat keys); it must
## be listed in the record's own `ref_ids`, same as any other ID-valued param.
static func _check_role_enemy_id(key: String, ref_ids: PackedStringArray, errors: Array[Dictionary]) -> void:
	var enemy_id: String = key.substr(_ROLE_KEY_PREFIX.length())
	if not ref_ids.has(enemy_id):
		errors.append({"severity": &"error", "field": "params.%s" % key,
				"message": "params.%s (%s) must be listed in ref_ids." % [key, enemy_id]})


static func _check_required_key(group: Dictionary, group_name: String, key: String,
		errors: Array[Dictionary]) -> void:
	if not group.has(key):
		errors.append({"severity": &"error", "field": "%s.%s" % [group_name, key],
				"message": "%s.%s is required." % [group_name, key]})
