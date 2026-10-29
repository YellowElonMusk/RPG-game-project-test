## Story 030 (AC-9h, GDD rule 5 notice check 3 and "Query budget"): a leader
## in another symbol-legal component costs zero pathfinder queries; in the
## same component, queries never exceed `repath_per_frame_max` on any frame,
## and a repeated (symbol cell, leader cell) pair is served from the cache.
extends GdUnitTestSuite

const _DT: float = 1.0 / 60.0
const _GRID_SIZE: Vector2i = Vector2i(16, 12)
const _WALL_X: int = 8
const _LEADER: Vector2 = Vector2(9.2, 5.5)
const _SPOTS: Array[Vector2] = [
	Vector2(7.5, 3.5), Vector2(7.5, 4.5), Vector2(7.5, 5.5),
	Vector2(7.5, 6.5), Vector2(7.5, 7.5), Vector2(6.5, 5.5)]


func test_other_component_costs_zero_queries() -> void:
	_assert_zero_queries(OverworldConfig.new())


func test_other_component_costs_zero_queries_with_custom_config() -> void:
	var cfg := OverworldConfig.new()
	cfg.symbol_chase_m = 3.4
	cfg.repath_per_frame_max = 4
	_assert_zero_queries(cfg)


func test_same_component_queries_stay_within_budget() -> void:
	_assert_within_budget(OverworldConfig.new())


func test_same_component_queries_stay_within_budget_with_custom_config() -> void:
	var cfg := OverworldConfig.new()
	cfg.repath_per_frame_max = 1
	_assert_within_budget(cfg)


func test_repeated_cell_pair_is_served_from_cache() -> void:
	var cfg := OverworldConfig.new()
	var grid := _grid()
	# Same component, but the leader is fenced off past the cap, so the
	# brain keeps testing without noticing.
	grid.set_blocked(_wall_cells(_GRID_SIZE.y - 2), true)
	var brain := _brain(Vector2(7.5, 1.5))
	var leader := Vector2(9.5, 1.5)
	var budget := QueryBudget.new(cfg.repath_per_frame_max)
	for i in 3:
		budget.begin_frame()
		brain.step(_DT, leader, grid, false, cfg, budget)
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.PATROL)
	assert_int(grid.query_count).is_equal(1)
	# A `set_blocked` call clears the cache.
	grid.set_blocked([Vector2i(0, _GRID_SIZE.y - 1)], true)
	budget.begin_frame()
	brain.step(_DT, leader, grid, false, cfg, budget)
	assert_int(grid.query_count).is_equal(2)


func _assert_zero_queries(cfg: OverworldConfig) -> void:
	var grid := _grid()
	grid.set_blocked(_wall_cells(_GRID_SIZE.y), true)
	var brains := _brains()
	var budget := QueryBudget.new(cfg.repath_per_frame_max)
	for frame in 60:
		budget.begin_frame()
		for brain in brains:
			brain.step(_DT, _LEADER, grid, false, cfg, budget)
	assert_int(grid.query_count).is_equal(0)
	assert_int(budget.granted_total).is_equal(0)
	for brain in brains:
		# Check 1 passed (leader in radius), check 3 rejected.
		assert_float(brain.position.distance_to(_LEADER)).is_less_equal(cfg.symbol_chase_m)
		assert_int(brain.notice_searches_run).is_equal(0)
		assert_int(brain.notice_tests_run).is_greater(0)
		assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.PATROL)


func _assert_within_budget(cfg: OverworldConfig) -> void:
	var grid := _grid()
	grid.set_blocked(_wall_cells(_GRID_SIZE.y), true)
	grid.set_blocked(_wall_cells(_GRID_SIZE.y), false)
	var brains := _brains()
	var budget := QueryBudget.new(cfg.repath_per_frame_max)
	for frame in 120:
		var before: int = grid.query_count
		budget.begin_frame()
		for brain in brains:
			brain.step(_DT, _LEADER, grid, false, cfg, budget)
		assert_int(grid.query_count - before).is_less_equal(cfg.repath_per_frame_max)
	for brain in brains:
		assert_int(brain.sub_state).is_not_equal(SymbolBrain.SubState.PATROL)


func _brains() -> Array[SymbolBrain]:
	var out: Array[SymbolBrain] = []
	for spot: Vector2 in _SPOTS:
		out.append(_brain(spot))
	return out


func _brain(spot: Vector2) -> SymbolBrain:
	var brain := SymbolBrain.new(PackedVector2Array([spot]), SymbolBrain.PathMode.LOOP, 1)
	brain.facing = SymbolBrain.nearest_facing(_LEADER - spot, -1)
	return brain


func _wall_cells(rows: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in rows:
		out.append(Vector2i(_WALL_X, y))
	return out


func _grid() -> WalkGrid:
	var grid := WalkGrid.new()
	grid.size = _GRID_SIZE
	grid.cell_m = 1.0
	grid.cells.resize(_GRID_SIZE.x * _GRID_SIZE.y)
	grid.cells.fill(WalkGrid.FLAG_WALKABLE)
	return grid
