## The one place that knows every content-catalog registrant (ADR-0004
## Content Boot Ordering). `run()` registers vocabularies and validators in
## ADR-0004 §1 order and is the only production caller of
## `ContentCatalogService.load_all()`. `GameRoot._enter_tree()` (Game State
## epic), harness scenes and `validate-content.gd` call it; nothing else does.
##
## The `data_root` pass-through is an additive default parameter that
## ADR-0004's Key Interfaces does not show yet; story 027's `--data-root=`
## needs it.
##
## Usage example:
## [codeblock]
## func _enter_tree() -> void:
##     ContentBootstrap.run(ContentCatalog)
##     # ContentCatalog.state is now READY or FAILED.
## [/codeblock]
class_name ContentBootstrap


## Runs every registrant, then `catalog.load_all(data_root)`. A no-op unless
## `catalog.state == UNLOADED`, so a second call can never double-register.
##
## Registrant lines are added here by the story or epic that builds each
## registrant (ADR-0004 §1, as amended by ADR-0007, ADR-0011 and ADR-0013):
##   1. Turn Battle effect-type registration.
##   2. Faction Rule registration: build the `FactionRuleRegistry`, fill it
##      with `FactionRules.register_all()`, then register its `faction_rule`
##      record validator with `register_faction_rule_validator()` (story 017).
##      Not wired yet (see the TODO below): `FactionRules` does not exist, and
##      an empty registry would reject every `faction_rule` record at boot.
##   3. `register_record_validator` calls: `InputBindingsValidator`, the Stats
##      validators (`StatsConfig.load_or_default()` bound), `LocFieldsValidator`.
##   4. `catalog.load_all()`.
## Steps 1-3 have no complete registrant yet, so today only step 4 runs.
## Example: [code]ContentBootstrap.run(catalog, "res://tests/unit/content_data/fixtures/valid_one_of_each")[/code]
static func run(catalog: ContentCatalogService, data_root: String = "res://data") -> void:
	if catalog.state != ContentCatalogService.State.UNLOADED:
		return
	# TODO(ADR-0011): once the Faction Rule Modifiers epic builds FactionRules:
	#   var registry := FactionRuleRegistry.new()
	#   FactionRules.register_all(registry)
	#   register_faction_rule_validator(catalog, registry)
	catalog.load_all(data_root)


## Registers the one `&"faction_rule"` record validator on `catalog`, built
## from `registry` (ADR-0011 §4 Boot). A `rule_class` missing from
## `registry.known_rule_classes()` is one error on field `rule_class`;
## otherwise the record goes to `registry.validator_for(rule_class)`. `run()`
## and the catalog's unit tests both use this, so they share one code path.
## Example: [code]ContentBootstrap.register_faction_rule_validator(catalog, registry)[/code]
static func register_faction_rule_validator(catalog: ContentCatalogService, registry: FactionRuleRegistry) -> void:
	# Untyped return: the rule class's validator result passes through as-is,
	# and the catalog's _run_one_validator() checks its shape.
	var validate := func(record: FactionRuleData) -> Variant:
		if not registry.known_rule_classes().has(record.rule_class):
			return [{"severity": &"error", "field": "rule_class",
					"message": "rule_class %s is not registered." % record.rule_class}]
		return registry.validator_for(record.rule_class).call(record)
	catalog.register_record_validator(&"faction_rule", validate)
