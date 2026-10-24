## Content-catalog record: a comedic status applied to a target (Content
## Data GDD Rule 1, type `quirk_state`, prefix `quirk_`). `effects` is
## provisional until the Quirk State System GDD is approved (Rule 5). Data
## only, no logic (Rule 4).
##
## Usage example:
## [codeblock]
## var rec: QuirkStateData = ContentCatalog.get_record(&"quirk_state", "quirk_complained")
## tooltip.text = rec.rule_text
## [/codeblock]
class_name QuirkStateData
extends Resource

## Permanent lowercase snake_case ID with the `quirk_` prefix (Rule 2).
@export var id: String = ""
## Prior IDs this record still answers to (Rule 2).
@export var aliases: PackedStringArray = PackedStringArray()
## Player-visible name.
@export var display_name: String = ""
## Asset ID of the status icon.
@export var icon_id: String = ""
## Player-visible description.
@export var description: String = ""
## Player-visible rule text.
@export var rule_text: String = ""
## EffectDescriptors `{type, ...params}`; the Quirk State System interprets them.
@export var effects: Array[Dictionary] = []

## Player-visible text exports (TR-content-012, ADR-0013 §4).
const LOC_FIELDS: Array[StringName] = [&"display_name", &"description", &"rule_text"]
## IDs and asset IDs (ADR-0013 §4).
const NON_LOC_FIELDS: Array[StringName] = [&"id", &"aliases", &"icon_id"]
## Required fields (story 015, QL-STORY-READY GAPS fix 2026-10-24): empty or
## whitespace-only text is an error. Widen only after a GDD edit marks more.
const REQUIRED_FIELDS: Array[StringName] = [&"display_name"]
