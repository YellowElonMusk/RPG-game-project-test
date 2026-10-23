## Content-catalog record: a named payoff of cashing quirk states (Content
## Data GDD Rule 1, type `combo`, prefix `combo_`). Data only, no logic
## (Rule 4); Combo System & Codex owns the matching rules.
##
## Usage example:
## [codeblock]
## var rec: ComboData = ContentCatalog.get_record(&"combo", "combo_overdue_notice")
## title_card.text = rec.display_name
## [/codeblock]
class_name ComboData
extends Resource

## Permanent lowercase snake_case ID with the `combo_` prefix (Rule 2).
@export var id: String = ""
## Prior IDs this record still answers to (Rule 2).
@export var aliases: PackedStringArray = PackedStringArray()
## Title-card text. Player-visible.
@export var display_name: String = ""
## QuirkState record IDs that must all be present.
@export var required_state_ids: PackedStringArray = PackedStringArray()
## Character record IDs that must be in the squad; empty means any.
@export var required_character_ids: PackedStringArray = PackedStringArray()
## EffectDescriptors `{type, ...params}`; the owning system interprets them.
@export var effects: Array[Dictionary] = []
## Player-visible punchline.
@export var punchline_text: String = ""
## Asset ID of the combo animation.
@export var animation_id: String = ""
## Player-visible Codex entry.
@export var codex_text: String = ""

## Player-visible text exports (TR-content-012, ADR-0013 §4).
const LOC_FIELDS: Array[StringName] = [&"display_name", &"punchline_text", &"codex_text"]
## IDs and asset IDs (ADR-0013 §4).
const NON_LOC_FIELDS: Array[StringName] = [
	&"id", &"aliases", &"required_state_ids", &"required_character_ids", &"animation_id",
]
