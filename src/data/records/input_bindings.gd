## Content-catalog record: the default key and gamepad bindings (Content
## Data GDD Rule 1, type `bindings`, prefix `bindings_`; one record,
## `bindings_default`). Keeps the class name ADR-0003 gives it. Each entry
## of `bindings` is `{action, device, input}`; the Input System owns the
## meaning and registers InputBindingsValidator (ADR-0003 / ADR-0004).
## Data only, no logic (Rule 4).
##
## Usage example:
## [codeblock]
## var rec: InputBindings = ContentCatalog.get_record(&"bindings", "bindings_default")
## for entry in rec.bindings:
##     resolver.bind(entry["action"], entry["device"], entry["input"])
## [/codeblock]
class_name InputBindings
extends Resource

## Permanent lowercase snake_case ID with the `bindings_` prefix (Rule 2).
@export var id: String = ""
## Prior IDs this record still answers to (Rule 2).
@export var aliases: PackedStringArray = PackedStringArray()
## Binding entries `{action, device, input}`; the Input System interprets them.
@export var bindings: Array[Dictionary] = []

## No player-visible text on this record (TR-content-012, ADR-0013 §4).
const LOC_FIELDS: Array[StringName] = []
## IDs (ADR-0013 §4).
const NON_LOC_FIELDS: Array[StringName] = [&"id", &"aliases"]
## Required fields (story 015, QL-STORY-READY GAPS fix 2026-10-24): none yet.
## The GDD marks no field required on this type.
const REQUIRED_FIELDS: Array[StringName] = []
