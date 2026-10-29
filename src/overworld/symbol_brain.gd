## Pure per-symbol AI (ADR-0012 §5 Key Interfaces; GDD
## `design/gdd/overworld-exploration-encounters.md` rule 5). One instance per
## `EncounterSymbol`; owns the symbol's ground-plane position, its facing and
## its sub-state, and moves only through `GroundMover.step()` with the symbol
## mask (walls + runtime-blocked + `SAFE`).
##
## Implemented so far:
## - **Patrol** (story 020): walk the marker's patrol polyline at
##   `cfg.v_patrol()`, closing a `LOOP` path's last vertex back to the first,
##   or reversing at each end of a `PINGPONG` path; the **turn pause** at a
##   `PINGPONG` end or a `LOOP` vertex turning by more than 90 degrees, the old
##   facing deciding the half-planes until the flip (story 026).
## - **Notice test** (stories 022-025): runs only in Patrol, outside the
##   re-notice cooldown and outside encounter grace; check 1 the half-plane
##   radius, check 2 the leader not `SAFE`, check 4 the bounded search.
## - **Noticing** (story 021): a timed hold of `cfg.notice_delay_s`, then
##   Chasing unconditionally.
## - **Facing** (stories 026-027): snapped to the four displayed diagonals
##   with 45 + 5 degree hysteresis, held while not moving.
##
## TODO(overworld): Chasing/Returning/Stunned/Static behaviour (stories 031+;
## Chasing currently holds still), notice check 3 (component labels, AC-9h),
## and the `QueryBudget` argument of ADR-0012's
## `step(dt, leader, leader_safe, grid, budget, grace, cfg)` (stories 028-030).
class_name SymbolBrain
extends RefCounted

## GDD rule 5 sub-states. `PATROL` and `NOTICING` have behaviour; the rest
## hold still in `step()` (TODO(overworld): stories 031+).
enum SubState { PATROL, NOTICING, CHASING, RETURNING, STUNNED, STATIC }

## How a patrol polyline continues past its last vertex (GDD rule 5: "a
## polyline marked `loop` (closed: last vertex back to first) or `pingpong`
## (walks back the way it came)").
enum PathMode { LOOP, PINGPONG }

## The four displayed sprite facings (ADR-0005 §1), in the GDD rule 5
## tie-break order: "the lower index (NE 0, SE 1, SW 2, NW 3)".
enum Facing { NE, SE, SW, NW }

## Ground-plane direction of each `Facing`, unnormalized so a half-plane dot
## product of 0 is exact. Ground `+x` is screen right and ground `+y` screen
## down (toward the camera at `FollowCamera.yaw_degrees` 0). TODO(overworld):
## rotate by the camera yaw if a map ever uses a non-zero yaw.
const DIAGONALS: Array[Vector2] = [
	Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0), Vector2(-1.0, -1.0)]

## Half the angle between neighbouring diagonals, in degrees.
const _HALF_SECTOR_DEG: float = 45.0

## GDD rule 5 Facing clause: "the facing changes only when the movement
## direction is more than 45° + 5° from the current diagonal". The 5° is a
## rule constant, not a GDD Tuning Knob, so it lives here, not in config.
const FACING_HYSTERESIS_DEG: float = 5.0

## Current sub-state. Starts in `PATROL` (GDD edge cases: symbols start at
## their patrol origins in Patrol).
var sub_state: SubState = SubState.PATROL

## Ground-plane position, in metres. Starts at the patrol origin (vertex 0).
var position: Vector2 = Vector2.ZERO

## Logical facing: the displayed diagonal (GDD rule 5 Facing clause). Decides
## the notice half-planes. Starts as the snap of the first patrol leg.
var facing: Facing = Facing.NE

## Raw direction of the most recent movement leg, normalized (the unsnapped
## input to `facing`).
var heading: Vector2 = Vector2.RIGHT

## Distance actually covered by the most recent `step()`, in metres (sum of
## every `GroundMover.MoveResult.distance_moved` inside it).
var last_distance_moved: float = 0.0

## Diagnostic counter: how many times the notice test has been entered
## (story 024 asserts the deaf sub-states never enter it).
var notice_tests_run: int = 0

## Diagnostic counter: how many times the notice test reached its bounded
## search, check 4 (story 022 asserts check 1 rejects without a search).
var notice_searches_run: int = 0

var _path: PackedVector2Array
var _mode: PathMode
## Index of the vertex currently being walked toward.
var _next: int = 0
## +1 walking toward higher indices, -1 walking back (PINGPONG only).
var _dir: int = 1
## Seconds spent in Noticing since the entry frame.
var _notice_elapsed: float = 0.0
## Seconds of re-notice cooldown left after rejoining Patrol.
var _cooldown_left: float = 0.0
## Seconds of turn pause left; > 0 while in the look-back pose.
var _pause_left: float = 0.0


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
			heading = first_leg.normalized()
			facing = nearest_facing(heading, -1)


## Index of the patrol vertex the symbol is currently walking toward.
func next_index() -> int:
	return _next


## +1 while walking toward higher vertex indices, -1 while walking back
## along a `PINGPONG` path. Always +1 on a `LOOP` path.
func direction() -> int:
	return _dir


## `true` while the symbol stands in its turn-pause look-back pose (GDD
## rule 5 Patrol row).
func is_turn_pausing() -> bool:
	return _pause_left > 0.0


## `true` while the re-notice cooldown keeps the notice test off.
func in_renotice_cooldown() -> bool:
	return _cooldown_left > 0.0


## Unit ground-plane vector of the current `facing`.
func facing_vector() -> Vector2:
	return DIAGONALS[facing].normalized()


## The Returning -> Patrol transition (GDD rule 5 Returning row): back in
## Patrol, with the notice test off for `cfg.renotice_cooldown_s`.
## TODO(overworld): the Returning behaviour (stories 031+) calls this on
## reaching the resume point; until then only tests drive it.
func rejoin_patrol(cfg: OverworldConfig) -> void:
	sub_state = SubState.PATROL
	_cooldown_left = cfg.renotice_cooldown_s


## Advances the brain by `dt` seconds (the overworld's `ow_dt`, ADR-0012
## §2). `leader` is the leader's ground-plane centre after this frame's
## leader move; whether it stands in a `SAFE` cell is read from `grid` (one
## source of truth instead of ADR-0012's separate `leader_safe` argument).
## `grace` is `true` during encounter grace (GDD rule 7), which keeps the
## notice test off whatever the sub-state.
##
## Patrol: tick the re-notice cooldown, run the notice test (entering
## Noticing, without moving, when it passes), else walk the path. Noticing:
## hold still; Chasing starts once `cfg.notice_delay_s` has elapsed since the
## entry frame. Every other sub-state holds still (TODO(overworld)).
func step(dt: float, leader: Vector2, grid: WalkGrid, grace: bool, cfg: OverworldConfig) -> void:
	last_distance_moved = 0.0
	if dt <= 0.0:
		return
	match sub_state:
		SubState.PATROL:
			if _cooldown_left > 0.0:
				_cooldown_left = maxf(0.0, _cooldown_left - dt)
			if not grace and _cooldown_left <= 0.0 and _notice_test(leader, grid, cfg):
				_enter_noticing(leader)
				return
			_walk_patrol(dt, grid, cfg)
		SubState.NOTICING:
			_notice_elapsed += dt
			if _notice_elapsed >= cfg.notice_delay_s:
				# TODO(overworld): chase movement (stories 031+); Chasing holds
				# still until then.
				sub_state = SubState.CHASING
		_:
			pass


## The facing a moving symbol shows (GDD rule 5 Facing clause): `current`
## is kept unless `dir` is more than 45° + 5° from it, in which case the
## nearest diagonal wins (`nearest_facing`). A zero `dir` (not moving) keeps
## `current`.
static func snap_facing(current: Facing, dir: Vector2) -> Facing:
	if dir == Vector2.ZERO:
		return current
	var off_deg: float = absf(rad_to_deg(dir.angle_to(DIAGONALS[current])))
	if off_deg <= _HALF_SECTOR_DEG + FACING_HYSTERESIS_DEG:
		return current
	return nearest_facing(dir, current)


## The diagonal nearest `dir`, with no hysteresis. Ties (a direction exactly
## between two diagonals) go to the one nearer `previous`, then to the lower
## index (GDD rule 5). Pass `previous = -1` when there is none. A zero `dir`
## returns `previous` (or `NE` when there is none).
static func nearest_facing(dir: Vector2, previous: int) -> Facing:
	if dir == Vector2.ZERO:
		return (previous if previous >= 0 else Facing.NE) as Facing
	var best: int = -1
	var best_deg: float = INF
	for i in DIAGONALS.size():
		var deg: float = absf(rad_to_deg(dir.angle_to(DIAGONALS[i])))
		if best < 0 or deg < best_deg:
			best = i
			best_deg = deg
		elif deg == best_deg and previous >= 0 \
				and _ring_distance(i, previous) < _ring_distance(best, previous):
			best = i
	return best as Facing


static func _ring_distance(a: int, b: int) -> int:
	var d: int = absi(a - b)
	return mini(d, DIAGONALS.size() - d)


## GDD rule 5 notice test, its cheap checks first; the first that fails ends
## it without any search. Entered only from Patrol, outside the cooldown and
## outside grace (the caller's gate).
func _notice_test(leader: Vector2, grid: WalkGrid, cfg: OverworldConfig) -> bool:
	notice_tests_run += 1
	# Check 1: half-plane radius. A leader exactly on the dividing line (dot
	# product 0) counts as in front.
	var offset: Vector2 = leader - position
	var in_front: bool = offset.dot(DIAGONALS[facing]) >= 0.0
	var radius: float = cfg.symbol_chase_m if in_front else cfg.symbol_notice_rear_m
	if offset.length() > radius:
		return false
	# Check 2: the leader is not in a SAFE cell.
	var leader_cell: Vector2i = grid.cell_of(leader)
	if grid.is_safe(leader_cell):
		return false
	# TODO(overworld): check 3, same symbol-legal component (AC-9h) once
	# `WalkGrid.component_of()` exists; check 4 below rejects a disconnected
	# leader too, at a cost bounded by the cap.
	# Check 4: bounded search. The end gaps (symbol centre to its cell centre,
	# target cell centre to the leader) are paid out of the cap first.
	# TODO(overworld): the chase target's nearest-legal-cell fallback and
	# sideways offset (GDD "Chase target") land with Chasing; the leader's
	# own cell is the target here.
	notice_searches_run += 1
	var own_cell: Vector2i = grid.cell_of(position)
	var gaps: float = position.distance_to(grid.cell_center(own_cell)) \
			+ grid.cell_center(leader_cell).distance_to(leader)
	var cap: float = cfg.notice_path_cap_m - gaps
	return grid.bounded_search(own_cell, leader_cell, cap) <= cap


## Patrol -> Noticing: stop, cancel any turn pause, and turn to face the
## leader (snapped to the displayed diagonal; GDD rule 5 Noticing row). The
## facing then holds for as long as the symbol is not moving.
func _enter_noticing(leader: Vector2) -> void:
	sub_state = SubState.NOTICING
	_notice_elapsed = 0.0
	_pause_left = 0.0
	facing = nearest_facing(leader - position, facing)


## Patrol movement: the symbol covers `cfg.v_patrol() * dt` metres of path
## arc length; whatever budget remains after reaching a waypoint (within
## `cfg.waypoint_tol_m`) carries onto the next segment, or into a turn pause,
## in the same step, so no segment is truncated and speed does not dip at
## vertices. Each leg is stepped by `GroundMover.step()` against `grid` with
## the symbol mask; a leg that makes no progress (blocked) ends the step
## early -- patrol legality (GDD rule 5, CI-checked) makes that a data error.
func _walk_patrol(dt: float, grid: WalkGrid, cfg: OverworldConfig) -> void:
	if _path.size() < 2:
		return
	var speed: float = cfg.v_patrol()
	if speed <= 0.0:
		return
	var tol: float = cfg.waypoint_tol_m
	var dt_left: float = dt
	# Each iteration reaches a waypoint, ends a pause or spends all of
	# `dt_left`; bound it so a degenerate path (all vertices within `tol`)
	# cannot spin.
	var guard: int = _path.size() * 3 + 3
	while dt_left > 0.0 and guard > 0:
		guard -= 1
		if _pause_left > 0.0:
			var used: float = minf(_pause_left, dt_left)
			_pause_left -= used
			dt_left -= used
			if _pause_left <= 0.0:
				_pause_left = 0.0
				# The flip happens at the pause's end (GDD rule 5 Patrol row).
				var new_leg: Vector2 = _path[_next] - position
				if new_leg != Vector2.ZERO:
					heading = new_leg.normalized()
					facing = snap_facing(facing, heading)
			continue
		var target: Vector2 = _path[_next]
		var to_target: Vector2 = target - position
		var dist: float = to_target.length()
		if dist == 0.0:
			_on_waypoint_reached(cfg)
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
		heading = dir
		facing = snap_facing(facing, dir)
		last_distance_moved += result.distance_moved
		dt_left -= leg_dt
		if arrives and position.distance_to(target) <= tol:
			_on_waypoint_reached(cfg)
		elif result.distance_moved <= 0.0:
			break


## Picks the next vertex once the current one is reached -- wraps on `LOOP`
## (the closing segment back to vertex 0 included), reverses at either end
## on `PINGPONG` -- and starts a turn pause at a `PINGPONG` end or a `LOOP`
## vertex turning by more than 90° (GDD rule 5 Patrol row; exactly 90° or
## less: no pause). Turn angles come from the path vertices, not the walked
## heading, so float noise cannot invent a pause at a right angle.
func _on_waypoint_reached(cfg: OverworldConfig) -> void:
	var n: int = _path.size()
	var reached: int = _next
	var came_from: int = (reached - _dir + n) % n
	var incoming: Vector2 = _path[reached] - _path[came_from]
	var turns_back: bool = false
	if _mode == PathMode.LOOP:
		_next = (_next + 1) % n
		var outgoing: Vector2 = _path[_next] - _path[reached]
		turns_back = incoming.dot(outgoing) < 0.0
	else:
		var candidate: int = _next + _dir
		if candidate < 0 or candidate >= n:
			_dir = -_dir
			candidate = _next + _dir
			turns_back = true
		_next = candidate
	if turns_back and cfg.turn_pause_s > 0.0:
		_pause_left = cfg.turn_pause_s
