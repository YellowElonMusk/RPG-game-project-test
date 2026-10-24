## Story 015 test-only record script: declares an Object/Resource-typed
## export, which ContentCatalogService rejects (ADR-0001 Implementation
## Guidelines). Deliberately has no `class_name`, like spy_content_catalog.gd.
## Its fixture sits in an existing type's folder (`moves/`) with a `move_` id,
## so no TYPE_TABLE entry is needed.
##
## Usage example:
## [codeblock]
## catalog.load_all("res://tests/unit/content_data/fixtures/structure_defects/object_export")
## # one error entry, field == &"bad_field"
## [/codeblock]
extends Resource

## Record id with the `move_` prefix, so the id checks pass.
@export var id: String = ""
## Prior ids; always empty here.
@export var aliases: PackedStringArray = PackedStringArray()
## The offending Object-typed export.
@export var bad_field: Resource = null
