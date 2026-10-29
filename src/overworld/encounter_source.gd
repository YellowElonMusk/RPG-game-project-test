## The `source` of `OverworldMode.start_encounter(enc_id, source)` (ADR-0012
## §5 Key Interfaces): one encounter symbol on the map -- its `encounter`
## record ID (`enc_`) and its pure `SymbolBrain`. Data only.
class_name EncounterSource
extends RefCounted

## The `encounter` record this symbol starts (prefix `enc_`).
var enc_id: String = ""
## The symbol's AI; its `marker_index` is the marker order.
var brain: SymbolBrain = null
## The marker's symbol ID, the key `WorldState` resolves (story 043).
## Defaults to `enc_id` when the caller gives none.
var symbol_id: String = ""


func _init(p_enc_id: String, p_brain: SymbolBrain, p_symbol_id: String = "") -> void:
	enc_id = p_enc_id
	brain = p_brain
	symbol_id = p_symbol_id if not p_symbol_id.is_empty() else p_enc_id
