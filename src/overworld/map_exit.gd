## A `MapExit` marker on an `OverworldMap` scene (ADR-0012 §3 marker table;
## GDD rule 11 "Map exits"; story 138). Data only. When the leader's centre
## enters `trigger_rect` from outside, `OverworldMode` requests the
## `OVERWORLD -> OVERWORLD` map change to `target_map_id`'s
## `target_entry_id` EntryPoint (ADR-0012 §4).
##
## Deviation, flagged: the trigger rectangle is authored in ground metres
## relative to the map root (like `EncounterSymbol.patrol_path`), not
## derived from the marker's transform.
##
## Usage example (in a map scene):
## [codeblock]
## [node name="ExitToSegment" type="Marker3D" parent="."]
## script = ExtResource("map_exit")
## marker_id = &"exit_to_segment"
## target_map_id = "map_paris_segment_placeholder"
## target_entry_id = &"from_town"
## trigger_rect = Rect2(21, 4, 2, 2)
## [/codeblock]
class_name MapExit
extends Marker3D

## Unique within the map (ADR-0012 §3).
@export var marker_id: StringName = &""
## The `map_` record the exit leads to.
@export var target_map_id: String = ""
## The target map's `EntryPoint.marker_id` the party arrives at.
@export var target_entry_id: StringName = &""
## Trigger rectangle in ground metres, map-root relative.
@export var trigger_rect: Rect2 = Rect2()
## Story 068 (rule 13, walk home): while this story flag is set the exit is
## closed: its `closed_rect` cells are taped off ("FERMÉ POUR
## RESTRUCTURATION", no crowd) and it never fires. Empty = always open.
@export var closed_when_flag: String = ""
## The ground cells (metres) the tape blocks while closed.
@export var closed_rect: Rect2 = Rect2()

## The tape's sign text (rule 13).
const TAPE_TEXT: String = "FERMÉ POUR RESTRUCTURATION"
