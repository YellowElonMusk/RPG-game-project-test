## `influencia_followers`'s factory and record validator (ADR-0011 §4/§5).
## The factory configures `InfluenciaRule` from the record's `params` and
## `texts`.
##
## Usage example:
## [codeblock]
## registry.register(&"influencia_followers", InfluenciaRuleValidator.create,
##         InfluenciaRuleValidator.validate_record)
## [/codeblock]
class_name InfluenciaRuleValidator
extends RefCounted

## `params` keys whose type must be `int`, with the minimum each allows.
const _INT_PARAMS: Dictionary = {"follower_attack": 0, "max_followers": 1}
## Required `texts` keys (ADR-0011 §4).
const _REQUIRED_TEXTS: PackedStringArray = ["banner", "tooltip", "badge", "note_followers"]


## The shipped rule, configured from `rule`.
## Example: [code]var rule: FactionRule = InfluenciaRuleValidator.create(faction, rule_record)[/code]
static func create(_faction: FactionData, rule: FactionRuleData) -> FactionRule:
	var out := InfluenciaRule.new()
	if rule != null:
		out.configure(rule.params, rule.texts)
	return out


## Pure: looks only at `rule`'s own fields (ADR-0004's validator contract).
## Example: [code]var errors: Array[Dictionary] = InfluenciaRuleValidator.validate_record(rule)[/code]
static func validate_record(rule: FactionRuleData) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	for key: String in _INT_PARAMS:
		if not rule.params.has(key) or typeof(rule.params[key]) != TYPE_INT:
			errors.append({"severity": &"error", "field": "params.%s" % key,
					"message": "params.%s is required and must be an int." % key})
		elif int(rule.params[key]) < int(_INT_PARAMS[key]):
			errors.append({"severity": &"error", "field": "params.%s" % key,
					"message": "params.%s must be >= %d." % [key, _INT_PARAMS[key]]})
	for key: String in _REQUIRED_TEXTS:
		if not rule.texts.has(key):
			errors.append({"severity": &"error", "field": "texts.%s" % key,
					"message": "texts.%s is required." % key})
	return errors
