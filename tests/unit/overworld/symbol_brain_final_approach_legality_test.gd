## Story 035 (AC-10e, GDD rule 5 "Chase target" final approach and "A*
## origins"): with a leader one cell inside a `SAFE` edge, a leader who rounds
## a wall corner between repaths, and a diagonal approach past a blocked
## corner, the symbol's centre is on a symbol-legal cell every frame, the
## final approach is used only when the leader is not `SAFE` and the swept
## straight segment is legal, and every query starts from a legal cell.
extends GdUnitTestSuite

const _DT: float = 1.0 / 60.0
const _GRID_SIZE: Vector2i = Vector2i(16, 12)


## Records every query origin so the test can check its legality.
class SpyGrid extends WalkGrid:
	var origins: Array[Vector2i] = []

	func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
		origins.append(from)
		return super.find_path(from, to)

	func bounded_route(from: Vector2i, to: Vector2i, cap_m: float) -> Array[Vector2i]:
		origins.append(from)
		return super.bounded_route(from, to, cap_m)


func test_leader_inside_safe_edge_gets_no_final_approach() -> void:
	for cfg: OverworldConfig in [OverworldConfig.new(), _custom_cfg()]:
		var grid := _grid()
		for y in _GRID_SIZE.y:
			for x in range(10, _GRID_SIZE.x):
				grid.cells[y * _GRID_SIZE.x + x] = WalkGrid.FLAG_WALKABLE | WalkGrid.FLAG_SAFE
		var brain := _brain(Vector2(6.5, 4.5), SymbolBrain.Facing.SE)
		_chase_until_chasing(brain, Vector2(8.5, 4.5), grid, cfg)
		var t: float = 0.0
		while t < 1.0:
			_step_checked(brain, Vector2(10.5, 4.5), grid, cfg)
			assert_bool(brain.used_final_approach).is_false()
			t += _DT
		_assert_origins_legal(grid)


func test_leader_rounding_a_corner_keeps_symbol_legal() -> void:
	for cfg: OverworldConfig in [OverworldConfig.new(), _custom_cfg()]:
		var grid := _grid()
		for y in 6:
			grid.cells[y * _GRID_SIZE.x + 8] = 0  # Wall column x = 8, rows 0-5.
		var brain := _brain(Vector2(4.5, 7.5), SymbolBrain.Facing.SE)
		var leader := Vector2(6.5, 7.5)
		_chase_until_chasing(brain, leader, grid, cfg)
		var waypoints: Array[Vector2] = [Vector2(9.5, 7.5), Vector2(9.5, 3.5)]
		var t: float = 0.0
		while t < 2.5:
			if not waypoints.is_empty():
				leader = leader.move_toward(waypoints[0], cfg.walk_speed * _DT)
				if leader == waypoints[0]:
					waypoints.pop_front()
			_step_checked(brain, leader, grid, cfg)
			t += _DT
		_assert_origins_legal(grid)


func test_diagonal_past_blocked_corner_falls_back_to_path() -> void:
	for cfg: OverworldConfig in [OverworldConfig.new(), _custom_cfg()]:
		var grid := _grid()
		grid.cells[4 * _GRID_SIZE.x + 5] = 0  # Corner cell (5, 4).
		var leader := Vector2(5.6, 5.6)
		var brain := _brain(Vector2(3.5, 3.5), SymbolBrain.Facing.SE)
		_chase_until_chasing(brain, leader, grid, cfg)
		# The straight segment sweeps past (5, 4): no final approach yet.
		assert_bool(grid.segment_clear(brain.position, leader, cfg.body_radius, true)).is_false()
		_step_checked(brain, leader, grid, cfg)
		assert_bool(brain.used_final_approach).is_false()
		var t: float = 0.0
		while t < 2.0:
			_step_checked(brain, leader, grid, cfg)
			t += _DT
		assert_float(brain.position.distance_to(leader)).is_less_equal(2.0 * cfg.body_radius)
		_assert_origins_legal(grid)


## One step, then the per-frame legality checks.
func _step_checked(brain: SymbolBrain, leader: Vector2, grid: WalkGrid, cfg: OverworldConfig) -> void:
	var before: Vector2 = brain.position
	var target: Vector2 = brain.chase_target(leader, grid, cfg)
	brain.step(_DT, leader, grid, false, cfg)
	assert_bool(grid.is_symbol_legal(grid.cell_of(brain.position))).is_true()
	if brain.used_final_approach:
		assert_bool(grid.is_safe(grid.cell_of(leader))).is_false()
		assert_bool(grid.segment_clear(before, target, cfg.body_radius, true)).is_true()
		assert_vector(grid.cell_of(target)).is_equal(brain.route_target_cell())


func _chase_until_chasing(brain: SymbolBrain, leader: Vector2, grid: WalkGrid, cfg: OverworldConfig) -> void:
	var guard: int = 1000
	while brain.sub_state != SymbolBrain.SubState.CHASING and guard > 0:
		brain.step(_DT, leader, grid, false, cfg)
		assert_bool(grid.is_symbol_legal(grid.cell_of(brain.position))).is_true()
		guard -= 1
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.CHASING)


func _assert_origins_legal(grid: SpyGrid) -> void:
	assert_int(grid.origins.size()).is_greater(0)
	for o: Vector2i in grid.origins:
		assert_bool(grid.is_symbol_legal(o)).is_true()


func _brain(spot: Vector2, facing: SymbolBrain.Facing) -> SymbolBrain:
	var brain := SymbolBrain.new(PackedVector2Array([spot]), SymbolBrain.PathMode.LOOP, 1)
	brain.facing = facing
	return brain


func _custom_cfg() -> OverworldConfig:
	var cfg := OverworldConfig.new()
	cfg.body_radius = 0.35
	cfg.f_chase = 0.75
	return cfg


func _grid() -> SpyGrid:
	var grid := SpyGrid.new()
	grid.size = _GRID_SIZE
	grid.cell_m = 1.0
	grid.cells.resize(_GRID_SIZE.x * _GRID_SIZE.y)
	grid.cells.fill(WalkGrid.FLAG_WALKABLE)
	return grid
