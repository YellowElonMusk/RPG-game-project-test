## Content-catalog record: one battle the overworld can start (ADR-0012 §3,
## type `encounter`, prefix `enc_`). `victory_payoff` is a descriptor
## dictionary the Game State owns (its rule 6). Data only, no logic (Rule 4).
##
## Usage example:
## [codeblock]
## var rec: EncounterData = ContentCatalog.get_record(&"encounter", "enc_checkpoint_ambush")
## for enemy_id in rec.enemy_ids:
##     spawn(ContentCatalog.get_record(&"enemy", enemy_id))
## [/codeblock]
class_name EncounterData
extends Resource

## Permanent lowercase snake_case ID with the `enc_` prefix (Rule 2).
@export var id: String = ""
## Prior IDs this record still answers to (Rule 2).
@export var aliases: PackedStringArray = PackedStringArray()
## Enemy record IDs in the fight.
@export var enemy_ids: PackedStringArray = PackedStringArray()
## Asset ID of the battle stage.
@export var battle_stage_id: String = ""
## Faction record ID of the enemies' faction.
@export var faction_id: String = ""
## True for a boss encounter.
@export var is_boss: bool = false
## True if the squad may flee.
@export var can_flee: bool = false
## True if Retreat is allowed after a loss.
@export var retreat_allowed: bool = false
## True if the encounter respawns after it is cleared.
@export var respawn: bool = false
## Victory payoff (GDD Overworld rule 7a; story 050), granted on the first
## Victory over a symbol only: `{"type": "clue" | "open" | "item" | "none",
## "facet": rumour / facet ID (clue), "text": the interim stub line (clue),
## "checkpoint": checkpoint marker ID on the same map (open), "item_id":
## item ID (item), "label": the name the payoff card shows (open, item)}`.
## Empty means none.
@export var victory_payoff: Dictionary = {}

## No player-visible text on this record (TR-content-012, ADR-0013 §4).
const LOC_FIELDS: Array[StringName] = []
## IDs and asset IDs (ADR-0013 §4).
const NON_LOC_FIELDS: Array[StringName] = [
	&"id", &"aliases", &"enemy_ids", &"battle_stage_id", &"faction_id",
]
## Required fields (story 015, QL-STORY-READY GAPS fix 2026-10-24): none yet.
## The GDD marks no field required on this type.
const REQUIRED_FIELDS: Array[StringName] = []
