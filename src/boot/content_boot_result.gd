## The boot result `ContentBootstrap.run()` returns (ADR-0011 §4: "`run()`
## returns the registry"). Today it carries only the `FactionRuleRegistry`
## `FactionRules.register_all()` filled. ADR-0004's Key Interfaces does not
## yet show this return type or the `.presentation_config` field ADR-0011
## expects it to grow -- owed to technical-director (story 011 Completion
## Notes); don't depend on anything beyond `.registry` here.
##
## Usage example:
## [codeblock]
## var result: ContentBootResult = ContentBootstrap.run(catalog)
## if result.registry.known_rule_classes().has(&"bureaucratia_permit"): ...
## [/codeblock]
class_name ContentBootResult
extends RefCounted

## The registry `FactionRules.register_all()` filled. Read-only after boot.
var registry: FactionRuleRegistry
