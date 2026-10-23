## Content-catalog record: a faction's battle-rule parameters (ADR-0011 §5,
## type `faction_rule`, prefix `rule_`). `rule_class` names a class
## registered in FactionRuleRegistry — never resolved by reflection.
## `params` is deliberately an untyped Dictionary: its value types vary per
## rule class. Data only, no logic (Rule 4).
##
## Usage example:
## [codeblock]
## var rec: FactionRuleData = ContentCatalog.get_record(&"faction_rule", "rule_red_tape")
## var rule: FactionRule = registry.build(rec.rule_class, rec.params)
## [/codeblock]
class_name FactionRuleData
extends Resource

## Permanent lowercase snake_case ID with the `rule_` prefix (Rule 2).
@export var id: String = ""
## Prior IDs this record still answers to (Rule 2).
@export var aliases: PackedStringArray = PackedStringArray()
## One of the registered rule classes (ADR-0011 §5).
@export var rule_class: StringName = &""
## Record IDs the rule references; checked by the generic reference pass.
@export var ref_ids: PackedStringArray = PackedStringArray()
## Rule parameters; the rule class owns their meaning and types.
@export var params: Dictionary = {}
## Player-visible texts keyed by role (banner, tooltip, ...). LocText source.
@export var texts: Dictionary = {}
## Hex colours keyed by role (identity, banner, ...).
@export var colors: Dictionary = {}

## Player-visible text exports (TR-content-012, ADR-0013 §4). `texts` is a
## text-holding Dictionary and is listed here on purpose.
const LOC_FIELDS: Array[StringName] = [&"texts"]
## IDs and enum-like strings (ADR-0013 §4).
const NON_LOC_FIELDS: Array[StringName] = [&"id", &"aliases", &"rule_class", &"ref_ids"]
