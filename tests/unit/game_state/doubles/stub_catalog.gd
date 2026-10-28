## Scriptable catalog double (ADR-0002 §10: the machine reads `state` during
## Boot via duck typing — `_catalog` is typed `Object`, never
## `ContentCatalogService`, so Game State never hard-depends on Content Data).
class_name StubCatalog extends RefCounted

var state: ContentCatalogService.State = ContentCatalogService.State.UNLOADED
## Default result for any (type, id) not overridden through `set_known()`.
var has_record_result: bool = true
## Per-(type, id) overrides (story 013): `StringName` type -> `{String id: bool}`.
## Lets a test say "the catalog knows every faction but not this one enemy"
## without disturbing every other test's single-flag usage of
## `has_record_result`.
var _known: Dictionary = {}


func has_record(type: StringName, id: String) -> bool:
	var by_id: Dictionary = _known.get(type, {})
	if by_id.has(id):
		return by_id[id]
	return has_record_result


## Marks one (type, id) pair known or unknown, overriding `has_record_result`
## for that pair only (story 013).
func set_known(type: StringName, id: String, known: bool) -> void:
	if not _known.has(type):
		_known[type] = {}
	_known[type][id] = known
