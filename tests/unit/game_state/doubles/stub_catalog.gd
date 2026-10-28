## Scriptable catalog double (ADR-0002 §10: the machine reads `state` during
## Boot via duck typing — `_catalog` is typed `Object`, never
## `ContentCatalogService`, so Game State never hard-depends on Content Data).
class_name StubCatalog extends RefCounted

var state: ContentCatalogService.State = ContentCatalogService.State.UNLOADED
var has_record_result: bool = true


func has_record(_type: StringName, _id: String) -> bool:
	return has_record_result
