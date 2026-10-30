## A `JunctionNode` marker on an `OverworldMap` scene (GDD Overworld rule 19
## "Junctions"; ADR-0012 §3 marker table; story 110). Data only: an authored
## choice point on one critical-path leg. The leg's start EntryPoint is its
## implicit first junction node (never authored twice); `BeaconJunctions`
## checks that the authored nodes cover one node per room the leg crosses
## and every branch cell of its `L_crit` path at every reachable stage. The
## level-review walk-in (story 109) places the leader at each one.
##
## Usage example (in a map scene):
## [codeblock]
## [node name="JunctionHallFork" type="Marker3D" parent="."]
## transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12.5, 0, 8.5)
## script = ExtResource("junction_node")
## marker_id = &"jn_hall_fork"
## leg_id = "dungeon_to_boss"
## [/codeblock]
class_name JunctionNode
extends Marker3D

## Unique within the map (ADR-0012 §3).
@export var marker_id: StringName = &""
## The `CriticalPathLeg.id` (on this map's `map_` record) the node belongs to.
@export var leg_id: String = ""


## Ground position (`x`, `z`) relative to `map_root` (see
## `OverworldMap.ground_position_of`).
func ground_position(map_root: Node) -> Vector2:
	return OverworldMap.ground_position_of(self, map_root)
