## Content-catalog record: a command a combatant can use (Content Data GDD
## Rule 1, type `move`, prefix `move_`). `effects` is a list of
## EffectDescriptors `{type, ...params}` stored as plain dictionaries; the
## catalog never interprets them (Rule 4). Data only, no logic.
##
## Usage example:
## [codeblock]
## var rec: MoveData = ContentCatalog.get_record(&"move", "move_notarize_strike")
## for effect in rec.effects:
##     print(effect["type"])
## [/codeblock]
class_name MoveData
extends Resource

## Permanent lowercase snake_case ID with the `move_` prefix (Rule 2).
@export var id: String = ""
## Prior IDs this record still answers to (Rule 2).
@export var aliases: PackedStringArray = PackedStringArray()
## Player-visible name.
@export var display_name: String = ""
## Who the move may target: `self`, `single_enemy` or `single_ally` (Turn Battle owns it).
@export var target_type: String = ""
## MP cost, a non-negative integer (Stats & Damage owns the range).
@export var cost: int = 0
## EffectDescriptors `{type, ...params}`; the owning system interprets them.
@export var effects: Array[Dictionary] = []
## Asset ID of the move's animation.
@export var animation_id: String = ""
## Player-visible flavour line.
@export var flavor_text: String = ""

## Player-visible text exports (TR-content-012, ADR-0013 §4).
const LOC_FIELDS: Array[StringName] = [&"display_name", &"flavor_text"]
## IDs, asset IDs and enum-like strings (ADR-0013 §4).
const NON_LOC_FIELDS: Array[StringName] = [&"id", &"aliases", &"target_type", &"animation_id"]
## Required fields (story 015, QL-STORY-READY GAPS fix 2026-10-24): empty or
## whitespace-only text is an error. Widen only after a GDD edit marks more.
const REQUIRED_FIELDS: Array[StringName] = [&"display_name"]
