## The `OVERWORLD -> OVERWORLD` map-change payload (ADR-0012 §4 entry-path
## table; story 138): the fresh `OverworldMode` loads `map_id`'s scene and
## places the party at `entry_marker_id`. `WorldState` survives the swap
## (GameRoot reuses it for this payload) and applies `on_map_reenter`.
class_name MapEntryPayload
extends RefCounted

## The target `map_` record ID.
var map_id: String = ""
## The target map's `EntryPoint.marker_id`.
var entry_marker_id: StringName = &""


func _init(p_map_id: String = "", p_entry_marker_id: StringName = &"") -> void:
	map_id = p_map_id
	entry_marker_id = p_entry_marker_id
