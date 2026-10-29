## Story 032 (AC-10b, GDD rule 5 "Path distance" and "Give-up test"): in a
## switchback the straight-line distance stays under `symbol_giveup_m`, but
## `path_dist` (recomputed from the stored path every frame) exceeds it from
## `t0`; the symbol is still Chasing at `t0 + giveup_s - dt` and Returning
## at `t0 + giveup_s + dt`, with `giveup_s / dt` not whole.
extends GdUnitTestSuite

const _GRID_SIZE: Vector2i = Vector2i(22, 12)
## Wall along row `_WALL_Y`, from x 0 to `_GAP_X - 1`.
const _WALL_Y: int = 6
const _GAP_X: int = 19
const _SYMBOL: Vector2 = Vector2(3.5, 4.5)
const _LEADER_A: Vector2 = Vector2(5.5, 4.5)
## Across the wall: close in a straight line, ~25 m by the route.
const _LEADER_B: Vector2 = Vector2(6.5, 8.5)


func test_switchback_gives_up_on_path_dist() -> void:
	_assert_giveup(OverworldConfig.new(), 0.017)


func test_switchback_gives_up_on_path_dist_with_custom_config() -> void:
	var cfg := OverworldConfig.new()
	cfg.giveup_s = 2.0
	cfg.symbol_giveup_m = 7.0
	_assert_giveup(cfg, 0.017)


func _assert_giveup(cfg: OverworldConfig, dt: float) -> void:
	assert_float(fmod(cfg.giveup_s / dt, 1.0)).is_not_equal(0.0)
	var grid := _grid()
	var brain := SymbolBrain.new(PackedVector2Array([_SYMBOL]), SymbolBrain.PathMode.LOOP, 1)
	brain.facing = SymbolBrain.Facing.SE
	# Notice A, chase it past `repath_s`, then the leader crosses the wall.
	var t: float = 0.0
	while t < cfg.notice_delay_s + cfg.repath_s + dt:
		brain.step(dt, _LEADER_A, grid, false, cfg)
		t += dt
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.CHASING)
	var k0: int = -1
	var k: int = 0
	var chasing_until: int = -1
	var returning_from: int = -1
	while k < 1000:
		k += 1
		brain.step(dt, _LEADER_B, grid, false, cfg)
		if k0 < 0 and brain.path_dist(_LEADER_B) > cfg.symbol_giveup_m:
			k0 = k
			chasing_until = k0 + floori((cfg.giveup_s - dt) / dt)
			returning_from = k0 + ceili((cfg.giveup_s + dt) / dt)
		if k0 < 0:
			continue
		if k <= chasing_until:
			assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.CHASING)
			# Straight line never reaches the give-up distance; the route does.
			assert_float(brain.position.distance_to(_LEADER_B)).is_less(cfg.symbol_giveup_m)
			assert_float(brain.path_dist(_LEADER_B)).is_greater(cfg.symbol_giveup_m)
		if k == returning_from:
			assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.RETURNING)
			break
	assert_int(k0).is_greater(0)
	assert_int(k).is_equal(returning_from)


func _grid() -> WalkGrid:
	var grid := WalkGrid.new()
	grid.size = _GRID_SIZE
	grid.cell_m = 1.0
	grid.cells.resize(_GRID_SIZE.x * _GRID_SIZE.y)
	grid.cells.fill(WalkGrid.FLAG_WALKABLE)
	for x in _GAP_X:
		grid.cells[_WALL_Y * _GRID_SIZE.x + x] = 0
	return grid
