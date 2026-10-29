## Story 034 (AC-10d, GDD rule 5 "Chase target"): a still, off-centre
## leader is reached within `path_dist0 / v_chase + 2 dt`; each symbol's
## target sits `|(i mod 3) - 1| * body_radius` from the nearest-cell point,
## perpendicular to its own symbol-to-leader vector, and the offset is
## dropped when it lands off a symbol-legal cell. Nearest-cell ties go to
## the lowest cell index.
extends GdUnitTestSuite

const _DT: float = 1.0 / 60.0
const _GRID_SIZE: Vector2i = Vector2i(14, 12)
const _LEADER: Vector2 = Vector2(8.3, 5.7)


func test_still_leader_reached_within_bound() -> void:
	for i in 3:
		_assert_reached(OverworldConfig.new(), i)


func test_still_leader_reached_within_bound_with_custom_config() -> void:
	var cfg := OverworldConfig.new()
	cfg.f_chase = 0.7
	cfg.body_radius = 0.35
	for i in 3:
		_assert_reached(cfg, i)


func test_offset_is_perpendicular_to_own_vector() -> void:
	for cfg: OverworldConfig in [OverworldConfig.new(), _radius_cfg()]:
		var grid := _grid()
		var spots: Array[Vector2] = [Vector2(4.5, 5.5), Vector2(8.5, 1.5), Vector2(11.5, 9.5)]
		for i in 3:
			var brain := SymbolBrain.new(PackedVector2Array([spots[i]]), SymbolBrain.PathMode.LOOP, i)
			var target: Vector2 = brain.chase_target(_LEADER, grid, cfg)
			var off: Vector2 = target - _LEADER
			var expected: float = absf(float(posmod(i, 3) - 1)) * cfg.body_radius
			assert_float(off.length()).is_equal_approx(expected, 1e-5)
			assert_float(off.dot(_LEADER - spots[i])).is_equal_approx(0.0, 1e-5)


func test_offset_dropped_when_off_legal_cell() -> void:
	var cfg := OverworldConfig.new()
	var grid := _grid()
	for x in _GRID_SIZE.x:
		grid.cells[4 * _GRID_SIZE.x + x] = 0  # Wall row y = 4.
	var leader := Vector2(6.5, 5.1)
	var spot := Vector2(2.5, 5.1)
	var down := SymbolBrain.new(PackedVector2Array([spot]), SymbolBrain.PathMode.LOOP, 0)
	var up := SymbolBrain.new(PackedVector2Array([spot]), SymbolBrain.PathMode.LOOP, 2)
	# One offset lands on a legal cell, the other in the wall: dropped.
	var t_down: Vector2 = down.chase_target(leader, grid, cfg)
	var t_up: Vector2 = up.chase_target(leader, grid, cfg)
	assert_float(t_down.distance_to(leader)).is_equal_approx(cfg.body_radius, 1e-5)
	assert_vector(t_up).is_equal(leader)


func test_nearest_cell_ties_go_to_lowest_index() -> void:
	var grid := _grid()
	var c := Vector2i(5, 5)
	grid.cells[c.y * _GRID_SIZE.x + c.x] = 0
	var centre: Vector2 = grid.cell_center(c)
	# Four orthogonal neighbours tie at half a cell: (5, 4) has the lowest index.
	assert_vector(SymbolBrain.nearest_legal_cell(grid, centre)).is_equal(Vector2i(5, 4))
	grid.cells[4 * _GRID_SIZE.x + 5] = 0
	assert_vector(SymbolBrain.nearest_legal_cell(grid, centre)).is_equal(Vector2i(4, 5))


func _assert_reached(cfg: OverworldConfig, marker: int) -> void:
	var grid := _grid()
	var brain := SymbolBrain.new(PackedVector2Array([Vector2(5.5, 5.5)]), SymbolBrain.PathMode.LOOP, marker)
	brain.facing = SymbolBrain.Facing.NE
	var guard: int = 1000
	while brain.sub_state != SymbolBrain.SubState.CHASING and guard > 0:
		brain.step(_DT, _LEADER, grid, false, cfg)
		guard -= 1
	var path_dist0: float = brain.path_dist(_LEADER)
	var bound: float = path_dist0 / cfg.v_chase() + 2.0 * _DT
	var t: float = 0.0
	while brain.position.distance_to(_LEADER) > 2.0 * cfg.body_radius and t <= bound + 1.0:
		brain.step(_DT, _LEADER, grid, false, cfg)
		t += _DT
	assert_float(t).is_less_equal(bound)


func _radius_cfg() -> OverworldConfig:
	var cfg := OverworldConfig.new()
	cfg.body_radius = 0.35
	return cfg


func _grid() -> WalkGrid:
	var grid := WalkGrid.new()
	grid.size = _GRID_SIZE
	grid.cell_m = 1.0
	grid.cells.resize(_GRID_SIZE.x * _GRID_SIZE.y)
	grid.cells.fill(WalkGrid.FLAG_WALKABLE)
	return grid
