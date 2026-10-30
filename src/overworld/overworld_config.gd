## Minimal stub: only `walk_speed`, the one field `GroundMover.step()` reads
## for story 001 (AC-1a). ADR-0012 §9 defines the full `OverworldConfig`
## (every GDD Tuning Knob except `dt_max`, plus `waypoint_tol_m`, and
## `validate()` checking invariants I1-I18) -- widen this file in place as
## later stories add the fields each invariant needs, rather than
## duplicating it (same precedent as `src/presentation/presentation_config.gd`).
class_name OverworldConfig
extends Resource

## The leader's full-tilt speed, in metres per second (GDD Tuning Knobs;
## safe range 3.0-4.0; default 3.5).
@export var walk_speed: float = 3.5

## Collision radius of the leader (and, later, of symbols), in metres (GDD
## Tuning Knobs; safe range 0.25-0.40; default 0.3; invariants I3, I7, I8, I9).
@export var body_radius: float = 0.3

## The largest corner overlap `GroundMover.step()`'s corner assist (ADR-0012
## §2.3) nudges the leader past instead of stopping it dead, in metres (GDD
## Tuning Knobs; safe range 0-0.4; default 0.25; invariant I9). 0 disables
## corner assist.
@export var corner_assist_m: float = 0.25

## Arc-length gap between neighbouring party members on the follower trail,
## in metres (GDD Formulas, `follower_trail`'s `follower_spacing_m`; GDD
## Tuning Knobs; safe range 0.7-1.1; default 0.9). `FollowerTrail.step()`
## places follower `i` at `(i + 1) * follower_spacing_m` behind the leader.
@export var follower_spacing_m: float = 0.9

## Distance between recorded follower-trail points, in metres (GDD
## Formulas, `follower_trail`'s `trail_sample_m`; GDD Tuning Knobs; safe
## range 0.05-0.25; default 0.15). Bounds how far a follower can cut a
## corner (`trail_sample_m / 2`) and how large the trail buffer grows
## (`FollowerTrail`'s `N_buf`).
@export var trail_sample_m: float = 0.15

## Patrol speed as a fraction of `walk_speed` (GDD Formulas, `chase_escape`'s
## `f_patrol`; GDD Tuning Knobs; safe range 0.4-0.7; default 0.6; invariant
## I1). `v_patrol()` turns it into metres per second.
@export var f_patrol: float = 0.6

## How close, in metres, a symbol following a path must come to a waypoint
## for it to count as reached (ADR-0012 §2: "A symbol following a path
## treats a waypoint as reached within `cfg.waypoint_tol_m`"). Not a GDD
## Tuning Knob -- ADR-0012 §9 adds it on top of the table and names no
## value; default 0.05 m (a sixth of the default `body_radius`).
@export var waypoint_tol_m: float = 0.05

## Front-half-plane notice radius, centre to centre, in metres (GDD rule 5
## notice test check 1; GDD Tuning Knobs; safe range 2.5-3.5; default 3.0;
## invariants I4, I7, I12, I14, I15).
@export var symbol_chase_m: float = 3.0

## Rear-half-plane notice radius, centre to centre, in metres (GDD rule 5
## notice test check 1; GDD Tuning Knobs; safe range 1.5-3.0, capped at
## `symbol_chase_m`; default 1.5; invariant I12).
@export var symbol_notice_rear_m: float = 1.5

## Longest route, in metres, the notice test's bounded uniform-cost search
## explores before giving up (GDD rule 5 notice test check 4; GDD Tuning
## Knobs; safe range 4.3-5.0; default 4.5; invariants I15, I16).
@export var notice_path_cap_m: float = 4.5

## How long, in seconds, the notice test stays off after a symbol rejoins
## Patrol from Returning (GDD rule 5 Returning row; GDD Tuning Knobs; safe
## range 2-5; default 3).
@export var renotice_cooldown_s: float = 3.0

## How long, in seconds, a symbol holds in Noticing before Chasing starts,
## whatever the leader does meanwhile (GDD rule 5 Noticing row; GDD Tuning
## Knobs; safe range 0.3-0.6; default 0.4; invariant I16).
@export var notice_delay_s: float = 0.4

## How long, in seconds, a patrolling symbol stands in its look-back pose at
## a `pingpong` end or a `loop` vertex turning by more than 90 degrees before
## its facing flips (GDD rule 5 Patrol row; GDD Tuning Knobs; safe range
## 0.9-1.4; default 0.9; invariant I17). 0 disables the pause.
@export var turn_pause_s: float = 0.9

## Chase speed as a fraction of `walk_speed` (GDD Formulas, `symbol_speeds`'s
## `f_chase`; GDD Tuning Knobs; safe range 0.7-0.85; default 0.8; invariants
## I1-I3). `v_chase()` turns it into metres per second.
@export var f_chase: float = 0.8

## Shortest gap, in seconds, between two chase repaths of one symbol (GDD
## rule 5 Chasing row; GDD Tuning Knobs; safe range 0.25-1.0; default 0.5).
@export var repath_s: float = 0.5

## Pathfinder queries (notice searches, chase repaths and Returning paths
## together) served per frame across all symbols (GDD rule 5 "Query budget";
## GDD Tuning Knobs; safe range 1-4; default 2).
@export var repath_per_frame_max: int = 2

## Path distance, in metres, past which a chase counts as "beyond" for the
## give-up test (GDD rule 5 "Give-up test"; GDD Tuning Knobs; safe range 6-8;
## default 6.5; invariants I2, I4, I5, I16).
@export var symbol_giveup_m: float = 6.5

## How long, in seconds, the give-up test must hold without a break before a
## chase ends (GDD rule 5 "Give-up test"; GDD Tuning Knobs; safe range
## 1.0-2.5; default 1.5; invariant I2).
@export var giveup_s: float = 1.5


## Seconds a non-Static symbol stays Stunned after a Fled battle, deaf and
## intangible (GDD rule 5 Stunned row; Tuning Knobs: safe range 2-4,
## default 3; invariants I5, I6).
@export var flee_grace_s: float = 3.0

## Maximum distance a Fled symbol is pushed back along the leader-to-symbol
## line, in metres (GDD Edge Cases, flee push; safe range 1-3; default 2).
@export var flee_push_m: float = 2.0

## Seconds of encounter grace started on `transition_finished` (GDD rule 7;
## safe range 1.5-3; default 2; invariants I3, I6).
@export var encounter_grace_s: float = 2.0


## `v_patrol = f_patrol * walk_speed`, in metres per second (GDD Formulas,
## `chase_escape`). The speed a Patrol (and Returning) symbol passes to
## `GroundMover.step()`.
func v_patrol() -> float:
	return f_patrol * walk_speed


## `v_chase = f_chase * walk_speed`, in metres per second (GDD Formulas,
## `symbol_speeds`). The speed a Chasing symbol passes to `GroundMover.step()`.
func v_chase() -> float:
	return f_chase * walk_speed


## Player reaction time assumed by the grace check, in seconds (GDD Tuning
## Knobs `t_react`, 0.4 s, range 0.3-0.6; I3, I17).
@export var t_react: float = 0.4
## Longest allowed worst-case escape, in seconds (`escape_max_s`, 10 s,
## range 8-12; I2).
@export var escape_max_s: float = 10.0
## Walk-grid cell size, in metres (`cell_m`, fixed 1.0 in MVP; I8, I11).
@export var cell_m: float = 1.0
## Beacon banner height, in metres (`beacon_h_m`, 3.5 m, range 3.0-4.5; I18).
@export var beacon_h_m: float = 3.5
## Tallest set wall, in metres (`wall_h_max`, 2.5 m, range 2.0-3.0; I18).
@export var wall_h_max: float = 2.5
## Symbol density bands, cells per symbol (`D_min` / `D_max`; I10): the
## overworld 150 / 250 (range 120-300), the dungeon 80 / 120 (range 60-150).
@export var d_min_overworld: int = 150
@export var d_max_overworld: int = 250
@export var d_min_dungeon: int = 80
@export var d_max_dungeon: int = 120

## `dt_max` is Presentation's knob; this default (the GDD's) stands in until
## `presentation_settings` is injected (see `OverworldMode`).
const DT_MAX_DEFAULT: float = 0.10


## `t_escape(d0) = max(0, symbol_giveup_m - d0) / (walk_speed - v_chase) +
## giveup_s` (GDD Formulas, `symbol_speeds`): open-ground time from a chase
## starting `d0` metres away until the symbol gives up. INF when the chase
## is as fast as the leader.
func t_escape(d0: float) -> float:
	var gap: float = walk_speed - v_chase()
	if gap <= 0.0:
		return INF
	return maxf(0.0, symbol_giveup_m - d0) / gap + giveup_s


## Invariants I1-I13 and I15-I18 (GDD Formulas, "Load-time invariants";
## story 098). Returns one message per failed invariant, each starting with
## its ID and naming the knobs involved; empty when all hold. `dt_max` is
## Presentation's (I11). `stage_records` are the `occupation_stage`
## records whose caps I13 checks per faction. I14 (`chase_visibility`)
## needs the camera and is `ChaseVisibility`'s (story 099).
func validate(dt_max: float = DT_MAX_DEFAULT, stage_records: Array = []) -> PackedStringArray:
	var out := PackedStringArray()
	if not (f_patrol < f_chase and f_chase <= 0.85):
		out.append("I1: f_patrol (%.2f) < f_chase (%.2f) <= 0.85 fails" % [f_patrol, f_chase])
	if not (t_escape(2.0 * body_radius) <= escape_max_s):
		out.append("I2: t_escape(2*body_radius) %.2f s > escape_max_s %.2f (walk_speed, f_chase, symbol_giveup_m, giveup_s)"
				% [t_escape(2.0 * body_radius), escape_max_s])
	if not ((encounter_grace_s - t_react) * (walk_speed - v_chase()) >= 2.0 * body_radius):
		out.append("I3: (encounter_grace_s - t_react) * (walk_speed - v_chase) < 2*body_radius")
	if not (symbol_giveup_m >= symbol_chase_m + 2.0):
		out.append("I4: symbol_giveup_m (%.2f) < symbol_chase_m + 2 (%.2f)" % [symbol_giveup_m, symbol_chase_m + 2.0])
	if not (flee_grace_s * walk_speed >= symbol_giveup_m):
		out.append("I5: flee_grace_s * walk_speed (%.2f) < symbol_giveup_m (%.2f)" % [flee_grace_s * walk_speed, symbol_giveup_m])
	if not (flee_grace_s >= encounter_grace_s):
		out.append("I6: flee_grace_s (%.2f) < encounter_grace_s (%.2f)" % [flee_grace_s, encounter_grace_s])
	if not (safe_radius_m > symbol_chase_m + 2.0 * body_radius):
		out.append("I7: safe_radius_m (%.2f) <= symbol_chase_m + 2*body_radius" % safe_radius_m)
	if not (body_radius < cell_m / 2.0):
		out.append("I8: body_radius (%.2f) >= cell_m / 2" % body_radius)
	if not (corner_assist_m <= body_radius + 0.1):
		out.append("I9: corner_assist_m (%.2f) > body_radius + 0.1" % corner_assist_m)
	if not (d_min_overworld <= d_max_overworld and d_min_dungeon <= d_max_dungeon):
		out.append("I10: D_min > D_max (overworld %d/%d, dungeon %d/%d)"
				% [d_min_overworld, d_max_overworld, d_min_dungeon, d_max_dungeon])
	if not (walk_speed * dt_max < cell_m):
		out.append("I11: walk_speed * dt_max (%.3f) >= cell_m (%.2f)" % [walk_speed * dt_max, cell_m])
	if not (0.5 * symbol_chase_m <= symbol_notice_rear_m and symbol_notice_rear_m <= symbol_chase_m):
		out.append("I12: symbol_notice_rear_m (%.2f) outside [0.5*symbol_chase_m, symbol_chase_m]" % symbol_notice_rear_m)
	var cap_errors: PackedStringArray = _cap_monotonic(stage_records)
	if not cap_errors.is_empty():
		out.append("I13: caps fall as the stage rises: " + ", ".join(cap_errors))
	if not (notice_path_cap_m >= symbol_chase_m * sqrt(2.0)):
		out.append("I15: notice_path_cap_m (%.2f) < symbol_chase_m * sqrt(2) (%.2f)"
				% [notice_path_cap_m, symbol_chase_m * sqrt(2.0)])
	if not (notice_path_cap_m + walk_speed * notice_delay_s <= symbol_giveup_m - 0.5):
		out.append("I16: notice_path_cap_m + walk_speed * notice_delay_s (%.2f) > symbol_giveup_m - 0.5"
				% (notice_path_cap_m + walk_speed * notice_delay_s))
	if not (turn_pause_s >= t_react + (symbol_chase_m - symbol_notice_rear_m) / walk_speed):
		out.append("I17: turn_pause_s (%.2f) < t_react + (symbol_chase_m - symbol_notice_rear_m) / walk_speed" % turn_pause_s)
	if not (beacon_h_m >= wall_h_max + 0.5):
		out.append("I18: beacon_h_m (%.2f) < wall_h_max + 0.5" % beacon_h_m)
	return out


## I13: per faction, every kind's cap at stage s+1 is at least its cap at s
## (a kind missing from the higher stage counts as 0).
static func _cap_monotonic(stage_records: Array) -> PackedStringArray:
	var out := PackedStringArray()
	var by_faction: Dictionary = {}
	for r: Variant in stage_records:
		var o: OccupationStageData = r as OccupationStageData
		if o == null:
			continue
		if not by_faction.has(o.faction_id):
			by_faction[o.faction_id] = {}
		(by_faction[o.faction_id] as Dictionary)[o.stage] = o
	for faction: String in by_faction:
		var stages: Dictionary = by_faction[faction]
		for s: int in [1, 2]:
			if not stages.has(s) or not stages.has(s + 1):
				continue
			var lo: OccupationStageData = stages[s]
			var hi: OccupationStageData = stages[s + 1]
			for kind: String in lo.clutter_caps:
				if int(hi.clutter_caps.get(kind, 0)) < lo.clutter_caps[kind]:
					out.append("%s %s stage %d->%d" % [faction, kind, s, s + 1])
	return out

## Minimum extra gap, in metres, between an EntryPoint and every MapExit
## rectangle beyond `body_radius` (GDD Tuning Knobs `entry_clearance_m`,
## 1.0 m, range 0.5-2.0; GDD rule 11; checked by `MapValidator`).
@export var entry_clearance_m: float = 1.0
## Directory holding the map scenes; a `map_<name>` record's scene is
## `<map_scene_dir>/<name>.tscn` (story 138; deviation from ADR-0012's
## `res://scenes/maps/<map_id>/<map_id>.tscn`, flagged).
@export var map_scene_dir: String = "res://data/maps"
## Followers snapped behind the leader on map entry (GDD rule 2: up to 3).
@export var max_followers: int = 3

## Safe-zone radius around every EntryPoint, MapExit rectangle and CampSpot,
## in metres (GDD rule 0, Tuning Knobs `safe_radius_m`, 4.5 m, range
## 4.0-6.0; must exceed `symbol_chase_m + 2 * body_radius`, I7). Cells whose
## nearest point lies within it are baked `SAFE`.
@export var safe_radius_m: float = 4.5
## The smaller safe disc around a checkpoint or story-encounter return
## marker, in metres (GDD rule 0, Tuning Knobs `return_safe_radius_m`,
## 1.5 m, range 1.0-2.0).
@export var return_safe_radius_m: float = 1.5
## How far from the probe point `confirm` reaches, in metres (GDD rule 3,
## Tuning Knobs `interact_reach_m`, 1.2 m, range 1.0-1.5).
@export var interact_reach_m: float = 1.2
## Longest walk-grid distance from the pre-dungeon CampSpot's safe-zone edge
## to the story encounter, in metres (GDD rule 13a, Tuning Knobs
## `story_sight_m`, 12 m, range 8-16; level review).
@export var story_sight_m: float = 12.0
## Whether the camp prompt's Yes requests the Camp mode (GDD States,
## CampPrompt). On since story 089 added the interim Camp mode; off, Yes
## only registers the camp and closes the prompt (for a build with no Camp
## mode scene).
@export var camp_mode_enabled: bool = true
## Dungeon pressure floor: the bypass lane must be at least this many times
## the unbanded shortest route (GDD rule 12, Tuning Knobs `bypass_ratio_min`,
## 1.2, range 1.1-1.5; story 085).
@export var bypass_ratio_min: float = 1.2
## How long a patrolling symbol is on screen before the leader can reach its
## notice radius, in seconds (GDD Formulas `chase_visibility`, Tuning Knobs
## `see_lead_s`, 0.25, range 0.2-0.3). Sets `see_m()`.
@export var see_lead_s: float = 0.25


## `see_m = symbol_chase_m + body_radius + (walk_speed + v_patrol) * see_lead_s`
## (GDD Formulas `chase_visibility`): the distance at which a patrolling
## symbol must already be on screen. 4.70 m at the defaults.
func see_m() -> float:
	return symbol_chase_m + body_radius + (walk_speed + v_patrol()) * see_lead_s
## The chapter step list `validate_maps` checks (ADR-0012 §8, interim data;
## story 074).
@export var chapter_steps_path: String = "res://data/chapters/chapter_paris_steps.tres"
## Timed text (GDD UI Requirements "Timed text"): every name card, payoff
## card and bark holds `text_hold(text) = max(name_card_s, text_hold_base_s
## + words * text_hold_per_word_s)`. Tuning Knobs: 2.0 s (1.5-3.0), 1.0 s
## (0.8-1.5), 0.3 s (0.25-0.4).
@export var name_card_s: float = 2.0
@export var text_hold_base_s: float = 1.0
@export var text_hold_per_word_s: float = 0.3
## The fade after a hold, in seconds (presentation; not a GDD knob).
@export var text_fade_s: float = 0.4


## `text_hold(text)` (GDD "Timed text"): the 9-word teaching bark holds 3.7 s.
func text_hold(text: String) -> float:
	var words: int = text.split(" ", false).size()
	return maxf(name_card_s, text_hold_base_s + float(words) * text_hold_per_word_s)
## How long an on-screen liberated marker's removal plays, from the reveal
## (GDD rule 9, Tuning Knobs `liberation_duration_s`, 1.0 s, range 0.6-1.5).
@export var liberation_duration_s: float = 1.0
