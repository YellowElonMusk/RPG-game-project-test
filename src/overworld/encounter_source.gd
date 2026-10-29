## The `source` of `OverworldMode.start_encounter(enc_id, source)` (ADR-0012
## §5 Key Interfaces): one encounter symbol on the map -- its `encounter`
## record ID (`enc_`) and its pure `SymbolBrain`. Data only.
class_name EncounterSource
extends RefCounted

## The `encounter` record this symbol starts (prefix `enc_`).
var enc_id: String = ""
## The symbol's AI; its `marker_index` is the marker order.
var brain: SymbolBrain = null


func _init(p_enc_id: String, p_brain: SymbolBrain) -> void:
	enc_id = p_enc_id
	brain = p_brain
