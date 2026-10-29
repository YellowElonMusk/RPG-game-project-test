## Story 020 (AC-9a, GDD rule 5 Patrol row): a patrolling `SymbolBrain`
## walks every segment of a `LOOP` path, the closing one included, at
## `v_patrol = f_patrol * walk_speed`, and reverses at each end of a
## `PINGPONG` path. Each frame's position is checked against the analytic
## point at arc length `v_patrol * t` along the (unfolded) polyline, so a
## skipped, truncated or reordered segment, or a speed dip at a vertex,
## fails. Fixture `WalkGrid` built by hand (ADR-0012 Implementation
## Guidelines).
extends GdUnitTestSuite

## 0.013 s is not a clean divisor of any segment time (test harness rule).
const _DT: float = 0.013
const _POS_TOL: float = 1e-3
const _DIST_TOL: float = 1e-4
const _GRID_SIZE: Vector2i = Vector2i(12, 10)
## Far outside every notice radius, so the notice test never passes.
const _FAR_LEADER: Vector2 = Vector2(-100.0, -100.0)

## Triangle loop; its closing segment (vertex 2 -> 0) is diagonal.
const _LOOP_PATH: Array[Vector2] = [Vector2(2.0, 2.0), Vector2(8.0, 2.0), Vector2(5.0, 7.0)]
## Four-vertex open polyline for pingpong.
const _PINGPONG_PATH: Array[Vector2] = [
	Vector2(2.0, 2.0), Vector2(6.0, 2.0), Vector2(6.0, 7.0), Vector2(9.0, 7.0)]


func test_loop_path_walks_every_segment_including_closing_at_v_patrol() -> void:
	_assert_loop_traversal(_default_cfg())


## Formula test harness rule: run once more against a non-default config.
func test_loop_path_walks_every_segment_including_closing_at_v_patrol_with_custom_config() -> void:
	_assert_loop_traversal(_custom_cfg())


func test_pingpong_path_reverses_at_each_end_at_v_patrol() -> void:
	_assert_pingpong_traversal(_default_cfg())


## Formula test harness rule: run once more against a non-default config.
func test_pingpong_path_reverses_at_each_end_at_v_patrol_with_custom_config() -> void:
	_assert_pingpong_traversal(_custom_cfg())


func test_v_patrol_is_f_patrol_times_walk_speed() -> void:
	var cfg := OverworldConfig.new()
	assert_float(cfg.v_patrol()).is_equal_approx(cfg.f_patrol * cfg.walk_speed, _DIST_TOL)
	var custom := _custom_cfg()
	assert_float(custom.v_patrol()).is_equal_approx(custom.f_patrol * custom.walk_speed, _DIST_TOL)


## Edge case: a one-vertex patrol is stationary -- the symbol holds still.
func test_single_vertex_path_holds_still() -> void:
	var cfg := OverworldConfig.new()
	var origin: Vector2 = _LOOP_PATH[0]
	var brain := SymbolBrain.new(PackedVector2Array([origin]), SymbolBrain.PathMode.LOOP)
	for i in 10:
		brain.step(_DT, _FAR_LEADER, _open_grid(), false, cfg)
	assert_vector(brain.position).is_equal(origin)
	assert_float(brain.last_distance_moved).is_equal(0.0)


func _assert_loop_traversal(cfg: OverworldConfig) -> void:
	var path := PackedVector2Array(_LOOP_PATH)
	var brain := SymbolBrain.new(path, SymbolBrain.PathMode.LOOP)
	var unfolded: PackedVector2Array = _unfold(path, SymbolBrain.PathMode.LOOP)
	var lap: float = _closed_length(unfolded)
	var frames: int = ceili(1.5 * lap / (cfg.v_patrol() * _DT))
	var targets: Array[int] = _run_and_check(brain, unfolded, frames, cfg)
	# Walked in order, wrapping through the closing segment (2 -> 0) and on.
	assert_array(targets.slice(0, 4)).is_equal([2, 0, 1, 2])
	assert_int(brain.direction()).is_equal(1)


func _assert_pingpong_traversal(cfg: OverworldConfig) -> void:
	var path := PackedVector2Array(_PINGPONG_PATH)
	var brain := SymbolBrain.new(path, SymbolBrain.PathMode.PINGPONG)
	var unfolded: PackedVector2Array = _unfold(path, SymbolBrain.PathMode.PINGPONG)
	var cycle: float = _closed_length(unfolded)
	var frames: int = ceili(1.25 * cycle / (cfg.v_patrol() * _DT))
	var last: int = path.size() - 1
	var facing_before_end: Vector2 = Vector2.ZERO
	var reversed_at_end: bool = false
	var dirs_at_flip: Array[int] = []
	var prev_dir: int = brain.direction()
	var targets: Array[int] = []
	var s: float = 0.0
	for i in frames:
		var prev_next: int = brain.next_index()
		var prev_facing: Vector2 = brain.heading
		brain.step(_DT, _FAR_LEADER, _open_grid(), false, cfg)
		s += cfg.v_patrol() * _DT
		_check_frame(brain, unfolded, s, cfg)
		if brain.next_index() != prev_next:
			targets.append(brain.next_index())
			if prev_next == last:
				facing_before_end = prev_facing
				reversed_at_end = true
				# Retraces the same final segment backward.
				assert_vector(brain.heading).is_equal_approx(-facing_before_end, Vector2(_POS_TOL, _POS_TOL))
		if brain.direction() != prev_dir:
			dirs_at_flip.append(brain.direction())
			prev_dir = brain.direction()
	assert_bool(reversed_at_end).is_true()
	# 1 -> 2 -> 3, reverse at the far end, 2 -> 1 -> 0, reverse at the start.
	assert_array(targets.slice(0, 6)).is_equal([2, 3, 2, 1, 0, 1])
	assert_array(dirs_at_flip.slice(0, 2)).is_equal([-1, 1])


## Steps `frames` times, checking every frame against the analytic arc
## point; returns the sequence of `next_index()` changes.
func _run_and_check(brain: SymbolBrain, unfolded: PackedVector2Array, frames: int,
		cfg: OverworldConfig) -> Array[int]:
	var targets: Array[int] = []
	var s: float = 0.0
	for i in frames:
		var prev_next: int = brain.next_index()
		brain.step(_DT, _FAR_LEADER, _open_grid(), false, cfg)
		s += cfg.v_patrol() * _DT
		_check_frame(brain, unfolded, s, cfg)
		if brain.next_index() != prev_next:
			targets.append(brain.next_index())
	return targets


func _check_frame(brain: SymbolBrain, unfolded: PackedVector2Array, s: float,
		cfg: OverworldConfig) -> void:
	assert_float(brain.last_distance_moved).is_equal_approx(cfg.v_patrol() * _DT, _DIST_TOL)
	var expected: Vector2 = _point_at_arc(unfolded, s)
	assert_vector(brain.position).is_equal_approx(expected, Vector2(_POS_TOL, _POS_TOL))


## A loop as-is; a pingpong unfolded to `0..n-1, n-2..1`, which is then
## walked as a closed loop.
func _unfold(path: PackedVector2Array, mode: SymbolBrain.PathMode) -> PackedVector2Array:
	var out := PackedVector2Array(path)
	if mode == SymbolBrain.PathMode.PINGPONG:
		for i in range(path.size() - 2, 0, -1):
			out.append(path[i])
	return out


func _closed_length(loop: PackedVector2Array) -> float:
	var total: float = 0.0
	for i in loop.size():
		total += loop[i].distance_to(loop[(i + 1) % loop.size()])
	return total


func _point_at_arc(loop: PackedVector2Array, s: float) -> Vector2:
	var remaining: float = fposmod(s, _closed_length(loop))
	for i in loop.size():
		var a: Vector2 = loop[i]
		var b: Vector2 = loop[(i + 1) % loop.size()]
		var seg: float = a.distance_to(b)
		if remaining <= seg:
			return a + (b - a) * (remaining / seg)
		remaining -= seg
	return loop[0]


## Fully walkable fixture grid, no `SAFE` cells.
func _open_grid() -> WalkGrid:
	var grid := WalkGrid.new()
	grid.size = _GRID_SIZE
	grid.cell_m = 1.0
	grid.cells.resize(_GRID_SIZE.x * _GRID_SIZE.y)
	grid.cells.fill(WalkGrid.FLAG_WALKABLE)
	return grid


func _custom_cfg() -> OverworldConfig:
	var cfg := OverworldConfig.new()
	cfg.walk_speed = 3.1
	cfg.f_patrol = 0.5
	cfg.waypoint_tol_m = 0.1
	cfg.turn_pause_s = 0.0
	return cfg


## Default config with the turn pause off: story 026 owns the pause
## (`symbol_brain_turn_pause_test.gd`); this suite checks uninterrupted
## arc-length traversal.
func _default_cfg() -> OverworldConfig:
	var cfg := OverworldConfig.new()
	cfg.turn_pause_s = 0.0
	return cfg
