## A `WaypointBeacon` marker on an `OverworldMap` scene (GDD Overworld rule
## 19 "Diegetic beacon chain"; ADR-0012 §3 marker table; story 110). Data
## only: one lantern banner (at `OverworldConfig.beacon_h_m`, I18) in one
## leg's chain. A leg's chain is its beacons sorted by `order`; the last one
## stands on the leg's end (an exit, the story encounter, the boss or the
## café camp). Story 112 lights the current leg's chain; the others are
## unlit set dressing.
##
## Usage example (in a map scene):
## [codeblock]
## [node name="BeaconDungeonExit" type="Marker3D" parent="."]
## transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 22, 0, 1.5)
## script = ExtResource("waypoint_beacon")
## marker_id = &"bc_to_dungeon_2"
## leg_id = "segment_to_dungeon"
## order = 2
## [/codeblock]
class_name WaypointBeacon
extends Marker3D

## Unique within the map (ADR-0012 §3).
@export var marker_id: StringName = &""
## The `CriticalPathLeg.id` (on this map's `map_` record) whose chain this
## beacon is in.
@export var leg_id: String = ""
## Position in the leg's chain, ascending from the start; unique per leg.
@export var order: int = 0

## Story 112: `true` while this beacon is in the current leg's chain (set
## only by `OverworldMode` through `BeaconGuide.apply_lit()`). The view reads
## it, or `lit_changed`, to show the lit or unlit banner (ADR-0005 owns the
## look). TODO(ui): the lit/unlit banner swap in the drawn set.
var lit: bool = false:
	set(value):
		if lit == value:
			return
		lit = value
		lit_changed.emit(value)

## Emitted when `lit` changes.
signal lit_changed(is_lit: bool)


## Ground position (`x`, `z`) relative to `map_root` (see
## `OverworldMap.ground_position_of`).
func ground_position(map_root: Node) -> Vector2:
	return OverworldMap.ground_position_of(self, map_root)
