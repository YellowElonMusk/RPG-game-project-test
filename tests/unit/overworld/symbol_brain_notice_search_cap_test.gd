## Story 029 (AC-9k, GDD rule 5 notice check 4): a leader 3 m away in the
## same component but ~60 m round a wall is never noticed, and the bounded
## search never expands a cell whose route length exceeds
## `notice_path_cap_m`. Cached waypoints and chase targets are per symbol.
extends GdUnitTestSuite

const _DT: float = 1.0 / 60.0
const _GRID_SIZE: Vector2i = Vector2i(20, 33)
const _WALL_X: int = 10
## The wall runs from row 0 to `_GAP_Y - 1`; the gap below keeps one
## component with a ~60 m detour.
const _GAP_Y: int = 30
const _SYMBOL: Vector2 = Vector2(8.5, 1.5)
const _LEADER: Vector2 = Vector2(11.5, 1.5)


func test_search_never_expands_past_cap() -> void:
	_assert_bounded(OverworldConfig.new())


func test_search_never_expands_past_cap_with_custom_config() -> void:
	var cfg := OverworldConfig.new()
	cfg.notice_path_cap_m = 5.0
	cfg.symbol_chase_m = 3.4
	_assert_bounded(cfg)


func test_two_symbols_in_one_cell_keep_their_own_cache_and_target() -> void:
	var cfg := OverworldConfig.new()
	var grid := _grid(false)
	var spot := Vector2(4.5, 4.5)
	var leader := Vector2(6.5, 4.5)
	var a := SymbolBrain.new(PackedVector2Array([spot]), SymbolBrain.PathMode.LOOP, 0)
	var b := SymbolBrain.new(PackedVector2Array([spot]), SymbolBrain.PathMode.LOOP, 2)
	a.step(_DT, leader, grid, false, cfg)
	b.step(_DT, leader, grid, false, cfg)
	assert_int(a.sub_state).is_equal(SymbolBrain.SubState.NOTICING)
	assert_int(b.sub_state).is_equal(SymbolBrain.SubState.NOTICING)
	# Each ran its own search: nothing is shared between brains.
	assert_int(grid.query_count).is_equal(2)
	var ta: Vector2 = a.chase_target(leader, grid, cfg)
	var tb: Vector2 = b.chase_target(leader, grid, cfg)
	assert_float(ta.distance_to(tb)).is_equal_approx(2.0 * cfg.body_radius, 1e-5)


func _assert_bounded(cfg: OverworldConfig) -> void:
	var grid := _grid(true)
	assert_float(_SYMBOL.distance_to(_LEADER)).is_less_equal(cfg.symbol_chase_m)
	# Same component, so check 3 passes and only the cap can reject.
	assert_int(grid.component_of(grid.cell_of(_SYMBOL))) \
			.is_equal(grid.component_of(grid.cell_of(_LEADER)))
	assert_float(grid.bounded_search(grid.cell_of(_SYMBOL), grid.cell_of(_LEADER), 1000.0)) \
			.is_greater(55.0)
	var queries_before: int = grid.query_count
	var brain := SymbolBrain.new(PackedVector2Array([_SYMBOL]), SymbolBrain.PathMode.LOOP)
	brain.facing = SymbolBrain.Facing.SE
	for i in 30:
		brain.step(_DT, _LEADER, grid, false, cfg)
		assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.PATROL)
	assert_int(brain.notice_searches_run).is_equal(30)
	# One real search (the rest came from the cache), and it never expanded
	# a cell past the cap.
	assert_int(grid.query_count - queries_before).is_equal(1)
	assert_int(grid.last_search_expanded).is_greater(0)
	assert_float(grid.last_search_max_expanded_m).is_less_equal(cfg.notice_path_cap_m)


func _grid(walled: bool) -> WalkGrid:
	var grid := WalkGrid.new()
	grid.size = _GRID_SIZE
	grid.cell_m = 1.0
	grid.cells.resize(_GRID_SIZE.x * _GRID_SIZE.y)
	grid.cells.fill(WalkGrid.FLAG_WALKABLE)
	if walled:
		for y in _GAP_Y:
			grid.cells[y * _GRID_SIZE.x + _WALL_X] = 0
	return grid
