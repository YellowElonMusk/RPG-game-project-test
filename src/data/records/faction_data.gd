## Content-catalog record: a human nation or alien civilization (Content Data
## GDD Rule 1, type `faction`, prefix `faction_`). Data only, no logic
## (Rule 4) — ContentCatalogService loads, validates and serves it.
##
## Usage example:
## [codeblock]
## var faction: FactionData = ContentCatalog.get_record(&"faction", "faction_tech_syndicate")
## print(faction.display_name, " ", faction.base_shape)
## [/codeblock]
class_name FactionData
extends Resource

## Permanent lowercase snake_case ID with the `faction_` prefix (Rule 2).
@export var id: String = ""
## Prior IDs this record still answers to; resolve one hop only (Rule 2).
@export var aliases: PackedStringArray = PackedStringArray()
## Player-visible faction name.
@export var display_name: String = ""
## `human_nation` or `alien`.
@export var kind: String = ""
## `organic` for nations; `square`, `circle`, `wedge` or `star` for aliens.
@export var base_shape: String = ""
## Hex colour (`#rrggbb`). Alien factions only.
@export var signature_color: String = ""
## Asset ID of the backup icon. Alien factions only.
@export var backup_icon_id: String = ""
## FactionRule record ID (`rule_` prefix). Alien factions only (ADR-0011).
@export var rule_id: String = ""
## Asset ID of the overworld patrol symbol. Alien factions only (ADR-0012).
@export var patrol_archetype_id: String = ""

## Player-visible text exports (TR-content-012, ADR-0013 §4).
const LOC_FIELDS: Array[StringName] = [&"display_name"]
## IDs, asset IDs, hex colours and enum-like strings (ADR-0013 §4).
const NON_LOC_FIELDS: Array[StringName] = [
	&"id", &"aliases", &"kind", &"base_shape", &"signature_color",
	&"backup_icon_id", &"rule_id", &"patrol_archetype_id",
]
