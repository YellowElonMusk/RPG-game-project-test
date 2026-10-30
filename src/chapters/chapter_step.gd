## One step of a chapter (ADR-0012 §8; GDD Overworld rules 0 and 19): the
## objective line and the critical-path leg it sends the player along, as
## `{map_id, leg_id}`, so the current leg is always known (the beacon and the
## objective line read it). Interim data until the Dialogue, Banter & Quests
## system owns quests.
class_name ChapterStep
extends Resource

## Unique within the chapter.
@export var id: String = ""
## The objective line shown for this step (plain text until LocText).
@export var objective: String = ""
## The `map_` record the leg is on.
@export var map_id: String = ""
## A `CriticalPathLeg.id` on that map.
@export var leg_id: String = ""
## Story flags set when the step begins (GDD rule 8: stages are raised on
## the faction's schedule, by step).
@export var flags_on_enter: PackedStringArray = PackedStringArray()
