## Content-catalog record: a consumable, piece of equipment or key item
## (Content Data GDD Rule 1, type `item`, prefix `item_`; Vertical Slice).
## Data only, no logic (Rule 4).
##
## Usage example:
## [codeblock]
## var rec: ItemData = ContentCatalog.get_record(&"item", "item_expired_coupon")
## print(rec.kind, " costs ", rec.price)
## [/codeblock]
class_name ItemData
extends Resource

## Permanent lowercase snake_case ID with the `item_` prefix (Rule 2).
@export var id: String = ""
## Prior IDs this record still answers to (Rule 2).
@export var aliases: PackedStringArray = PackedStringArray()
## Player-visible name.
@export var display_name: String = ""
## Player-visible description.
@export var description: String = ""
## `consumable`, `equipment` or `key`.
@export var kind: String = ""
## EffectDescriptors `{type, ...params}`; the owning system interprets them.
@export var effects: Array[Dictionary] = []
## Shop price (Items, Equipment & Shops owns the range).
@export var price: int = 0

## Player-visible text exports (TR-content-012, ADR-0013 §4).
const LOC_FIELDS: Array[StringName] = [&"display_name", &"description"]
## IDs and enum-like strings (ADR-0013 §4).
const NON_LOC_FIELDS: Array[StringName] = [&"id", &"aliases", &"kind"]
