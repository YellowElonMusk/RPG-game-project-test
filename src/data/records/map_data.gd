## Content-catalog record: an overworld map (ADR-0012 §3, type `map`,
## prefix `map_`). The scene path is derived from the ID
## (`res://scenes/maps/<map_id>/<map_id>.tscn`), never stored. Data only,
## no logic (Rule 4).
##
## Usage example:
## [codeblock]
## var rec: MapData = ContentCatalog.get_record(&"map", "map_outskirts")
## var stage: int = rec.stage_table.get(flag, rec.base_stage)
## [/codeblock]
class_name MapData
extends Resource

## Permanent lowercase snake_case ID with the `map_` prefix (Rule 2).
@export var id: String = ""
## Prior IDs this record still answers to (Rule 2).
@export var aliases: PackedStringArray = PackedStringArray()
## Player-visible map name.
@export var display_name: String = ""
## Faction record ID of the occupier. Optional.
@export var faction_id: String = ""
## Occupation stage when no `stage_table` flag is set (1–3).
@export var base_stage: int = 1
## Story flag name → occupation stage (1–3).
@export var stage_table: Dictionary[String, int] = {}
## The critical path's legs, in order (GDD rule 0; story 074).
@export var critical_path: Array[CriticalPathLeg] = []
## Story flag that marks the region liberated.
@export var region_liberation_flag: String = ""
## Asset ID of the lighting profile once liberated.
@export var liberated_profile_id: String = ""
## Asset ID of the set kit once liberated.
@export var liberated_kit_id: String = ""
## Encounter record IDs this map can start.
@export var encounter_zone_ids: PackedStringArray = PackedStringArray()
## Zone encounter rate, 0–1 (the Overworld owns the range).
@export var zone_rate: float = 0.0
## True on the one map a new game starts in.
@export var new_game_entry: bool = false

## Player-visible text exports (TR-content-012, ADR-0013 §4).
const LOC_FIELDS: Array[StringName] = [&"display_name"]
## IDs, asset IDs and flag names (ADR-0013 §4).
const NON_LOC_FIELDS: Array[StringName] = [
	&"id", &"aliases", &"faction_id", &"critical_path", &"region_liberation_flag",
	&"liberated_profile_id", &"liberated_kit_id", &"encounter_zone_ids",
]
## Required fields (story 015, QL-STORY-READY GAPS fix 2026-10-24): empty or
## whitespace-only text is an error. Widen only after a GDD edit marks more.
const REQUIRED_FIELDS: Array[StringName] = [&"display_name"]
