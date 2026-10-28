## Registers every shipped `FactionRule` class into a `FactionRuleRegistry`
## (ADR-0011 §4). The one place that knows every rule class that ships with
## the game; adding a faction's rule means adding one `register()` line here.
## Called once, from `ContentBootstrap.run()` (ADR-0004 §1 step 2).
##
## Usage example:
## [codeblock]
## var registry := FactionRuleRegistry.new()
## FactionRules.register_all(registry)
## [/codeblock]
class_name FactionRules
extends RefCounted


## Registers `bureaucratia_permit` and `megacorp_billing`, the two rule
## classes this chapter ships with.
## Example: [code]FactionRules.register_all(registry)[/code]
static func register_all(registry: FactionRuleRegistry) -> void:
	registry.register(&"bureaucratia_permit", BureaucratiaRuleValidator.create,
			BureaucratiaRuleValidator.validate_record)
	registry.register(&"megacorp_billing", MegaCorpRuleValidator.create,
			MegaCorpRuleValidator.validate_record)
