## Pure, static ground-plane mover (ADR-0012 §2 Key Interfaces). Used by the
## leader and, later, by symbols -- this class is never instantiated.
class_name GroundMover


## One `GroundMover.step()` outcome. `blocked_x`/`blocked_y` are collision
## flags against `grid`/`blocked_mask`: story 004 is what makes `step()` ever
## set them `true`; until then they are always `false`.
class MoveResult:
	## The resulting ground-plane position, in metres.
	var position: Vector2
	## `true` iff the x-axis move this step was blocked (story 004).
	var blocked_x: bool
	## `true` iff the y-axis move this step was blocked (story 004).
	var blocked_y: bool
	## Distance actually covered this step, in metres.
	var distance_moved: float

	func _init(p_position: Vector2, p_blocked_x: bool, p_blocked_y: bool,
			p_distance_moved: float) -> void:
		position = p_position
		blocked_x = p_blocked_x
		blocked_y = p_blocked_y
		distance_moved = p_distance_moved


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
## 2. **Axis-separated collision** against `grid`/`blocked_mask`, using
##    `cfg.body_radius`, and **3. corner assist** (leader only) via
##    `cfg.corner_assist_m` -- both land in story 004. Until then, `grid`,
##    `blocked_mask` and `cfg` are accepted (so this signature does not have
##    to change shape when that story lands) but not read, and `pos` moves by
##    `velocity * dt` unobstructed.
##
## `grid` is typed `Object`, not `WalkGrid`, because `WalkGrid`
## (`src/overworld/walk_grid.gd`) is story 004's file and does not exist yet;
## narrow this parameter's type the same story adds it.
static func step(pos: Vector2, input_vec: Vector2, dt: float, grid: Object, cfg: OverworldConfig,
		speed: float, blocked_mask: int) -> MoveResult:
	var velocity: Vector2 = input_vec.limit_length(1.0) * speed
	var new_pos: Vector2 = pos + velocity * dt
	var distance_moved: float = (new_pos - pos).length()
	return MoveResult.new(new_pos, false, false, distance_moved)
