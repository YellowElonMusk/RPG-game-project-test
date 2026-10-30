## Story 102, AC-40c (GDD rule 5 "Path distance", Formulas "Why I2 needs no
## repath term"): in a U-shaped corridor where the leader rounds the wall's
## end between repaths, `path_dist` is never below the true walk-grid path
## distance from symbol to leader, and once it exceeds `symbol_giveup_m` it
## stays above until Returning unless the true distance falls below first.
## The two `+INF` gaps: a leader in a SAFE cell at `t0`, and a gap from the
## path's end to the leader that crosses a wall.
extends GdUnitTestSuite

## 14 x 26 open grid with a wall on column 6 from row 0 to row 21: two arms
## joined round the wall's south end (rows 22-24).
const _SIZE: Vector2i = Vector2i(14, 26)
const _WALL_X: int = 6
const _WALL_END_Y: int = 21
const _SYMBOL: Vector2 = Vector2(2.5, 1.5)
## The leader's walk: down the west arm, round the wall end, up the east arm.
const _WALK: Array[Vector2] = [Vector2(3.5, 2.5), Vector2(3.5, 23.5), Vector2(9.5, 23.5), Vector2(9.5, 1.5)]
## The wall end's two south corners: a point path between the arms goes
## round them, so the true (point) geodesic is the straight line when it is
## clear, else west point -> (6, 9) -> (7, 9) -> east point.
const _CORNER_W: Vector2 = Vector2(_WALL_X, _WALL_END_Y + 1)
const _CORNER_E: Vector2 = Vector2(_WALL_X + 1, _WALL_END_Y + 1)


func test_path_dist_bounds_the_true_distance_and_give_up_holds() -> void:
	var cfg := OverworldConfig.new()
	# The symbol cuts the bend and closes in there, so give up at 5 m (not
	# the default 6.5) for the chase to go beyond it on the far arm.
	cfg.symbol_giveup_m = 5.0
	var dt: float = 1.0 / 60.0
	var grid := _u_grid()
	var brain := SymbolBrain.new(PackedVector2Array([_SYMBOL]), SymbolBrain.PathMode.LOOP, 1)
	brain.facing = SymbolBrain.Facing.SE
	var leader: Vector2 = _WALK[0]
	var frames: int = 0
	while brain.sub_state != SymbolBrain.SubState.CHASING and frames < 300:
		brain.step(dt, leader, grid, false, cfg)
		frames += 1
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.CHASING)
	var leg: int = 1
	var beyond_from: int = -1
	var checked: int = 0
	frames = 0
	while brain.sub_state == SymbolBrain.SubState.CHASING and frames < 1200:
		leader = _walk_toward(leader, leg, cfg.walk_speed * dt)
		if leader.is_equal_approx(_WALK[leg]) and leg < _WALK.size() - 1:
			leg += 1
		brain.step(dt, leader, grid, false, cfg)
		frames += 1
		if brain.sub_state != SymbolBrain.SubState.CHASING:
			break
		var pd: float = brain.path_dist(leader)
		var truth: float = _true_distance(grid, brain.position, leader)
		assert_float(pd).override_failure_message("frame %d: path_dist %.3f < true %.3f" % [frames, pd, truth]) \
				.is_greater_equal(truth - 1e-3)
		checked += 1
		if beyond_from < 0 and pd > cfg.symbol_giveup_m:
			beyond_from = frames
		elif beyond_from >= 0 and truth >= cfg.symbol_giveup_m:
			assert_float(pd).override_failure_message("frame %d: path_dist fell back under give-up" % frames) \
					.is_greater(cfg.symbol_giveup_m)
	assert_int(checked).is_greater(60)
	assert_int(beyond_from).override_failure_message("the chase never went beyond give-up").is_greater(0)
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.RETURNING)


func test_a_leader_in_a_safe_cell_at_t0_makes_the_gap_infinite() -> void:
	var cfg := OverworldConfig.new()
	var grid := _u_grid()
	var leader := Vector2(3.5, 4.5)
	grid.cells[grid.cell_of(leader).y * _SIZE.x + grid.cell_of(leader).x] |= WalkGrid.FLAG_SAFE
	var brain := SymbolBrain.new(PackedVector2Array([_SYMBOL]), SymbolBrain.PathMode.LOOP, 1)
	var target: Vector2i = SymbolBrain.nearest_legal_cell(grid, leader)
	var cells: Array[Vector2i] = grid.find_path(grid.cell_of(_SYMBOL), target)
	brain.call(&"_install_route", cells, target, leader, grid, cfg, grid.cell_center(target))
	assert_float(brain.path_dist(leader)).is_equal(INF)


func test_a_gap_crossing_a_wall_makes_the_gap_infinite() -> void:
	var cfg := OverworldConfig.new()
	var grid := _u_grid()
	# The route ends west of the wall; the leader stands just east of it.
	var end_cell := Vector2i(_WALL_X - 1, 4)
	var leader := Vector2(_WALL_X + 1.2, 4.5)
	var brain := SymbolBrain.new(PackedVector2Array([_SYMBOL]), SymbolBrain.PathMode.LOOP, 1)
	var cells: Array[Vector2i] = grid.find_path(grid.cell_of(_SYMBOL), end_cell)
	brain.call(&"_install_route", cells, end_cell, leader, grid, cfg, grid.cell_center(end_cell))
	assert_float(brain.path_dist(leader)).is_equal(INF)


func _walk_toward(at: Vector2, leg: int, step: float) -> Vector2:
	var to: Vector2 = _WALK[leg] - at
	return _WALK[leg] if to.length() <= step else at + to.normalized() * step


## The true shortest walk between the two points (a point body, so a lower
## bound on any route a symbol can take): straight when clear, else round
## the wall end's corners. Cell-centre grid distance is not a lower bound:
## two points in opposite corners of their cells sit well under it.
func _true_distance(grid: WalkGrid, from: Vector2, to: Vector2) -> float:
	if grid.segment_clear(from, to, 0.0, false):
		return from.distance_to(to)
	var west: Vector2 = from if from.x < to.x else to
	var east: Vector2 = to if from.x < to.x else from
	return west.distance_to(_CORNER_W) + _CORNER_W.distance_to(_CORNER_E) + _CORNER_E.distance_to(east)


func _u_grid() -> WalkGrid:
	var grid := WalkGrid.new()
	grid.size = _SIZE
	grid.cell_m = 1.0
	grid.cells.resize(_SIZE.x * _SIZE.y)
	grid.cells.fill(WalkGrid.FLAG_WALKABLE)
	for y: int in _WALL_END_Y + 1:
		grid.cells[y * _SIZE.x + _WALL_X] = 0
	for x: int in _SIZE.x:
		grid.cells[x] = 0
		grid.cells[(_SIZE.y - 1) * _SIZE.x + x] = 0
	for y: int in _SIZE.y:
		grid.cells[y * _SIZE.x] = 0
		grid.cells[y * _SIZE.x + _SIZE.x - 1] = 0
	return grid
