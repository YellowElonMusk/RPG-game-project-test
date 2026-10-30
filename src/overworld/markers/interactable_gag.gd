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
## Optional (rule 16; story 118): a squad member's remark on this gag, as a
## recruit-remark ID. Recruit remarks are undesigned (Squad Roster), so the
## reference is carried but not resolved yet; a gag validates either way.
@export var recruit_remark: String = ""
## Rule 16 marker tag: the faction's first-encounter rule clue.
@export var faction_clue: bool = false


## Ground position (`x`, `z`) relative to `map_root`.
func ground_position(map_root: Node) -> Vector2:
	return OverworldMap.ground_position_of(self, map_root)

## Decree gag (GDD rule 8, story 056): the in-world announcement of a stage
## raise. Active at and above this occupation stage; 0 = not a decree.
## A decree is exempt from stage caps and from the "no clutter in a safe
## zone" rule, never blocks, always answers `confirm` with its text, and is
## inactive once its map's `region_liberation_flag` is set.
@export var decree_stage: int = 0
## Decree gag triggered on first sight of this symbol instead (rule 13a: the
## camp decree announcing the story encounter); raises no stage.
@export var decree_first_sight: String = ""


## `true` for a decree gag (either trigger).
func is_decree() -> bool:
	return decree_stage > 0 or not decree_first_sight.is_empty()


## Story 058 (`marker_activation`): the clutter kind this marker counts
## against ("poster", "queue", ...), capped per faction x stage by the
## `occupation_stage` record; empty for an uncapped gag. `min_stage` is the
## lowest stage at which it is a candidate (1-3).
@export var clutter_kind: String = ""
@export var min_stage: int = 1
## Story 066 (rule 13): set only on liberated-set content, shown only once
## the region is liberated: `mairie_queue`, `grumbler` or `had_a_point` (the
## "Bureaucratia had a point" item). Empty for ordinary content.
@export var liberated_role: String = ""
## Story 063 (rule 9): this liberation reaction ribs the squad (AC-51 checks
## the line really does). Each last-act map needs at least one.
@export var ribs_squad: bool = false

## Rule 9 local liberation: the `symbol_id` whose first Victory liberates
## this clutter marker (a poster comes down, a queue breaks up), and/or a
## story flag that does. Liberated markers drop out of `probe()` for good.
@export var liberate_symbol: String = ""
@export var liberation_flag: String = ""
## Ground cells (metres) a queue blocks until it is liberated; empty for a
## poster.
@export var blocked_rect: Rect2 = Rect2()
## The street name a liberation card line shows ("Street cleared: ...").
@export var street_label: String = ""


## `true` for a clutter marker some Victory or flag can liberate.
func is_liberatable() -> bool:
	return not liberate_symbol.is_empty() or not liberation_flag.is_empty()
