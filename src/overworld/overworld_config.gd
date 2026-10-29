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


## `v_patrol = f_patrol * walk_speed`, in metres per second (GDD Formulas,
## `chase_escape`). The speed a Patrol (and Returning) symbol passes to
## `GroundMover.step()`.
func v_patrol() -> float:
	return f_patrol * walk_speed


## Invariants I1-I18 (GDD Formulas, "Load-time invariants"). Returns one
## message per failed invariant, naming its ID -- empty when every checked
## invariant holds. Every invariant that reads `walk_speed` also reads a
## field this stub does not declare yet (I11 needs `dt_max`, which is
## Presentation's; I3 needs `v_chase`; etc.), so this returns `[]` until a
## later story adds those fields and their checks.
func validate() -> PackedStringArray:
	return PackedStringArray()
