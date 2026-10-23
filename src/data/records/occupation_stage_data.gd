## Content-catalog record: presentation and density parameters for one
## faction × occupation stage (ADR-0012 §3, type `occupation_stage`, prefix
## `ostage_`). Cross-record invariants (caps non-decreasing with stage) are
## the Overworld's own validators. Data only, no logic (Rule 4).
##
## Usage example:
## [codeblock]
## var rec: OccupationStageData = ContentCatalog.get_record(&"occupation_stage", "ostage_outskirts_stage1")
## name_card.subtitle = rec.name_card_subtitle
## [/codeblock]
class_name OccupationStageData
extends Resource

## Permanent lowercase snake_case ID with the `ostage_` prefix (Rule 2).
@export var id: String = ""
## Prior IDs this record still answers to (Rule 2).
@export var aliases: PackedStringArray = PackedStringArray()
## Faction record ID of the occupier.
@export var faction_id: String = ""
## Occupation stage, 1–3.
@export var stage: int = 1
## Clutter kind → cap (non-decreasing in stage; the Overworld checks it).
@export var clutter_caps: Dictionary[String, int] = {}
## Civilian density, 0–1.
@export var civilian_density: float = 0.0
## Civilian archetype asset IDs to draw from.
@export var civilian_pool: PackedStringArray = PackedStringArray()
## Asset ID of the lighting profile.
@export var lighting_profile_id: String = ""
## Asset ID of the set kit.
@export var set_kit_id: String = ""
## Asset ID of the ambience bed.
@export var ambience_bed_id: String = ""
## Player-visible name-card subtitle.
@export var name_card_subtitle: String = ""
## Minimum liberation grumble, 0.1–0.4 (Overworld Tuning Knobs).
@export var liberation_grumble_min: float = 0.1
## Story flag → decree gag asset ID.
@export var decree_gag_by_flag: Dictionary[String, String] = {}

## Player-visible text exports (TR-content-012, ADR-0013 §4).
const LOC_FIELDS: Array[StringName] = [&"name_card_subtitle"]
## IDs and asset IDs (ADR-0013 §4).
const NON_LOC_FIELDS: Array[StringName] = [
	&"id", &"aliases", &"faction_id", &"civilian_pool", &"lighting_profile_id",
	&"set_kit_id", &"ambience_bed_id",
]
