## Maps a `FactionRuleData.rule_class` to its factory and its record
## validator (ADR-0011 §4). Built by `ContentBootstrap.run()` step 2, filled by
## `FactionRules.register_all()`, and wired into the catalog through
## `ContentBootstrap.register_faction_rule_validator()`; never resolved by
## reflection. Read-only after boot.
##
## `FactionRules` does not exist yet (Faction Rule Modifiers epic), so no
## production rule class is registered today; catalog tests register a stub
## (story 017).
##
## Usage example:
## [codeblock]
## var registry := FactionRuleRegistry.new()
## registry.register(&"bureaucratia_permit", BureaucratiaRule.create, BureaucratiaRule.validate_record)
## var rule: FactionRule = registry.create(faction, rule_record)
## [/codeblock]
class_name FactionRuleRegistry
extends RefCounted

# rule_class → Callable(faction: FactionData, rule: FactionRuleData) -> FactionRule.
var _factories: Dictionary = {}
# rule_class → Callable(rule: FactionRuleData) -> Array[Dictionary].
var _validators: Dictionary = {}


## Registers `rule_class` with its `factory` and its pure record `validator`
## (ADR-0011 §4). A second registration of the same class overwrites the
## first with a warning.
## Example: [code]registry.register(&"bureaucratia_permit", BureaucratiaRule.create, BureaucratiaRule.validate_record)[/code]
func register(rule_class: StringName, factory: Callable, validator: Callable) -> void:
	if _validators.has(rule_class):
		push_warning("FactionRuleRegistry.register(%s): overwriting an existing registration." % rule_class)
	_factories[rule_class] = factory
	_validators[rule_class] = validator


## Builds the `FactionRule` for `faction` from its rule record through the
## registered factory. Does no lookups (ADR-0011 §4). An unregistered
## `rule_class` logs an error and returns `null`; the catalog's faction_rule
## validator makes that unreachable after a READY load.
## Example: [code]var rule: FactionRule = registry.create(faction, rule_record)[/code]
func create(faction: FactionData, rule: FactionRuleData) -> FactionRule:
	if not _factories.has(rule.rule_class):
		push_error("FactionRuleRegistry.create(%s): rule_class %s is not registered." % [faction.id, rule.rule_class])
		return null
	return (_factories[rule.rule_class] as Callable).call(faction, rule)


## Every registered `rule_class`, in registration order.
## Example: [code]if not registry.known_rule_classes().has(rec.rule_class): ...[/code]
func known_rule_classes() -> PackedStringArray:
	var out := PackedStringArray()
	for rule_class: StringName in _validators:
		out.append(rule_class)
	return out


## The validator registered for `rule_class`, or an invalid `Callable` when
## none is. Callers check `known_rule_classes()` first.
## Example: [code]var errors: Array = registry.validator_for(rec.rule_class).call(rec)[/code]
func validator_for(rule_class: StringName) -> Callable:
	return _validators.get(rule_class, Callable())
