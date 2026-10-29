## Pure, static ground-plane mover (ADR-0012 §2 Key Interfaces). Used by the
## leader and, later, by symbols -- this class is never instantiated.
class_name GroundMover


## One `GroundMover.step()` outcome. `blocked_x`/`blocked_y` are collision
## flags against `grid`/`blocked_mask` (story 004): `true` iff that axis's
## move was clamped against a wall this step (a corner-assisted axis is
## *not* flagged blocked -- it passed).
class MoveResult:
	## The resulting ground-plane position, in metres.
	var position: Vector2
	## `true` iff the x-axis move this step was blocked.
	var blocked_x: bool
	## `true` iff the y-axis move this step was blocked.
	var blocked_y: bool
	## Distance actually covered this step, in metres.
	var distance_moved: float

	func _init(p_position: Vector2, p_blocked_x: bool, p_blocked_y: bool,
			p_distance_moved: float) -> void:
		position = p_position
		blocked_x = p_blocked_x
		blocked_y = p_blocked_y
		distance_moved = p_distance_moved


## One axis's resolved value (story 004 internal; see `_resolve_axis()`).
class _AxisResult:
	## The resolved coordinate along this axis.
	var value: float
	## `true` iff this axis's move was clamped against a wall.
	var blocked: bool
	## The amount to add to the *perpendicular* axis -- nonzero only when
	## this axis was corner-assisted past a grazed corner, zero otherwise.
	var perp_nudge: float

	func _init(p_value: float, p_blocked: bool, p_perp_nudge: float) -> void:
		value = p_value
		blocked = p_blocked
		perp_nudge = p_perp_nudge


## Steps one actor on the ground plane (ADR-0012 §2):
## 1. **Velocity.** `velocity = input_vec.limit_length(1) * speed` -- the
##    leader passes `cfg.walk_speed`; a symbol passes `v_patrol` or
##    `v_chase`. `speed` is its own parameter (not read off `cfg`) because
##    the caller, not this function, picks which speed applies. This clamp is
##    what makes magnitude scale speed linearly below 1 and cap at `speed`
##    for any `input_vec` longer than 1 -- e.g. a diagonal keyboard vector
##    before `InputResolver.get_move_vector()`'s own normalization (story
##    002, AC-1b). The two layers compose rather than double-scale because
##    this function clamps the *post-normalization* vector it is handed, not
##    a second time on top of ADR-0003's own clamp.
## 2. **Axis-separated collision**, resolved x then y, each against `grid`
##    using `cfg.body_radius` (story 004): if an axis's leading edge, swept
##    across the other axis's current span, overlaps a cell `grid.is_blocked()`
##    reports for `blocked_mask`, that axis clamps to the wall face instead of
##    moving -- the untouched axis keeps its full velocity, which is the
##    slide (GDD AC-2, part 1).
## 3. **Corner assist.** `grid.is_blocked()` is checked per cell, so a span
##    that straddles a cell boundary with exactly one side blocked is a
##    corner graze, not a flat wall: its overlap is `cfg.body_radius` minus
##    the distance from the span's centre to the boundary. Zero or negative
##    overlap is a bare touch and never blocks. A positive overlap at most
##    `cfg.corner_assist_m` (0 disables this) doesn't block either -- instead
##    the perpendicular axis is nudged by that overlap, toward the open side,
##    so the leader passes the corner instead of stopping dead (GDD AC-2,
##    part 2). A deeper overlap still blocks, same as a flat wall.
## `grid` is null-safe: passing `null` (the leader's call until a map-loading
## story injects a baked `WalkGrid`) skips collision entirely, matching the
## pre-story-004 behaviour.
static func step(pos: Vector2, input_vec: Vector2, dt: float, grid: WalkGrid, cfg: OverworldConfig,
		speed: float, blocked_mask: int) -> MoveResult:
	var velocity: Vector2 = input_vec.limit_length(1.0) * speed
	var candidate: Vector2 = pos + velocity * dt

	if grid == null:
		return MoveResult.new(candidate, false, false, (candidate - pos).length())

	var radius: float = cfg.body_radius
	var corner_assist_m: float = cfg.corner_assist_m

	var x_result: _AxisResult = _resolve_axis(
			pos.x, candidate.x - pos.x, pos.y, radius, true, grid, blocked_mask, corner_assist_m)
	var y_base: float = pos.y + x_result.perp_nudge
	var y_result: _AxisResult = _resolve_axis(
			y_base, candidate.y - pos.y, x_result.value, radius, false, grid, blocked_mask, corner_assist_m)
	var final_x: float = x_result.value + y_result.perp_nudge

	var new_pos: Vector2 = Vector2(final_x, y_result.value)
	var distance_moved: float = (new_pos - pos).length()
	return MoveResult.new(new_pos, x_result.blocked, y_result.blocked, distance_moved)


## Resolves one axis of a position update against `grid` (ADR-0012 §2.2-3).
## `is_x` true resolves the x-axis (`value` is x, `perp` is the current y);
## false resolves y (`value` is y, `perp` is the current x). `perp` is the
## *current* coordinate of the other axis -- the old value when resolving
## the first axis, the already-resolved value when resolving the second --
## so a corner nudge found while resolving one axis composes into the other.
static func _resolve_axis(value: float, delta: float, perp: float, radius: float, is_x: bool,
		grid: WalkGrid, blocked_mask: int, corner_assist_m: float) -> _AxisResult:
	if delta == 0.0:
		return _AxisResult.new(value, false, 0.0)

	var cell_m: float = grid.cell_m
	var dir: float = signf(delta)
	var candidate: float = value + delta
	var leading: float = candidate + dir * radius
	var lead_cell: int = floori(leading / cell_m)

	var perp_lo: int = floori((perp - radius) / cell_m)
	var perp_hi: int = floori((perp + radius) / cell_m)
	var lo_blocked: bool = _axis_cell_blocked(lead_cell, perp_lo, is_x, grid, blocked_mask)
	var hi_blocked: bool = lo_blocked if perp_hi == perp_lo else \
			_axis_cell_blocked(lead_cell, perp_hi, is_x, grid, blocked_mask)

	if not lo_blocked and not hi_blocked:
		return _AxisResult.new(candidate, false, 0.0)

	if perp_hi != perp_lo and lo_blocked != hi_blocked:
		# Straddling a perpendicular cell boundary with exactly one side
		# blocked: a corner graze, not a flat wall. `boundary` is the edge
		# shared by `perp_lo`/`perp_hi`; the open side is whichever one
		# isn't blocked.
		var boundary: float = float(perp_hi) * cell_m
		var open_sign: float = 1.0 if lo_blocked else -1.0
		var overlap: float = radius - absf(perp - boundary)
		if overlap <= 0.0:
			# A bare touch, no actual penetration: no collision at all.
			return _AxisResult.new(candidate, false, 0.0)
		if corner_assist_m > 0.0 and overlap <= corner_assist_m:
			return _AxisResult.new(candidate, false, open_sign * overlap)

	# Outright blocked: a flat wall, a corner overlap too deep to assist, or
	# a solid wall spanning both straddled cells. Clamp so this axis's
	# leading edge stops exactly at the wall face.
	var wall_cell: int = lead_cell if dir > 0.0 else lead_cell + 1
	var clamped: float = float(wall_cell) * cell_m - dir * radius
	return _AxisResult.new(clamped, true, 0.0)


## `is_x` true: `lead` is a column index, `perp_cell` a row index. False:
## the reverse.
static func _axis_cell_blocked(lead: int, perp_cell: int, is_x: bool, grid: WalkGrid, blocked_mask: int) -> bool:
	var cell: Vector2i = Vector2i(lead, perp_cell) if is_x else Vector2i(perp_cell, lead)
	return grid.is_blocked(cell, blocked_mask)
