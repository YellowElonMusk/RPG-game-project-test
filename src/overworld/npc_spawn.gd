## An `NpcSpawn` marker on an `OverworldMap` scene (ADR-0012 §3; GDD rule
## 3). Data only: a civilian who answers `confirm` with one line. Always
## eligible for `probe()`. The proximity bark (rule 16 `optional_teach`,
## P14) is story 123's.
##
## Usage example (in a map scene):
## [codeblock]
## [node name="NpcUnionMan" type="Marker3D" parent="."]
## script = ExtResource("npc_spawn")
## marker_id = &"npc_union_man"
## speaker = "Café regular"
## line = "They won't follow you past the café paving. Union rules."
## [/codeblock]
class_name NpcSpawn
extends Marker3D

## Unique within the map (ADR-0012 §3).
@export var marker_id: StringName = &""
## Who speaks; shown before the line.
@export var speaker: String = ""
## What `confirm` shows. Plain text until LocText exists.
@export_multiline var line: String = ""


## Ground position (`x`, `z`) relative to `map_root`.
func ground_position(map_root: Node) -> Vector2:
	return OverworldMap.ground_position_of(self, map_root)
