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


## Invariants I1-I18 (GDD Formulas, "Load-time invariants"). Returns one
## message per failed invariant, naming its ID -- empty when every checked
## invariant holds. Every invariant that reads `walk_speed` also reads a
## field this stub does not declare yet (I11 needs `dt_max`, which is
## Presentation's; I3 needs `v_chase`; etc.), so this returns `[]` until a
## later story adds those fields and their checks.
func validate() -> PackedStringArray:
	return PackedStringArray()

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
