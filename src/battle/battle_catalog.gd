## Interim access to the shipped content catalog for the battle factories
## (content-migration stories 023/024/028; ADR-0001's autoload exception:
## parameterless static factories cannot take an injected catalog). Story 026
## moves the rules' lookups into `_configure()` and stories 029/034 give
## `BattleFactory` an injected catalog, after which this accessor goes away.
##
## Never boots the catalog: production code that runs before
## `ContentBootstrap.run()` gets a non-READY catalog, and every lookup through
## it fails loudly (`push_error`, `null`). Only harness scenes and tests boot.
##
## Usage example:
## [codeblock]
## var clerk: Combatant = EnemyAdapter.from_catalog(BattleCatalog.shipped(), "enemy_clerk")
## [/codeblock]
class_name BattleCatalog
extends RefCounted


## The `ContentCatalog` autoload, read through the scene tree (the autoload
## identifier does not compile under `-s` scripts).
## Example: [code]var catalog := BattleCatalog.shipped()[/code]
static func shipped() -> ContentCatalogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node(^"ContentCatalog") as ContentCatalogService
