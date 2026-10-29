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
## The checkpoint this fight's Victory opens (GDD rule 10 `encounter`
## outcome, rule 13a story encounter); empty for an ordinary symbol.
var checkpoint_id: StringName = &""
## Where Fled places the leader (ground metres; rule 13a); `Vector2.ZERO`
## for none, when the leader stays put (rule 7).
var return_marker: Vector2 = Vector2.ZERO
## The leader's facing at `return_marker`.
var return_facing: Vector2 = Vector2.ZERO


func _init(p_enc_id: String, p_brain: SymbolBrain, p_symbol_id: String = "") -> void:
	enc_id = p_enc_id
	brain = p_brain
	symbol_id = p_symbol_id if not p_symbol_id.is_empty() else p_enc_id
