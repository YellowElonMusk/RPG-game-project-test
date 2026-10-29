## AC-2: axis-separated collision slides the leader along a wall it
## approaches diagonally (non-zero tangential speed), and corner assist lets
## it pass a corner overlap of at most `corner_assist_m` without stopping.
## Fixture `WalkGrid`s are built by hand (ADR-0012 Implementation
## Guidelines) -- no `TileMapLayer` or bake pipeline involved.
extends GdUnitTestSuite

const _WALL_COLUMN: int = 2
const _COLUMN_GRID_COLS: int = 4
const _COLUMN_GRID_ROWS: int = 4

## The single blocked cell in `_make_single_wall_grid()`'s 3x2 fixture.
const _CORNER_WALL_CELL: Vector2i = Vector2i(1, 0)


## AC-2, part 1 (default config): a wall slide loses only the blocked axis's
## speed and keeps the open axis's, giving non-zero tangential speed.
func test_diagonal_approach_into_a_wall_slides_along_the_open_axis() -> void:
	_assert_wall_slide(OverworldConfig.new())


## Formula test harness rule: run once more against a non-default config.
func test_diagonal_approach_into_a_wall_slides_along_the_open_axis_with_custom_config() -> void:
	var cfg := OverworldConfig.new()
	cfg.walk_speed = 3.1
	cfg.body_radius = 0.35
	_assert_wall_slide(cfg)


## AC-2, part 2 (default config): a corner overlap inside the assist range
## passes without either axis stopping.
func test_corner_overlap_inside_assist_range_passes_without_stopping() -> void:
	_assert_corner_pass(OverworldConfig.new(), 0.1)


## Formula test harness rule: run once more against a non-default config.
func test_corner_overlap_inside_assist_range_passes_without_stopping_with_custom_config() -> void:
	var cfg := OverworldConfig.new()
	cfg.body_radius = 0.35
	cfg.corner_assist_m = 0.2
	_assert_corner_pass(cfg, 0.15)


## AC-2, part 2, boundary: an overlap of exactly `corner_assist_m` still
## passes ("at most `corner_assist_m`").
func test_corner_overlap_at_exact_assist_boundary_passes_without_stopping() -> void:
	var cfg := OverworldConfig.new()
	_assert_corner_pass(cfg, cfg.corner_assist_m)


## AC-2 boundary, the other end: a bare touch (overlap exactly 0) never
## blocks and nudges by nothing. The config values are exact in binary
## floating point, so the boundary is not blurred by representation error.
## (Replaces an earlier exact-zero test whose derived floats were noisy.)
func test_corner_bare_touch_never_blocks() -> void:
	var cfg := OverworldConfig.new()
	cfg.body_radius = 0.25
	cfg.corner_assist_m = 0.125
	_assert_corner_pass(cfg, 0.0)


## Contrast case: an overlap beyond the assist range still stops the leader
## dead on that axis, proving the assist is bounded, not unconditional.
func test_corner_overlap_beyond_assist_range_still_blocks() -> void:
	var cfg := OverworldConfig.new()
	var overlap: float = cfg.corner_assist_m + 0.05
	var grid: WalkGrid = _make_single_wall_grid()
	var resolved_x: float = 1.0 - (cfg.body_radius - overlap)
	var start: Vector2 = Vector2(resolved_x - 0.3, 1.5)
	var result: GroundMover.MoveResult = _step_with_displacement(start, Vector2(0.3, -0.6), grid, cfg)

	assert_bool(result.blocked_x).is_false()
	assert_bool(result.blocked_y).is_true()
	# Moving north (dir = -1) into row 0, which is blocked at this column:
	# clamped so the leading edge stops exactly at row 0's far (south) face.
	var expected_y: float = 1.0 * grid.cell_m + cfg.body_radius
	assert_float(result.position.y).is_equal_approx(expected_y, 1e-4)


## Builds a grid where column `_WALL_COLUMN` is blocked at every row and
## every other cell is walkable.
func _make_column_wall_grid() -> WalkGrid:
	var grid := WalkGrid.new()
	grid.cell_m = 1.0
	grid.size = Vector2i(_COLUMN_GRID_COLS, _COLUMN_GRID_ROWS)
	grid.cells = PackedByteArray()
	grid.cells.resize(_COLUMN_GRID_COLS * _COLUMN_GRID_ROWS)
	for y in range(_COLUMN_GRID_ROWS):
		for x in range(_COLUMN_GRID_COLS):
			grid.cells[y * _COLUMN_GRID_COLS + x] = 0 if x == _WALL_COLUMN else WalkGrid.FLAG_WALKABLE
	return grid


## Builds a 3x2 grid with a single blocked cell at `_CORNER_WALL_CELL` and
## every other cell walkable -- an inside corner with three open neighbours.
func _make_single_wall_grid() -> WalkGrid:
	var grid := WalkGrid.new()
	grid.cell_m = 1.0
	grid.size = Vector2i(3, 2)
	grid.cells = PackedByteArray()
	grid.cells.resize(3 * 2)
	for y in range(2):
		for x in range(3):
			var cell := Vector2i(x, y)
			grid.cells[y * 3 + x] = 0 if cell == _CORNER_WALL_CELL else WalkGrid.FLAG_WALKABLE
	return grid


## Runs one `GroundMover.step()` whose resulting displacement, before
## collision, is exactly `displacement` -- independent of `cfg.walk_speed`,
## by deriving `dt` from the direction and magnitude `displacement` already
## encodes (`GroundMover.step()`'s own `limit_length(1)` clamp is then a
## no-op, since the direction vector passed in already has length 1).
func _step_with_displacement(pos: Vector2, displacement: Vector2, grid: WalkGrid,
		cfg: OverworldConfig) -> GroundMover.MoveResult:
	var magnitude: float = displacement.length()
	var dir_vec: Vector2 = displacement / magnitude
	var dt: float = magnitude / cfg.walk_speed
	return GroundMover.step(pos, dir_vec, dt, grid, cfg, cfg.walk_speed, 0, true)


## Walks diagonally into `_WALL_COLUMN`'s face: starts `0.2 m` short of it
## and moves by `cfg.body_radius + 0.5` on each axis (comfortably overshoots
## the wall face before collision). Asserts the x-axis clamps to the wall
## face while the y-axis keeps its full, unblocked displacement.
func _assert_wall_slide(cfg: OverworldConfig) -> void:
	var grid: WalkGrid = _make_column_wall_grid()
	var start_x: float = float(_WALL_COLUMN) * grid.cell_m - cfg.body_radius - 0.2
	var pos: Vector2 = Vector2(start_x, 1.5)
	var move_amount: float = cfg.body_radius + 0.5
	var result: GroundMover.MoveResult = _step_with_displacement(
			pos, Vector2(move_amount, move_amount), grid, cfg)

	assert_bool(result.blocked_x).is_true()
	assert_bool(result.blocked_y).is_false()
	var expected_x: float = float(_WALL_COLUMN) * grid.cell_m - cfg.body_radius
	assert_float(result.position.x).is_equal_approx(expected_x, 1e-4)
	assert_float(result.position.y).is_equal_approx(pos.y + move_amount, 1e-4)


## Places the leader so its resolved x sits exactly `overlap` past the
## col0/col1 boundary into `_CORNER_WALL_CELL`'s column, then moves it north
## into `_CORNER_WALL_CELL`'s row. Asserts neither axis blocks, and the free
## axis (x) is nudged toward the open side by exactly `overlap`.
func _assert_corner_pass(cfg: OverworldConfig, overlap: float) -> void:
	var grid: WalkGrid = _make_single_wall_grid()
	var resolved_x: float = 1.0 - (cfg.body_radius - overlap)
	var start: Vector2 = Vector2(resolved_x - 0.3, 1.5)
	var result: GroundMover.MoveResult = _step_with_displacement(start, Vector2(0.3, -0.6), grid, cfg)

	assert_bool(result.blocked_x).is_false()
	assert_bool(result.blocked_y).is_false()
	var expected_x: float = resolved_x - overlap
	assert_float(result.position.x).is_equal_approx(expected_x, 1e-4)
	assert_float(result.position.y).is_equal_approx(start.y - 0.6, 1e-4)
