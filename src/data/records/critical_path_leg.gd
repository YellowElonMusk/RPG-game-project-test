## One leg of a map's critical path (GDD Overworld rule 0; ADR-0012 §3):
## from an EntryPoint to a MapExit, the story encounter or boss (a
## `symbol_id`) or a CampSpot (its `marker_id`). Data only, embedded in its
## `map_` record. ChapterFlow steps name `{map_id, leg_id}`.
##
## Usage example (in a `map_` record):
## [codeblock]
## [sub_resource type="Resource" id="leg_a"]
## script = ExtResource("leg")
## id = "seg_to_dungeon"
## from_entry = &"from_town"
## to = "exit_to_dungeon"
## [/codeblock]
class_name CriticalPathLeg
extends Resource

## Unique within the map.
@export var id: String = ""
## The EntryPoint `marker_id` the leg starts at.
@export var from_entry: StringName = &""
## Where it ends: a MapExit `marker_id`, a Static symbol's `symbol_id`, or
## a CampSpot `marker_id`.
@export var to: String = ""
