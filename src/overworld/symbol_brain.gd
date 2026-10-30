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
## - **Notice test** (stories 022-025, 029-030): runs only in Patrol, outside
##   the re-notice cooldown and outside encounter grace; check 1 the
##   half-plane radius, check 2 the leader not `SAFE`, check 3 the same
##   symbol-legal component, check 4 the bounded search (route cached per
##   symbol per (symbol cell, leader cell, grid revision)).
## - **Query budget** (story 028): every pathfinder query (notice search,
##   chase repath, Returning path) asks the injected `QueryBudget` first.
## - **Noticing** (story 021): a timed hold of `cfg.notice_delay_s`, then
##   Chasing unconditionally.
## - **Chasing** (stories 031-037): `cfg.v_chase()` along the stored A* route
##   toward the chase target, repathing at most every `cfg.repath_s` and only
##   when the target cell or the grid revision changed; the final approach;
##   the give-up test (`path_dist`, `SAFE` leader, empty path).
## - **Returning** (story 033, 037): A* at `cfg.v_patrol()` to the resume
##   point, then Patrol in its earlier direction with the re-notice cooldown;
##   an unreachable resume point holds the symbol still, deaf, with one
##   warning.
## - **Facing** (stories 026-027): snapped to the four displayed diagonals
##   with 45 + 5 degree hysteresis, held while not moving.
##
## - **Contact pending** (story 041): while `start_encounter` is rejected the
##   touched symbol holds still and keeps its sub-state (`contact_pending`);
##   `on_contact()` stores the resume point for a symbol touched in Patrol.
##   The swept contact test itself lives in `OverworldMode` (story 038).
##
## - **Stunned** (stories 044-046): `on_fled()` enters Stunned and pushes the
##   symbol back up to `cfg.flee_push_m` in 4-connected cell steps along the
##   leader-to-symbol line (opposite the leader's facing when the centres
##   coincide); deaf and intangible for `cfg.flee_grace_s`, then Returning.
##
## TODO(overworld): Static behaviour (`start_on`, the Fled return marker).
class_name SymbolBrain
extends RefCounted

## GDD rule 5 sub-states. `STUNNED` and `STATIC` hold still in `step()`
## (TODO(overworld): stories 038+).
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

## Returned by `nearest_legal_cell()` when the grid has no symbol-legal cell.
const NO_CELL: Vector2i = Vector2i(-1, -1)

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

## The symbol's index in its map's marker order. Picks the chase target's
## sideways offset, `(marker_index mod 3 - 1) * body_radius` (GDD rule 5
## "Chase target").
var marker_index: int = 0

## Distance actually covered by the most recent `step()`, in metres (sum of
## every `GroundMover.MoveResult.distance_moved` inside it).
var last_distance_moved: float = 0.0

## Diagnostic counter: how many times the notice test has been entered
## (story 024 asserts the deaf sub-states never enter it).
var notice_tests_run: int = 0

## Diagnostic counter: how many times the notice test reached check 4, the
## bounded search, whether it was served from the cache or not (story 022
## asserts check 1 rejects without a search).
var notice_searches_run: int = 0

## Diagnostic counter: pathfinder queries this brain was granted (notice
## searches, chase repaths and Returning paths; story 028's spy).
var queries_granted: int = 0

## Diagnostic counter: chase repaths issued (story 031's spy).
var repaths_run: int = 0

## Diagnostic counter: warnings logged (story 037: exactly one for an
## unreachable resume point).
var warnings_logged: int = 0

## Diagnostic: `true` when the most recent Chasing step used the final
## approach (straight at the target point) instead of the stored route.
var used_final_approach: bool = false

## GDD rule 5 "Contact pending": `true` while this symbol's encounter request
## is rejected and the overlap holds. `step()` then holds the symbol still
## (no movement, no timers; sub-state and facing kept). Set and cleared only
## by `OverworldMode`'s contact check (ADR-0012 §5).
var contact_pending: bool = false

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
## Seconds of stun left (Stunned only).
var _stun_left: float = 0.0

# Stored route (Chasing and Returning): remaining waypoints, in metres.
var _route: Array[Vector2] = []
# `w_last`, the stored route's end, kept once its waypoints are consumed.
var _route_end: Vector2 = Vector2.ZERO
# The cell the stored route was computed toward.
var _route_target_cell: Vector2i = NO_CELL
# `grid.revision()` when the route was computed.
var _route_revision: int = 0
# `c_L(t0)`: the leader's centre when the route was computed.
var _route_leader_t0: Vector2 = Vector2.ZERO
# `true` when the gap `w_last -> c_L(t0)` is not a real route (GDD "Path
# distance": the leader was `SAFE` at `t0`, or the gap crosses a cell the
# leader cannot walk).
var _route_gap_inf: bool = false
# The last query returned nothing and nothing is pending.
var _route_empty: bool = false
# A repath was deferred by the budget; the old route is kept.
var _repath_pending: bool = false
# Seconds since the stored route was computed.
var _since_repath: float = 0.0
# `d_L(t0 -> t)`: distance the leader has walked since `t0`.
var _leader_travel: float = 0.0
var _last_leader: Vector2 = Vector2.ZERO
# Seconds the give-up test has held without a break; -1 while it fails.
var _giveup_elapsed: float = -1.0

# Notice cache (GDD rule 5 check 4: waypoints cached per symbol).
var _cache_valid: bool = false
var _cache_from: Vector2i = NO_CELL
var _cache_to: Vector2i = NO_CELL
var _cache_rev: int = 0
var _cache_route: Array[Vector2i] = []

# Resume point (GDD rule 5 Returning row): where the symbol left Patrol.
var _resume_point: Vector2 = Vector2.ZERO
var _resume_next: int = 0
var _resume_dir: int = 1
var _return_needs_path: bool = false
var _return_stuck: bool = false

## Static only: `true` when contact also starts its fight (`start_on =
## contact_or_confirm`).
var _static_contact: bool = false


## `path` is the marker's patrol polyline in ground-plane metres; `mode`
## says how it continues past its last vertex; `p_marker_index` is the
## marker's index in map order. A path with fewer than two vertices is a
## stationary patrol: `step()` holds the symbol at vertex 0 (or
## `Vector2.ZERO` for an empty path).
func _init(path: PackedVector2Array, mode: PathMode, p_marker_index: int = 0) -> void:
	_path = path
	_mode = mode
	marker_index = p_marker_index
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


## The resume point stored when the symbol left Patrol (GDD rule 5
## Returning row).
func resume_point() -> Vector2:
	return _resume_point


## `true` while a budget-deferred repath keeps the old route (GDD: a pending
## path is never empty).
func is_repath_pending() -> bool:
	return _repath_pending


## `true` when the last route query returned nothing and nothing is pending.
func has_empty_route() -> bool:
	return _route_empty and not _repath_pending


## The cell the stored route leads to (`NO_CELL` before any route).
func route_target_cell() -> Vector2i:
	return _route_target_cell


## Seconds the give-up test has held without a break (0 while it fails).
func giveup_elapsed() -> float:
	return maxf(0.0, _giveup_elapsed)


## `true` once Returning found its resume point unreachable: the symbol
## holds still, deaf, until the map reloads (GDD rule 5 "No route").
func is_return_stuck() -> bool:
	return _return_stuck


## GDD rule 5 Contact: contact counts only in Patrol, Noticing and Chasing,
## and for a Static symbol whose `start_on` is `contact_or_confirm` (the
## boss, rule 13). A `confirm`-started Static symbol never makes contact
## (rule 13a). Grace and the leader's `SAFE` cell are the caller's checks.
func contact_eligible() -> bool:
	if sub_state == SubState.STATIC:
		return _static_contact
	return sub_state == SubState.PATROL or sub_state == SubState.NOTICING \
			or sub_state == SubState.CHASING


## Makes this a Static symbol (GDD rules 5, 13, 13a): it stands still and
## never notices, chases, is stunned or is pushed. `contact_starts` is
## `true` for `start_on = contact_or_confirm`, `false` for `confirm`.
func make_static(contact_starts: bool) -> void:
	sub_state = SubState.STATIC
	_static_contact = contact_starts


## `true` for a Static symbol (`confirm` can start it, whatever `start_on`).
func is_static() -> bool:
	return sub_state == SubState.STATIC


## Called by `OverworldMode` on the first frame of a contact (not on a
## contact-pending retry): a symbol touched during Patrol stores its patrol
## position as its resume point (GDD rule 5 Contact).
func on_contact() -> void:
	if contact_pending or sub_state != SubState.PATROL:
		return
	_resume_point = position
	_resume_next = _next
	_resume_dir = _dir


## ADR-0012 §5 `on_grace_started()`: a Noticing or Chasing symbol switches
## to Returning when encounter grace starts (GDD rule 7).
func on_grace_started() -> void:
	if sub_state == SubState.NOTICING or sub_state == SubState.CHASING:
		_enter_returning()


## Seconds left of the stun (0 outside Stunned).
func stun_left() -> float:
	return _stun_left


## Seconds spent in Noticing since the entry frame.
func notice_elapsed() -> float:
	return _notice_elapsed


## Seconds of re-notice cooldown left.
func cooldown_left() -> float:
	return _cooldown_left


## ADR-0012 §5 `on_fled(leader, leader_facing, grid, cfg)`, applied in
## `on_thawed` under the wipe (GDD rule 7 Fled, Edge Cases flee push). A
## Static symbol is neither stunned nor pushed. Otherwise the symbol enters
## Stunned for `cfg.flee_grace_s` and moves along `flee_push_direction()` by
## `push_distance()`. The leader is never moved (it is not this brain's).
func on_fled(leader: Vector2, leader_facing: Vector2, grid: WalkGrid, cfg: OverworldConfig) -> void:
	if sub_state == SubState.STATIC:
		return
	sub_state = SubState.STUNNED
	contact_pending = false
	_stun_left = cfg.flee_grace_s
	_pause_left = 0.0
	_route.clear()
	_repath_pending = false
	_giveup_elapsed = -1.0
	var dir: Vector2 = flee_push_direction(position, leader, leader_facing)
	if dir == Vector2.ZERO or grid == null:
		return
	position += dir * push_distance(grid, position, dir, cfg.flee_push_m, cfg.body_radius)


## The flee push's unit direction (GDD Edge Cases): along the leader-to-symbol
## line; when the centres coincide, opposite `leader_facing`. `Vector2.ZERO`
## (no push) only when both are zero, never an arbitrary axis.
static func flee_push_direction(symbol: Vector2, leader: Vector2, leader_facing: Vector2) -> Vector2:
	var away: Vector2 = symbol - leader
	if not away.is_zero_approx():
		return away.normalized()
	if leader_facing.is_zero_approx():
		return Vector2.ZERO
	return -leader_facing.normalized()


## How far the flee push carries a centre from `from` along unit `dir`, at
## most `max_m` (GDD Edge Cases): the cells the line crosses are walked one
## at a time, 4-connected (on an exact corner the x neighbour is tried
## first, so the push never hops diagonally between two blocked corners).
## At the first cell that is not symbol-legal the push stops, backed off by
## `body_radius` so the body stays clear of it (never below 0). Every cell
## entered is appended to `crossed` when given.
static func push_distance(grid: WalkGrid, from: Vector2, dir: Vector2, max_m: float,
		body_radius: float, crossed: Array[Vector2i] = []) -> float:
	var cell: Vector2i = grid.cell_of(from)
	crossed.append(cell)
	var cm: float = grid.cell_m
	var step_x: int = 1 if dir.x > 0.0 else -1
	var step_y: int = 1 if dir.y > 0.0 else -1
	var t_max_x: float = INF
	var t_max_y: float = INF
	var t_delta_x: float = INF
	var t_delta_y: float = INF
	if dir.x != 0.0:
		t_max_x = (float(cell.x + (1 if dir.x > 0.0 else 0)) * cm - from.x) / dir.x
		t_delta_x = cm / absf(dir.x)
	if dir.y != 0.0:
		t_max_y = (float(cell.y + (1 if dir.y > 0.0 else 0)) * cm - from.y) / dir.y
		t_delta_y = cm / absf(dir.y)
	while true:
		var t_next: float = minf(t_max_x, t_max_y)
		if t_next > max_m:
			return max_m
		if t_max_x <= t_max_y:
			cell.x += step_x
			t_max_x += t_delta_x
		else:
			cell.y += step_y
			t_max_y += t_delta_y
		if not grid.is_symbol_legal(cell):
			return maxf(0.0, t_next - body_radius)
		crossed.append(cell)
	return max_m


## The Returning -> Patrol transition (GDD rule 5 Returning row): back in
## Patrol, with the notice test off for `cfg.renotice_cooldown_s`. Called by
## the Returning step on reaching the resume point.
func rejoin_patrol(cfg: OverworldConfig) -> void:
	sub_state = SubState.PATROL
	_cooldown_left = cfg.renotice_cooldown_s


## Advances the brain by `dt` seconds (the overworld's `ow_dt`, ADR-0012
## §2). `leader` is the leader's ground-plane centre after this frame's
## leader move; whether it stands in a `SAFE` cell is read from `grid` (one
## source of truth instead of ADR-0012's separate `leader_safe` argument).
## `grace` is `true` during encounter grace (GDD rule 7), which keeps the
## notice test off whatever the sub-state. `budget` is the frame's shared
## `QueryBudget` (ADR-0012 §5); `null` serves every query (tests of other
## rules). It is the last, optional argument rather than ADR-0012's fifth,
## so earlier callers keep compiling.
##
## Patrol: tick the re-notice cooldown, run the notice test (entering
## Noticing, without moving, when it passes), else walk the path. Noticing:
## hold still; Chasing starts once `cfg.notice_delay_s` has elapsed since the
## entry frame. Chasing and Returning: see `_step_chasing()` and
## `_step_returning()`. Stunned and Static hold still (TODO(overworld)).
func step(dt: float, leader: Vector2, grid: WalkGrid, grace: bool, cfg: OverworldConfig,
		budget: QueryBudget = null) -> void:
	last_distance_moved = 0.0
	used_final_approach = false
	if dt <= 0.0 or contact_pending:
		return
	match sub_state:
		SubState.PATROL:
			if _cooldown_left > 0.0:
				_cooldown_left = maxf(0.0, _cooldown_left - dt)
			if not grace and _cooldown_left <= 0.0 and _notice_test(leader, grid, cfg, budget):
				_enter_noticing(leader, grid, cfg)
				return
			_walk_patrol(dt, grid, cfg)
		SubState.NOTICING:
			_track_leader(leader)
			_since_repath += dt
			_notice_elapsed += dt
			if _notice_elapsed >= cfg.notice_delay_s:
				sub_state = SubState.CHASING
				_giveup_elapsed = -1.0
		SubState.CHASING:
			_step_chasing(dt, leader, grid, cfg, budget)
		SubState.RETURNING:
			_step_returning(dt, grid, cfg, budget)
		SubState.STUNNED:
			# Deaf and intangible (GDD rule 5): no notice test, no movement;
			# Returning once `flee_grace_s` has run out. Only a stun armed by
			# `on_fled()` runs out; a bare `sub_state = STUNNED` just holds.
			if _stun_left > 0.0:
				_stun_left = maxf(0.0, _stun_left - dt)
				if _stun_left <= 0.0:
					_enter_returning()
		_:
			pass


## GDD rule 5 "Path distance": `arc(c_S -> w_last) + |w_last - c_L(t0)| +
## d_L(t0 -> t)` -- the remaining arc along the stored route from the
## symbol's centre, the gap from the route's end to the leader's centre when
## it was computed, and the distance the leader has walked since (tracked
## per step; `leader` adds any walk since the last step). `INF` when the
## route is empty or its gap is not a real route segment. Always an upper
## bound on the leader's true path distance.
func path_dist(leader: Vector2) -> float:
	if _route_empty or _route_gap_inf:
		return INF
	var arc: float = 0.0
	if _route.is_empty():
		arc = position.distance_to(_route_end)
	else:
		var p: Vector2 = position
		for w: Vector2 in _route:
			arc += p.distance_to(w)
			p = w
	return arc + _route_end.distance_to(_route_leader_t0) + _leader_travel \
			+ _last_leader.distance_to(leader)


## GDD rule 5 "Chase target": the symbol-legal cell nearest `leader` (ties:
## lowest cell index) -- the leader's own point when its cell is legal,
## else the closest point of that cell -- offset sideways by
## `(marker_index mod 3 - 1) * cfg.body_radius` perpendicular to this
## symbol's own symbol-to-leader vector. The offset is dropped when the
## offset point is not on a symbol-legal cell.
func chase_target(leader: Vector2, grid: WalkGrid, cfg: OverworldConfig) -> Vector2:
	var base: Vector2 = nearest_cell_point(grid, leader)
	var k: int = posmod(marker_index, 3) - 1
	var to_leader: Vector2 = leader - position
	if k == 0 or to_leader == Vector2.ZERO:
		return base
	var offset_point: Vector2 = base + to_leader.normalized().orthogonal() * (float(k) * cfg.body_radius)
	if grid.is_symbol_legal(grid.cell_of(offset_point)):
		return offset_point
	return base


## The closest point to `point` inside the symbol-legal cell nearest it
## (`point` itself when its cell is legal; `point` unchanged when the grid
## has no legal cell).
static func nearest_cell_point(grid: WalkGrid, point: Vector2) -> Vector2:
	var cell: Vector2i = nearest_legal_cell(grid, point)
	if cell == NO_CELL or cell == grid.cell_of(point):
		return point
	var lo: Vector2 = Vector2(cell) * grid.cell_m
	var hi: Vector2 = lo + Vector2(grid.cell_m, grid.cell_m) * (1.0 - 1e-6)
	return point.clamp(lo, hi)


## The symbol-legal cell nearest `point` (GDD rule 5 "A* origins" and
## "Chase target": ties go to the lowest cell index, `y * size.x + x`).
## Distance is from `point` to the cell's square. `NO_CELL` when none.
static func nearest_legal_cell(grid: WalkGrid, point: Vector2) -> Vector2i:
	var c: Vector2i = grid.cell_of(point)
	if grid.is_symbol_legal(c):
		return c
	var best: Vector2i = NO_CELL
	var best_d: float = INF
	var best_idx: int = 0
	var max_r: int = maxi(grid.size.x, grid.size.y) + absi(c.x) + absi(c.y) + 1
	for r in range(1, max_r + 1):
		if best != NO_CELL and float(r - 1) * grid.cell_m > best_d:
			break
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				if maxi(absi(x - c.x), absi(y - c.y)) != r:
					continue
				var cell := Vector2i(x, y)
				if not grid.is_symbol_legal(cell):
					continue
				var lo: Vector2 = Vector2(cell) * grid.cell_m
				var hi: Vector2 = lo + Vector2(grid.cell_m, grid.cell_m)
				var d: float = point.distance_to(point.clamp(lo, hi))
				var idx: int = y * grid.size.x + x
				if d < best_d or (d == best_d and idx < best_idx):
					best = cell
					best_d = d
					best_idx = idx
	return best


static func _ring_distance(a: int, b: int) -> int:
	var d: int = absi(a - b)
	return mini(d, DIAGONALS.size() - d)


## GDD rule 5 notice test, its cheap checks first; the first that fails ends
## it without any search. Entered only from Patrol, outside the cooldown and
## outside grace (the caller's gate).
func _notice_test(leader: Vector2, grid: WalkGrid, cfg: OverworldConfig, budget: QueryBudget) -> bool:
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
	# Check 3: same 4-connected symbol-legal component (AC-9h). A rejected
	# leader costs no query and never reaches the budget.
	var own_cell: Vector2i = nearest_legal_cell(grid, position)
	var leader_component: int = grid.component_of(leader_cell)
	if own_cell == NO_CELL or leader_component < 0 \
			or grid.component_of(own_cell) != leader_component:
		return false
	# Check 4: bounded search, served from the per-symbol cache when the
	# (symbol cell, leader cell, grid revision) key repeats. The end gaps
	# (symbol centre to its cell centre, target cell centre to the leader)
	# are recomputed from the exact centres on every use.
	notice_searches_run += 1
	if not (_cache_valid and _cache_from == own_cell and _cache_to == leader_cell
			and _cache_rev == grid.revision()):
		if budget != null and not budget.request(get_instance_id()):
			return false  # Deferred: "not noticed this frame" (GDD rule 5).
		queries_granted += 1
		_cache_route = grid.bounded_route(own_cell, leader_cell, cfg.notice_path_cap_m)
		_cache_valid = true
		_cache_from = own_cell
		_cache_to = leader_cell
		_cache_rev = grid.revision()
	if _cache_route.is_empty():
		return false
	var gaps: float = position.distance_to(grid.cell_center(own_cell)) \
			+ grid.cell_center(leader_cell).distance_to(leader)
	return grid.route_length(_cache_route) + gaps <= cfg.notice_path_cap_m


## Patrol -> Noticing: stop, cancel any turn pause, and turn to face the
## leader (snapped to the displayed diagonal; GDD rule 5 Noticing row). The
## facing then holds for as long as the symbol is not moving. Stores the
## resume point and installs the notice search's route as the chase's first
## path (GDD rule 5 "Path distance").
func _enter_noticing(leader: Vector2, grid: WalkGrid, cfg: OverworldConfig) -> void:
	sub_state = SubState.NOTICING
	_notice_elapsed = 0.0
	_pause_left = 0.0
	facing = nearest_facing(leader - position, facing)
	_resume_point = position
	_resume_next = _next
	_resume_dir = _dir
	_install_route(_cache_route, _cache_to, leader, grid, cfg, chase_target(leader, grid, cfg))


## Stores a cell route as the symbol's path (waypoints at cell centres) and
## restarts `path_dist`'s `t0` bookkeeping. The origin waypoint is dropped
## when the next one is reachable in a straight, legal line.
func _install_route(cells: Array[Vector2i], target_cell: Vector2i, leader: Vector2,
		grid: WalkGrid, cfg: OverworldConfig, end_point: Vector2 = Vector2.INF) -> void:
	_route.clear()
	for c: Vector2i in cells:
		_route.append(grid.cell_center(c))
	# Story 101: the route ends at the chase target itself (the leader's own
	# point when its cell is legal, GDD rule 5), not its cell's centre, so
	# `path_dist` does not overshoot the leader by up to a cell.
	if not _route.is_empty() and end_point != Vector2.INF and grid.cell_of(end_point) == target_cell:
		_route[_route.size() - 1] = end_point
	_route_empty = cells.is_empty()
	_route_target_cell = target_cell
	_route_revision = grid.revision()
	_route_end = position if _route_empty else _route[_route.size() - 1]
	_route_leader_t0 = leader
	_last_leader = leader
	_leader_travel = 0.0
	_route_gap_inf = _route_empty or grid.is_safe(grid.cell_of(leader)) \
			or not grid.segment_clear(_route_end, leader, 0.0, false)
	_repath_pending = false
	_since_repath = 0.0
	if _route.size() > 1 and grid.segment_clear(position, _route[1], cfg.body_radius, true):
		_route.pop_front()


func _track_leader(leader: Vector2) -> void:
	_leader_travel += _last_leader.distance_to(leader)
	_last_leader = leader


## GDD rule 5 Chasing row: repath (throttled, budgeted), move at `v_chase`
## by the final approach or along the route, then run the give-up test.
func _step_chasing(dt: float, leader: Vector2, grid: WalkGrid, cfg: OverworldConfig,
		budget: QueryBudget) -> void:
	_track_leader(leader)
	_since_repath += dt
	var target: Vector2 = chase_target(leader, grid, cfg)
	var target_cell: Vector2i = nearest_legal_cell(grid, target)
	var stale: bool = target_cell != _route_target_cell or grid.revision() != _route_revision
	if not stale:
		_repath_pending = false
	# Story 101: a symbol that has run out of route repaths at once (still
	# budgeted), never idling for `repath_s` while the leader walks away.
	elif _since_repath >= cfg.repath_s or (_route.is_empty() and not _route_empty):
		if budget == null or budget.request(get_instance_id()):
			queries_granted += 1
			repaths_run += 1
			var origin: Vector2i = nearest_legal_cell(grid, position)
			var cells: Array[Vector2i] = []
			if origin != NO_CELL and target_cell != NO_CELL:
				cells = grid.find_path(origin, target_cell)
			_install_route(cells, target_cell, leader, grid, cfg, target)
		else:
			_repath_pending = true  # The old route is kept: pending, never empty.
	var speed: float = cfg.v_chase()
	var leader_safe: bool = grid.is_safe(grid.cell_of(leader))
	# Final approach (GDD rule 5): only while the chase target's cell is the
	# route's target, the leader is not SAFE, the route exists, and the
	# straight segment swept by `body_radius` crosses only legal cells.
	if not _route_empty and not leader_safe and target_cell == _route_target_cell \
			and grid.segment_clear(position, target, cfg.body_radius, true):
		used_final_approach = true
		_leg(target, dt, speed, grid, cfg)
	else:
		var left: float = _follow_route(dt, speed, grid, cfg)
		# Story 101: a route run out mid-frame spends the rest of the step
		# on the chase target when the straight line there is clear.
		var clear: bool = grid.segment_clear(position, target, cfg.body_radius, true)
		if left > 0.0 and _route.is_empty() and not _route_empty and not leader_safe and clear:
			_leg(target, left, speed, grid, cfg)
	# Story 101: waypoints the final approach has passed drop out while the
	# next one is in a straight legal line, so the arc stays a tight real route.
	while _route.size() > 1 and grid.segment_clear(position, _route[1], cfg.body_radius, true):
		_route.pop_front()
	# Give-up test: `giveup_s` without a break of any "beyond" condition.
	var beyond: bool = leader_safe or (_route_empty and not _repath_pending) \
			or path_dist(leader) > cfg.symbol_giveup_m
	if not beyond:
		_giveup_elapsed = -1.0
		return
	_giveup_elapsed = 0.0 if _giveup_elapsed < 0.0 else _giveup_elapsed + dt
	if _giveup_elapsed >= cfg.giveup_s:
		_enter_returning()


## Chasing/Noticing -> Returning: deaf and intangible until the resume point.
func _enter_returning() -> void:
	sub_state = SubState.RETURNING
	_route.clear()
	_route_empty = false
	_repath_pending = false
	_giveup_elapsed = -1.0
	_pause_left = 0.0
	_return_needs_path = true


## GDD rule 5 Returning row: one budgeted A* query to the resume point, then
## walk it at `v_patrol`; on arrival resume Patrol in the earlier direction.
## An unreachable resume point holds the symbol still, deaf, until the map
## reloads, and logs one warning (GDD rule 5 "No route").
func _step_returning(dt: float, grid: WalkGrid, cfg: OverworldConfig, budget: QueryBudget) -> void:
	if _return_stuck:
		return
	if _return_needs_path:
		if budget != null and not budget.request(get_instance_id()):
			return
		queries_granted += 1
		var origin: Vector2i = nearest_legal_cell(grid, position)
		var goal: Vector2i = grid.cell_of(_resume_point)
		var cells: Array[Vector2i] = []
		if origin != NO_CELL:
			cells = grid.find_path(origin, goal)
		if cells.is_empty():
			_return_stuck = true
			warnings_logged += 1
			push_warning("SymbolBrain: resume point %s unreachable; holding still until reload" \
					% [_resume_point])
			return
		_route.clear()
		for c: Vector2i in cells:
			_route.append(grid.cell_center(c))
		_route[_route.size() - 1] = _resume_point
		if _route.size() > 1 and grid.segment_clear(position, _route[1], cfg.body_radius, true):
			_route.pop_front()
		_return_needs_path = false
	_follow_route(dt, cfg.v_patrol(), grid, cfg)
	if _route.is_empty():
		_next = _resume_next
		_dir = _resume_dir
		if _path.size() > 1:
			var leg: Vector2 = _path[_next] - position
			if leg != Vector2.ZERO:
				heading = leg.normalized()
				facing = snap_facing(facing, heading)
		rejoin_patrol(cfg)


## Walks the stored route at `speed` for `dt`, carrying leftover time past
## each reached waypoint (within `cfg.waypoint_tol_m`) onto the next.
func _follow_route(dt: float, speed: float, grid: WalkGrid, cfg: OverworldConfig) -> float:
	var dt_left: float = dt
	while dt_left > 0.0 and not _route.is_empty():
		var left: float = _leg(_route[0], dt_left, speed, grid, cfg)
		if left < 0.0:
			return 0.0
		_route.pop_front()
		dt_left = left
	return dt_left


## One straight leg toward `target` through `GroundMover.step()` with the
## symbol mask. Returns the unused time when it arrived (within
## `cfg.waypoint_tol_m`), or -1.0 when it did not.
func _leg(target: Vector2, dt_left: float, speed: float, grid: WalkGrid, cfg: OverworldConfig) -> float:
	var to_target: Vector2 = target - position
	var dist: float = to_target.length()
	if dist <= 0.0:
		return dt_left
	if speed <= 0.0:
		return -1.0
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
	if arrives and position.distance_to(target) <= cfg.waypoint_tol_m:
		return dt_left - leg_dt
	return -1.0


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
