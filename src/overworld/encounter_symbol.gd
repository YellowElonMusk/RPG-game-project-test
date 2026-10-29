## An encounter symbol's placement marker on an `OverworldMap` scene
## (ADR-0012 §4-5; GDD rule 5; story 137). Data only: it names an
## `encounter` record by id (never an inline roster, ADR-0012 Alternative 4)
## and carries the symbol's patrol polyline in ground metres. No physics
## node is involved (ADR-0012 §2-3): `OverworldMode.load_map()` reads every
## marker, in child order, into one `SymbolBrain` each, and contact is the
## mode's swept circle test.
##
## Usage example (in a map scene):
## [codeblock]
## [node name="SymbolClerks" type="Marker3D" parent="."]
## script = ExtResource("encounter_symbol")
## encounter_id = "enc_paris_clerks_west"
## patrol_path = PackedVector2Array(4.5, 5.5, 10.5, 5.5)
## path_mode = 1
## [/codeblock]
class_name EncounterSymbol
extends Marker3D

## The `enc_` record this symbol starts (ADR-0012 §5 `start_encounter`).
@export var encounter_id: String = ""
## Persistent id for `WorldState` resolution; empty means `encounter_id`.
@export var symbol_id: String = ""
## Patrol polyline vertices in ground metres (x, z); the first vertex is the
## spawn point. At least one vertex is required.
@export var patrol_path: PackedVector2Array = PackedVector2Array()
## How the polyline continues past its last vertex (GDD rule 5).
@export var path_mode: SymbolBrain.PathMode = SymbolBrain.PathMode.PINGPONG


## `true` when the marker names a record and has a patrol path.
func is_valid_marker() -> bool:
	return encounter_id.begins_with("enc_") and not patrol_path.is_empty()
