## `liberty7_freedom`'s factory and record validator (ADR-0011 §4/§5). The
## factory configures `Liberty7Rule` from the record's `texts`.
##
## Usage example:
## [codeblock]
## registry.register(&"liberty7_freedom", Liberty7RuleValidator.create,
##         Liberty7RuleValidator.validate_record)
## [/codeblock]
class_name Liberty7RuleValidator
extends RefCounted

## Required `texts` keys (ADR-0011 §4).
const _REQUIRED_TEXTS: PackedStringArray = ["banner", "tooltip", "note_repeat"]


## The shipped rule, configured from `rule`.
## Example: [code]var rule: FactionRule = Liberty7RuleValidator.create(faction, rule_record)[/code]
static func create(_faction: FactionData, rule: FactionRuleData) -> FactionRule:
	var out := Liberty7Rule.new()
	if rule != null:
		out.configure(rule.params, rule.texts)
	return out


## Pure: looks only at `rule`'s own fields (ADR-0004's validator contract).
## Example: [code]var errors: Array[Dictionary] = Liberty7RuleValidator.validate_record(rule)[/code]
static func validate_record(rule: FactionRuleData) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	for key: String in _REQUIRED_TEXTS:
		if not rule.texts.has(key):
			errors.append({"severity": &"error", "field": "texts.%s" % key,
					"message": "texts.%s is required." % key})
	return errors
