## A gag `Interactable` on an `OverworldMap` scene (GDD rule 16; ADR-0012
## §3). On `confirm` it gives one data-chosen response:
## - `LINE`: the joke as a Dialogue line; it stays eligible and repeats
##   (its `alt_text` from the second time, if it has one);
## - `CHANGE`: the line, then a small state change (a notice torn down),
##   saved; it then drops out of `probe()` (rule 3);
## - `CLUE`: the line plus a Codex rumour, added once ever; it stays
##   eligible and repeats.
## Text is plain until LocText exists (rule 16: shown verbatim).
##
## Usage example (in a map scene):
## [codeblock]
## [node name="PermitPoster" type="Marker3D" parent="."]
## script = ExtResource("interactable_gag")
## marker_id = &"gag_permit_poster"
## response = 2
## text = "SPECIAL MOVES REQUIRE A PERMIT."
## rumour_id = "rumour_permit_ban"
## faction_clue = true
## [/codeblock]
class_name GagInteractable
extends Marker3D

enum Response { LINE, CHANGE, CLUE }

## Unique within the map (ADR-0012 §3).
@export var marker_id: StringName = &""
@export var response: Response = Response.LINE
## The line `confirm` shows.
@export_multiline var text: String = ""
## `LINE` only: the shorter line from the second time on; empty repeats
## `text`.
@export_multiline var alt_text: String = ""
## `CLUE` only: the Codex rumour it adds, once.
@export var rumour_id: String = ""
## Rule 16 marker tag: the faction's first-encounter rule clue.
@export var faction_clue: bool = false


## Ground position (`x`, `z`) relative to `map_root`.
func ground_position(map_root: Node) -> Vector2:
	return OverworldMap.ground_position_of(self, map_root)
