## An `EntryPoint` marker on an `OverworldMap` scene (ADR-0012 §3 marker
## table; GDD rule 11; story 138). Data only: where the party arrives on a
## map change and which way it faces. Its ground position is the `x`/`z` of
## its transform relative to the map root, composed from local transforms
## (never `global_*`: markers are read before the map enters the tree).
##
## Usage example:
## [codeblock]
## var entry: EntryPoint = map.find_entry_point(&"from_town")
## leader_pos = entry.ground_position(map)
## [/codeblock]
class_name EntryPoint
extends Marker3D

## Unique within the map (ADR-0012 §3).
@export var marker_id: StringName = &""
## Ground-plane facing on arrival; must face into the map (GDD rule 11).
@export var facing: Vector2 = Vector2.DOWN


## Ground position (`x`, `z`) relative to `map_root`, composed from the
## local transforms of this marker and its ancestors below `map_root`.
func ground_position(map_root: Node) -> Vector2:
	var xf: Transform3D = transform
	var node: Node = get_parent()
	while node != null and node != map_root and node is Node3D:
		xf = (node as Node3D).transform * xf
		node = node.get_parent()
	return Vector2(xf.origin.x, xf.origin.z)
