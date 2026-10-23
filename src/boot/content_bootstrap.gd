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
##   2. Faction Rule registration (`FactionRules.register_all()`, story 017).
##   3. `register_record_validator` calls: `InputBindingsValidator`, the Stats
##      validators (`StatsConfig.load_or_default()` bound), `LocFieldsValidator`.
##   4. `catalog.load_all()`.
## None of those registrants exists yet, so today only step 4 runs.
## Example: [code]ContentBootstrap.run(catalog, "res://tests/unit/content_data/fixtures/valid_one_of_each")[/code]
static func run(catalog: ContentCatalogService, data_root: String = "res://data") -> void:
	if catalog.state != ContentCatalogService.State.UNLOADED:
		return
	catalog.load_all(data_root)
