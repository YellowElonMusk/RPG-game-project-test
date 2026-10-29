## Story 021 (AC-9b, GDD rule 5 Noticing row): a leader entering the front
## half-plane within `symbol_chase_m`, with a reachable path, puts the
## symbol in Noticing on that frame's step. It is still Noticing at
## `notice_delay_s - dt` and Chasing at `notice_delay_s + dt`, even when the
## leader leaves the radius during the delay. Fixture `WalkGrid` built by
## hand (ADR-0012 Implementation Guidelines).
extends GdUnitTestSuite

## `notice_delay_s / _DT` is not whole for the default (0.4) or custom (0.55)
## delay (test harness timing rule).
const _DT: float = 0.013
const _GRID_SIZE: Vector2i = Vector2i(12, 12)
const _ORIGIN: Vector2 = Vector2(5.5, 5.5)
const _FAR_LEADER: Vector2 = Vector2(-100.0, -100.0)


func test_leader_entering_front_radius_notices_then_chases_after_delay() -> void:
	_assert_delay(OverworldConfig.new(), false)


## Formula test harness rule: run once more against a non-default config.
func test_leader_entering_front_radius_notices_then_chases_after_delay_with_custom_config() -> void:
	_assert_delay(_custom_cfg(), false)


func test_leader_leaving_radius_during_delay_chasing_still_starts() -> void:
	_assert_delay(OverworldConfig.new(), true)


func test_leader_leaving_radius_during_delay_chasing_still_starts_with_custom_config() -> void:
	_assert_delay(_custom_cfg(), true)


## A patrolling (moving) symbol notices on the very frame the leader steps in
## and does not move on that frame.
func test_patrolling_symbol_enters_noticing_on_entry_frame_without_moving() -> void:
	var cfg := OverworldConfig.new()
	var grid := _open_grid()
	var path := PackedVector2Array([Vector2(1.5, 5.5), Vector2(10.5, 5.5)])
	var brain := SymbolBrain.new(path, SymbolBrain.PathMode.PINGPONG)
	for i in 20:
		brain.step(_DT, _FAR_LEADER, grid, false, cfg)
		assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.PATROL)
	var before: Vector2 = brain.position
	var leader: Vector2 = before + brain.facing_vector() * (0.5 * cfg.symbol_chase_m)
	brain.step(_DT, leader, grid, false, cfg)
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.NOTICING)
	assert_vector(brain.position).is_equal(before)
	assert_float(brain.last_distance_moved).is_equal(0.0)


func _assert_delay(cfg: OverworldConfig, leader_leaves: bool) -> void:
	var grid := _open_grid()
	var brain := _stationary_brain(SymbolBrain.Facing.SE)
	brain.step(_DT, _FAR_LEADER, grid, false, cfg)
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.PATROL)
	# Front half-plane, half the front radius away: noticed on this frame.
	var leader: Vector2 = _ORIGIN + brain.facing_vector() * (0.5 * cfg.symbol_chase_m)
	brain.step(_DT, leader, grid, false, cfg)
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.NOTICING)
	var delay: float = cfg.notice_delay_s
	var frames: int = ceili((delay + 2.0 * _DT) / _DT)
	var saw_late_check: bool = false
	for k in range(1, frames + 1):
		if leader_leaves:
			leader = _FAR_LEADER
		brain.step(_DT, leader, grid, false, cfg)
		assert_float(brain.last_distance_moved).is_equal(0.0)
		var t: float = k * _DT
		if t <= delay - _DT:
			assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.NOTICING)
		elif t >= delay + _DT:
			assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.CHASING)
			saw_late_check = true
	assert_bool(saw_late_check).is_true()


func _stationary_brain(facing: SymbolBrain.Facing) -> SymbolBrain:
	var brain := SymbolBrain.new(PackedVector2Array([_ORIGIN]), SymbolBrain.PathMode.LOOP)
	brain.facing = facing
	return brain


## Fully walkable fixture grid, no `SAFE` cells.
func _open_grid() -> WalkGrid:
	var grid := WalkGrid.new()
	grid.size = _GRID_SIZE
	grid.cell_m = 1.0
	grid.cells.resize(_GRID_SIZE.x * _GRID_SIZE.y)
	grid.cells.fill(WalkGrid.FLAG_WALKABLE)
	return grid


func _custom_cfg() -> OverworldConfig:
	var cfg := OverworldConfig.new()
	cfg.notice_delay_s = 0.55
	cfg.symbol_chase_m = 3.4
	cfg.notice_path_cap_m = 5.0
	return cfg
