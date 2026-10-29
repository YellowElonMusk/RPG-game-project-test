## Story 023 (AC-9d, GDD rule 5 notice test check 4): a leader inside the
## front notice radius but behind a fence, in the same symbol-legal
## component yet with no route within `notice_path_cap_m`, is never noticed
## over 10 s -- at `dt = 1/60` and at `dt_max`. Checks 1-3 pass in the
## fixture, so the bounded search is what rejects it every frame. Also pins
## `WalkGrid.bounded_search()` route lengths on an open grid.
extends GdUnitTestSuite

const _GRID_SIZE: Vector2i = Vector2i(12, 14)
const _FENCE_X: int = 4
## The fence runs from row 0 to row `_FENCE_GAP_Y - 1`; the gap below it
## keeps both sides in one component but makes the detour far longer than
## any cap in the safe range.
const _FENCE_GAP_Y: int = 11
const _SYMBOL: Vector2 = Vector2(3.5, 2.5)
const _LEADER: Vector2 = Vector2(5.5, 2.5)
const _SIM_S: float = 10.0


func test_fenced_leader_is_never_noticed_over_10s() -> void:
	_assert_never_noticed(OverworldConfig.new(), 1.0 / 60.0)
	_assert_never_noticed(OverworldConfig.new(), PresentationConfig.new().follow_camera_dt_max)


## Formula test harness rule: run once more against a non-default config.
func test_fenced_leader_is_never_noticed_over_10s_with_custom_config() -> void:
	_assert_never_noticed(_custom_cfg(), 1.0 / 60.0)
	_assert_never_noticed(_custom_cfg(), PresentationConfig.new().follow_camera_dt_max)


## Control: the same placement without the fence is noticed at once, so the
## fixture really does isolate check 4.
func test_same_leader_without_fence_is_noticed() -> void:
	var cfg := OverworldConfig.new()
	var brain := _stationary_brain()
	brain.step(1.0 / 60.0, _LEADER, _grid(false), false, cfg)
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.NOTICING)


func test_bounded_search_returns_route_length_within_cap() -> void:
	var grid := _grid(false)
	assert_float(grid.bounded_search(Vector2i(0, 0), Vector2i(3, 0), 10.0)).is_equal_approx(3.0, 1e-6)
	assert_float(grid.bounded_search(Vector2i(0, 0), Vector2i(2, 2), 10.0)) \
			.is_equal_approx(2.0 * sqrt(2.0), 1e-6)


func test_bounded_search_beyond_cap_returns_inf() -> void:
	var grid := _grid(false)
	assert_float(grid.bounded_search(Vector2i(0, 0), Vector2i(5, 0), 4.5)).is_equal(INF)
	# Through the fence's gap the route exists but is far past the cap.
	var fenced := _grid(true)
	var from: Vector2i = fenced.cell_of(_SYMBOL)
	var to: Vector2i = fenced.cell_of(_LEADER)
	assert_float(fenced.bounded_search(from, to, 4.5)).is_equal(INF)
	assert_float(fenced.bounded_search(from, to, 100.0)).is_greater(4.5)


func _assert_never_noticed(cfg: OverworldConfig, dt: float) -> void:
	var grid := _grid(true)
	var brain := _stationary_brain()
	# Check 1 passes: front half-plane, inside `symbol_chase_m`.
	assert_float(_SYMBOL.distance_to(_LEADER)).is_less(cfg.symbol_chase_m)
	var frames: int = ceili(_SIM_S / dt)
	for i in frames:
		brain.step(dt, _LEADER, grid, false, cfg)
		assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.PATROL)
	# The search ran (and failed) every frame: checks 1-3 never rejected.
	assert_int(brain.notice_searches_run).is_equal(frames)


func _stationary_brain() -> SymbolBrain:
	var brain := SymbolBrain.new(PackedVector2Array([_SYMBOL]), SymbolBrain.PathMode.LOOP)
	brain.facing = SymbolBrain.Facing.SE
	return brain


## Walkable grid, optionally with a fence column at `_FENCE_X` from row 0 to
## row `_FENCE_GAP_Y - 1`.
func _grid(fenced: bool) -> WalkGrid:
	var grid := WalkGrid.new()
	grid.size = _GRID_SIZE
	grid.cell_m = 1.0
	grid.cells.resize(_GRID_SIZE.x * _GRID_SIZE.y)
	grid.cells.fill(WalkGrid.FLAG_WALKABLE)
	if fenced:
		for y in _FENCE_GAP_Y:
			grid.cells[y * _GRID_SIZE.x + _FENCE_X] = 0
	return grid


func _custom_cfg() -> OverworldConfig:
	var cfg := OverworldConfig.new()
	cfg.notice_path_cap_m = 5.0
	cfg.symbol_chase_m = 3.4
	return cfg
