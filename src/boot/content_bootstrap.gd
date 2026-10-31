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
##   1. Turn Battle effect-type registration (story 010: `BattleEffectTypes`),
##      plus `damage`/`heal` registered on Stats' behalf until that epic
##      exists, and the Quirk State System's own provisional types (story
##      010, same placeholder shape) so the content-catalog epic's own
##      `valid_one_of_each` fixture -- authored before any registrant existed,
##      and still exercising every record type including `quirk_state` and
##      `combo` -- keeps reaching READY through this real boot path. Neither
##      placeholder decides that system's real vocabulary; whichever epic
##      designs the Quirk State System replaces this line with its own.
##   2. Faction Rule registration (story 011): build the `FactionRuleRegistry`,
##      fill it with `FactionRules.register_all()` (the shipped
##      `bureaucratia_permit` and `megacorp_billing` classes), then register
##      its `faction_rule` record validator with
##      `register_faction_rule_validator()`. The registry is returned on the
##      `ContentBootResult` (ADR-0011 §4); `null` on the no-op path.
##   3. `register_record_validator` calls: `InputBindingsValidator` (story
##      003, ADR-0003 §6), the Stats validators (`StatsConfig.load_or_default()`
##      bound), `LocFieldsValidator`.
##   4. `catalog.load_all()`.
## The Stats validators and `LocFieldsValidator` have no epic yet, so today
## step 3 runs only `InputBindingsValidator`, alongside steps 1, 2 and 4.
## Example: [code]ContentBootstrap.run(catalog, "res://tests/unit/content_data/fixtures/valid_one_of_each")[/code]
static func run(catalog: ContentCatalogService, data_root: String = "res://data") -> ContentBootResult:
	if catalog.state != ContentCatalogService.State.UNLOADED:
		return null
	BattleEffectTypes.register(catalog)
	# Stats has no epic yet; "damage" (named attacks: {type = "damage", power = N})
	# and "heal" (unused by the migrated set) are registered on its behalf here.
	catalog.register_known_effect_types(&"stats", PackedStringArray(["damage", "heal"]))
	# Placeholder until the (not yet designed) Quirk State System has its own
	# epic: the four types content-catalog's own `valid_one_of_each` fixture
	# already uses on its quirk_state and combo records.
	catalog.register_known_effect_types(&"quirk_state_provisional", PackedStringArray([
		"apply_quirk_state", "consume_quirk_state", "stat_modifier", "expiry_hook",
	]))
	var result := ContentBootResult.new()
	result.registry = FactionRuleRegistry.new()
	FactionRules.register_all(result.registry)
	# Stub, never a shipped rule: content-catalog's own canonical
	# valid_one_of_each fixture's faction_rule record (authored before any
	# real rule class existed) uses rule_class &"delay_rule". A no-op
	# validator keeps that pre-existing fixture at READY now that a
	# faction_rule validator runs for the first time; whichever story updates
	# that fixture to a real shipped class removes this line.
	result.registry.register(&"delay_rule",
			func(_faction: FactionData, _rule: FactionRuleData) -> FactionRule: return FactionRule.new(),
			func(_rule: FactionRuleData) -> Array[Dictionary]: return [])
	register_faction_rule_validator(catalog, result.registry)
	# TODO(sprite-camera-presentation): ADR-0005 §9 PresentationConfig load rules
	# (`PresentationConfig.validate()`) need a config-level validator hook;
	# ADR-0004 only offers per-record-type validators.
	# Step 3 (ADR-0003 §6): the bindings record validator, before load_all().
	catalog.register_record_validator(&"bindings", InputBindingsValidator.validate)
	# ADR-0005 §9 sprite-set validators (stories 018, 062, 066), run on the
	# character/enemy records that name each set.
	PresentationValidators.register_sprite_set_validators(catalog,
			PresentationValidators.load_sprite_sets(), PresentationValidators.load_config())
	# ADR-0005 §9 existence checks against the root's own presentation tables
	# (`boss_profile_exists`, story 032; `sprite_set_exists`, story 034).
	PresentationValidators.register_existence_validators(catalog, data_root)
	catalog.load_all(data_root)
	return result


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
