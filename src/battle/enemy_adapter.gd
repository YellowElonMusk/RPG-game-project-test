## Builds today's runtime enemy `Combatant` from an `EnemyData` record
## (content-migration story 024, merged with 025; ADR-0001 Migration Step 3;
## ADR-0011 §5). Copies the stat block into a new `Combatant` tagged with the
## record ID (identity only; the resolver never reads it) and never keeps the
## record. Shared with story 029.
##
## An unknown ID or a null record fails loudly (`push_error`, `null`); there
## is no fallback to the old factory constants.
##
## Usage example:
## [codeblock]
## var clerk: Combatant = EnemyAdapter.from_catalog(BattleCatalog.shipped(), "enemy_clerk")
## [/codeblock]
class_name EnemyAdapter
extends RefCounted


## A new enemy `Combatant` copied from `record`, or `null` with a `push_error`.
## `move_ids` is not copied: enemy moves come from the faction rule, and
## `Combatant.move_ids` stays empty for enemies (unchanged behaviour).
## Example: [code]var enemy := EnemyAdapter.from_record(record as EnemyData)[/code]
static func from_record(record: EnemyData) -> Combatant:
	if record == null:
		push_error("EnemyAdapter.from_record: null record.")
		return null
	return Combatant.new(record.display_name, record.max_hp, record.max_mp, record.attack,
			record.defense, record.speed, true, record.is_boss, record.id)


## Looks `id` up in `catalog` and adapts it. `null` with a `push_error` (and
## `catalog.last_lookup_error` set, e.g. `&"missing_id"`) when it fails.
## Example: [code]var boss := EnemyAdapter.from_catalog(catalog, "enemy_supervisor")[/code]
static func from_catalog(catalog: ContentCatalogService, id: String) -> Combatant:
	if catalog == null:
		push_error("EnemyAdapter.from_catalog(%s): no catalog." % id)
		return null
	var record: EnemyData = catalog.get_record(&"enemy", id) as EnemyData
	if record == null:
		push_error("EnemyAdapter.from_catalog(%s): lookup failed (%s)." % [id, catalog.last_lookup_error])
		return null
	return from_record(record)
