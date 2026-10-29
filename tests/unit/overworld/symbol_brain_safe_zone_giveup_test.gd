## Story 036 (AC-11, GDD rule 5 "Give-up test" and rule 12): a chase toward
## a leader who enters a safe zone at `t0` never puts the symbol's centre in
## a `SAFE` cell, never closes to contact range, and gives up on the `SAFE`
## branch: Chasing at `t0 + giveup_s - dt`, Returning at `t0 + giveup_s + dt`.
extends GdUnitTestSuite

## `giveup_s / _DT` is not whole for 1.5 and 2.0.
const _DT: float = 0.017
const _GRID_SIZE: Vector2i = Vector2i(18, 9)
const _SAFE_X: int = 12
const _SYMBOL: Vector2 = Vector2(7.5, 4.5)
const _LEADER_START: Vector2 = Vector2(9.5, 4.5)
const _LEADER_STOP: Vector2 = Vector2(14.5, 4.5)


func test_safe_zone_chase_gives_up_on_schedule() -> void:
	_assert_safe_giveup(OverworldConfig.new())


func test_safe_zone_chase_gives_up_on_schedule_with_custom_config() -> void:
	var cfg := OverworldConfig.new()
	cfg.giveup_s = 2.0
	cfg.f_chase = 0.75
	_assert_safe_giveup(cfg)


func _assert_safe_giveup(cfg: OverworldConfig) -> void:
	assert_float(fmod(cfg.giveup_s / _DT, 1.0)).is_not_equal(0.0)
	var grid := _grid()
	var brain := SymbolBrain.new(PackedVector2Array([_SYMBOL]), SymbolBrain.PathMode.LOOP, 1)
	brain.facing = SymbolBrain.Facing.SE
	var guard: int = 1000
	while brain.sub_state != SymbolBrain.SubState.CHASING and guard > 0:
		brain.step(_DT, _LEADER_START, grid, false, cfg)
		guard -= 1
	var leader: Vector2 = _LEADER_START
	var k: int = 0
	var k0: int = -1
	var chasing_until: int = -1
	var returning_from: int = -1
	while k < 2000:
		k += 1
		leader = leader.move_toward(_LEADER_STOP, cfg.walk_speed * _DT)
		brain.step(_DT, leader, grid, false, cfg)
		assert_bool(grid.is_safe(grid.cell_of(brain.position))).is_false()
		assert_bool(grid.is_symbol_legal(grid.cell_of(brain.position))).is_true()
		# No contact: never within 2 body radii.
		assert_float(brain.position.distance_to(leader)).is_greater(2.0 * cfg.body_radius)
		if k0 < 0 and grid.is_safe(grid.cell_of(leader)):
			k0 = k
			chasing_until = k0 + floori((cfg.giveup_s - _DT) / _DT)
			returning_from = k0 + ceili((cfg.giveup_s + _DT) / _DT)
		if k0 < 0:
			assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.CHASING)
			assert_float(brain.giveup_elapsed()).is_equal(0.0)
			continue
		if k <= chasing_until:
			assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.CHASING)
		if k == returning_from:
			assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.RETURNING)
			break
	assert_int(k).is_equal(returning_from)


func _grid() -> WalkGrid:
	var grid := WalkGrid.new()
	grid.size = _GRID_SIZE
	grid.cell_m = 1.0
	grid.cells.resize(_GRID_SIZE.x * _GRID_SIZE.y)
	grid.cells.fill(WalkGrid.FLAG_WALKABLE)
	for y in _GRID_SIZE.y:
		for x in range(_SAFE_X, _GRID_SIZE.x):
			grid.cells[y * _GRID_SIZE.x + x] = WalkGrid.FLAG_WALKABLE | WalkGrid.FLAG_SAFE
	return grid
