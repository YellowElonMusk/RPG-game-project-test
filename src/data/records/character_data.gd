## Content-catalog record: a recruitable squad misfit (Content Data GDD
## Rule 1, type `character`, prefix `char_`). The GDD's `stat_block` is
## flattened into the five scalar stat exports (ADR-0001: every scalar is
## its own typed export). Data only, no logic (Rule 4).
##
## Usage example:
## [codeblock]
## var rec: CharacterData = ContentCatalog.get_record(&"character", "char_baguette_thrower")
## var hero := Combatant.new(rec.display_name, rec.max_hp, rec.max_mp, rec.attack, rec.defense, rec.speed, false)
## [/codeblock]
class_name CharacterData
extends Resource

## Permanent lowercase snake_case ID with the `char_` prefix (Rule 2).
@export var id: String = ""
## Prior IDs this record still answers to (Rule 2).
@export var aliases: PackedStringArray = PackedStringArray()
## Player-visible name.
@export var display_name: String = ""
## Faction record ID of the character's home nation (`human_nation`).
@export var nation_id: String = ""
## One-sentence description of the prop/pose joke. Player-visible.
@export var archetype_line: String = ""
## Stat block (Stats & Damage F1 ranges own the meaning and bounds).
@export var max_hp: int = 0
@export var max_mp: int = 0
@export var attack: int = 0
@export var defense: int = 0
@export var speed: int = 0
## Move record IDs available from the start.
@export var move_ids: PackedStringArray = PackedStringArray()
## Move record ID unlocked by loyalty.
@export var signature_move_id: String = ""
## Asset ID of the sprite set.
@export var sprite_set_id: String = ""
## Asset ID of the portrait.
@export var portrait_id: String = ""

## Player-visible text exports (TR-content-012, ADR-0013 §4).
const LOC_FIELDS: Array[StringName] = [&"display_name", &"archetype_line"]
## IDs and asset IDs (ADR-0013 §4).
const NON_LOC_FIELDS: Array[StringName] = [
	&"id", &"aliases", &"nation_id", &"move_ids", &"signature_move_id",
	&"sprite_set_id", &"portrait_id",
]
## Required fields (story 015, QL-STORY-READY GAPS fix 2026-10-24): empty or
## whitespace-only text is an error. Widen only after a GDD edit marks more.
const REQUIRED_FIELDS: Array[StringName] = [&"display_name"]
