## A `CampSpot` marker on an `OverworldMap` scene (ADR-0012 §3 marker table;
## GDD rules 0, 11, 13a). Data only: where the squad can rest, and a
## safe-zone source (`safe_radius_m`). Entering its safe zone registers it as
## the last camp (`GameStateMachine.register_camp()`); `confirm` at it opens
## the "Rest here?" camp prompt (story 113).
##
## Usage example (in a map scene):
## [codeblock]
## [node name="CampCafe" type="Marker3D" parent="."]
## script = ExtResource("camp_spot")
## marker_id = &"camp_cafe"
## camp_id = "camp_paris_cafe"
## return_entry_id = &"from_segment"
## is_region_default = true
## [/codeblock]
class_name CampSpot
extends Marker3D

## Unique within the map (ADR-0012 §3).
@export var marker_id: StringName = &""
## The camp's ID, recorded as `last_camp_id` (ADR-0002 §11).
@export var camp_id: String = ""
## The EntryPoint on this map the party returns to after resting here.
@export var return_entry_id: StringName = &""
## The region's default camp, the Retreat target before any other camp is
## registered (GDD rule 11: the Town café).
@export var is_region_default: bool = false


## Ground position (`x`, `z`) relative to `map_root` (see
## `OverworldMap.ground_position_of()`).
func ground_position(map_root: Node) -> Vector2:
	return OverworldMap.ground_position_of(self, map_root)
