## A checkpoint `Interactable` on an `OverworldMap` scene (ADR-0012 §3
## marker table; GDD rule 10). Data only. While closed it blocks the cells
## under `blocked_rect` (a route-blocker); opened, it frees them and stays
## open (`WorldState`). Its `return_marker` is where a redirect or a Fled
## story encounter places the leader, and a safe-zone source at
## `return_safe_radius_m` (GDD rule 0).
##
## Usage example (in a map scene):
## [codeblock]
## [node name="PermitBoom" type="Marker3D" parent="."]
## script = ExtResource("interactable_checkpoint")
## marker_id = &"cp_permit_boom"
## requirement_flag = "permit_to_approach"
## failure_outcome = 2
## linked_encounter_id = "enc_paris_permit_counter"
## blocked_rect = Rect2(10, 3, 1, 3)
## return_marker = Vector2(7.5, 4.5)
## [/codeblock]
class_name CheckpointMarker
extends Marker3D

## What `confirm` does when the requirement is not met (GDD rule 10).
enum FailureOutcome { REDIRECT, QUEUE, ENCOUNTER }

## Unique within the map (ADR-0012 §3).
@export var marker_id: StringName = &""
## The requirement: exactly one of an item ID or a story flag (GDD rule 10).
@export var requirement_item_id: String = ""
@export var requirement_flag: String = ""
## Where the requirement is obtained (GDD rule 0, "Requirement source").
@export var obtained_at: String = ""
@export var failure_outcome: FailureOutcome = FailureOutcome.REDIRECT
## The `enc_` record the `ENCOUNTER` outcome starts; winning it opens this
## checkpoint (GDD rule 10).
@export var linked_encounter_id: String = ""
## Ground cells (metres) blocked while closed.
@export var blocked_rect: Rect2 = Rect2()
## Ground position (metres) a redirect lands the leader on.
@export var return_marker: Vector2 = Vector2.ZERO
## Leader facing at the return marker: away from the checkpoint.
@export var return_facing: Vector2 = Vector2.DOWN


## Ground position (`x`, `z`) relative to `map_root`: the probe target.
func ground_position(map_root: Node) -> Vector2:
	return OverworldMap.ground_position_of(self, map_root)
