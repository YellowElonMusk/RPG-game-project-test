## Pure per-symbol AI (ADR-0012 §5 Key Interfaces; GDD
## `design/gdd/overworld-exploration-encounters.md` rule 5). One instance per
## `EncounterSymbol`; owns the symbol's ground-plane position and its
## sub-state, and moves only through `GroundMover.step()` with the symbol
## mask (walls + runtime-blocked + `SAFE`).
##
## Story 020 implements the **Patrol** sub-state only: walk the marker's
## patrol polyline at `cfg.v_patrol()`, closing a `LOOP` path's last vertex
## back to the first, or reversing at each end of a `PINGPONG` path.
## TODO(overworld): Noticing, Chasing, Returning, Stunned and Static, the
## turn pause and facing hysteresis (stories 021-027), and the ADR's full
## `step(dt, leader, leader_safe, grid, budget, grace, cfg)` signature, which
## those stories widen this one to once `QueryBudget` exists.
class_name SymbolBrain
extends RefCounted

## GDD rule 5 sub-states. Only `PATROL` has behaviour yet.
## TODO(overworld): NOTICING/CHASING/RETURNING/STUNNED/STATIC behaviour lands
## in stories 021-027; `step()` holds still in any of them until then.
enum SubState { PATROL, NOTICING, CHASING, RETURNING, STUNNED, STATIC }

## How a patrol polyline continues past its last vertex (GDD rule 5: "a
## polyline marked `loop` (closed: last vertex back to first) or `pingpong`
## (walks back the way it came)").
enum PathMode { LOOP, PINGPONG }

## Current sub-state. Starts in `PATROL` (GDD edge cases: symbols start at
## their patrol origins in Patrol).
var sub_state: SubState = SubState.PATROL

## Ground-plane position, in metres. Starts at the patrol origin (vertex 0).
var position: Vector2 = Vector2.ZERO

## Last non-zero movement direction, normalized. TODO(overworld): story 026
## replaces this raw direction with the displayed-facing snap, hysteresis
## and turn-pause flip timing.
var facing: Vector2 = Vector2.RIGHT

## Distance actually covered by the most recent `step()`, in metres (sum of
## every `GroundMover.MoveResult.distance_moved` inside it).
var last_distance_moved: float = 0.0

var _path: PackedVector2Array
var _mode: PathMode
## Index of the vertex currently being walked toward.
var _next: int = 0
## +1 walking toward higher indices, -1 walking back (PINGPONG only).
var _dir: int = 1


## `path` is the marker's patrol polyline in ground-plane metres; `mode`
## says how it continues past its last vertex. A path with fewer than two
## vertices is a stationary patrol: `step()` holds the symbol at vertex 0
## (or `Vector2.ZERO` for an empty path).
func _init(path: PackedVector2Array, mode: PathMode) -> void:
	_path = path
	_mode = mode
	if _path.size() > 0:
		position = _path[0]
	_next = 1 if _path.size() > 1 else 0
	if _path.size() > 1:
		var first_leg: Vector2 = _path[1] - _path[0]
		if first_leg != Vector2.ZERO:
			facing = first_leg.normalized()


## Index of the patrol vertex the symbol is currently walking toward.
func next_index() -> int:
	return _next


## +1 while walking toward higher vertex indices, -1 while walking back
## along a `PINGPONG` path. Always +1 on a `LOOP` path.
func direction() -> int:
	return _dir


## Advances the brain by `dt` seconds (the overworld's `ow_dt`, ADR-0012
## §2). In `PATROL` the symbol covers `cfg.v_patrol() * dt` metres of path
## arc length: whatever budget remains after reaching a waypoint (within
## `cfg.waypoint_tol_m`) carries onto the next segment in the same step, so
## no segment is truncated and speed does not dip at vertices. Each leg is
## stepped by `GroundMover.step()` against `grid` with the symbol mask; a
## leg that makes no progress (blocked) ends the step early -- patrol
## legality (GDD rule 5, CI-checked) makes that a data error.
func step(dt: float, grid: WalkGrid, cfg: OverworldConfig) -> void:
	last_distance_moved = 0.0
	if sub_state != SubState.PATROL or _path.size() < 2 or dt <= 0.0:
		return
	var speed: float = cfg.v_patrol()
	if speed <= 0.0:
		return
	var tol: float = cfg.waypoint_tol_m
	var dt_left: float = dt
	# Each iteration either reaches a waypoint or spends all of `dt_left`;
	# bound it so a degenerate path (all vertices within `tol`) cannot spin.
	var guard: int = _path.size() * 2 + 2
	while dt_left > 0.0 and guard > 0:
		guard -= 1
		var target: Vector2 = _path[_next]
		var to_target: Vector2 = target - position
		var dist: float = to_target.length()
		if dist == 0.0:
			_advance_waypoint()
			continue
		# The tolerance applies only once a leg aimed to arrive this step:
		# testing it up front would skip up to `tol` of path every time a
		# frame happened to end just short of a vertex.
		var arrive_dt: float = dist / speed
		var arrives: bool = arrive_dt <= dt_left
		var leg_dt: float = arrive_dt if arrives else dt_left
		var dir: Vector2 = to_target / dist
		var result: GroundMover.MoveResult = GroundMover.step(
				position, dir, leg_dt, grid, cfg, speed, WalkGrid.FLAG_SAFE)
		position = result.position
		facing = dir
		last_distance_moved += result.distance_moved
		dt_left -= leg_dt
		if arrives and position.distance_to(target) <= tol:
			_advance_waypoint()
		elif result.distance_moved <= 0.0:
			break


## Picks the next vertex once the current one is reached: wraps on `LOOP`
## (the closing segment back to vertex 0 included), reverses at either end
## on `PINGPONG`.
func _advance_waypoint() -> void:
	var n: int = _path.size()
	if _mode == PathMode.LOOP:
		_next = (_next + 1) % n
		return
	var candidate: int = _next + _dir
	if candidate < 0 or candidate >= n:
		_dir = -_dir
		candidate = _next + _dir
	_next = candidate
