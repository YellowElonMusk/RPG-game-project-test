## Story 025 (AC-9f, GDD rule 5 notice test check 2, rule 12): a leader in a
## `SAFE` cell inside a patrolling symbol's front radius, with a reachable
## path to the cell's edge, is never noticed over 10 s -- at `dt = 1/60`
## and at `dt_max`. Check 2 rejects it before any search runs. The `SAFE`
## bit is set directly on the fixture cell (the bake is story 128's).
extends GdUnitTestSuite

const _GRID_SIZE: Vector2i = Vector2i(12, 12)
const _ORIGIN: Vector2 = Vector2(5.5, 5.5)
const _SIM_S: float = 10.0


func test_safe_cell_leader_is_never_noticed_over_10s() -> void:
	_assert_never_noticed(OverworldConfig.new(), 1.0 / 60.0)
	_assert_never_noticed(OverworldConfig.new(), PresentationConfig.new().follow_camera_dt_max)


## Formula test harness rule: run once more against a non-default config.
func test_safe_cell_leader_is_never_noticed_over_10s_with_custom_config() -> void:
	_assert_never_noticed(_custom_cfg(), 1.0 / 60.0)
	_assert_never_noticed(_custom_cfg(), PresentationConfig.new().follow_camera_dt_max)


## Control: the same placement with the `SAFE` bit cleared is noticed.
func test_same_leader_on_non_safe_cell_is_noticed() -> void:
	var cfg := OverworldConfig.new()
	var brain := _stationary_brain()
	brain.step(1.0 / 60.0, _leader(brain, cfg), _grid(false, Vector2i.ZERO), false, cfg)
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.NOTICING)


func _assert_never_noticed(cfg: OverworldConfig, dt: float) -> void:
	var brain := _stationary_brain()
	var leader: Vector2 = _leader(brain, cfg)
	var safe_cell: Vector2i = Vector2i(floori(leader.x), floori(leader.y))
	var grid := _grid(true, safe_cell)
	assert_bool(grid.is_symbol_legal(safe_cell)).is_false()
	assert_bool(grid.is_safe(grid.cell_of(leader))).is_true()
	# A symbol-legal neighbour of the SAFE cell is within the cap: the route
	# itself is reachable, only the SAFE flag stops the notice.
	var neighbour: Vector2i = safe_cell - Vector2i(1, 0)
	assert_float(grid.bounded_search(grid.cell_of(_ORIGIN), neighbour, cfg.notice_path_cap_m)) \
			.is_less_equal(cfg.notice_path_cap_m)
	var frames: int = ceili(_SIM_S / dt)
	for i in frames:
		brain.step(dt, leader, grid, false, cfg)
		assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.PATROL)
	assert_int(brain.notice_tests_run).is_equal(frames)
	assert_int(brain.notice_searches_run).is_equal(0)


## Front half-plane, half the front radius away.
func _leader(brain: SymbolBrain, cfg: OverworldConfig) -> Vector2:
	return _ORIGIN + brain.facing_vector() * (0.5 * cfg.symbol_chase_m)


func _stationary_brain() -> SymbolBrain:
	var brain := SymbolBrain.new(PackedVector2Array([_ORIGIN]), SymbolBrain.PathMode.LOOP)
	brain.facing = SymbolBrain.Facing.SE
	return brain


## Walkable grid, optionally with `safe_cell` flagged `SAFE`.
func _grid(with_safe: bool, safe_cell: Vector2i) -> WalkGrid:
	var grid := WalkGrid.new()
	grid.size = _GRID_SIZE
	grid.cell_m = 1.0
	grid.cells.resize(_GRID_SIZE.x * _GRID_SIZE.y)
	grid.cells.fill(WalkGrid.FLAG_WALKABLE)
	if with_safe:
		var idx: int = safe_cell.y * _GRID_SIZE.x + safe_cell.x
		grid.cells[idx] = WalkGrid.FLAG_WALKABLE | WalkGrid.FLAG_SAFE
	return grid


func _custom_cfg() -> OverworldConfig:
	var cfg := OverworldConfig.new()
	cfg.symbol_chase_m = 3.4
	cfg.notice_path_cap_m = 5.0
	return cfg
