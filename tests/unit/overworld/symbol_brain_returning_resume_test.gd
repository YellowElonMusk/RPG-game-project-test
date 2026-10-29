## Story 033 (AC-10c, GDD rule 5 Returning row): after give-up the symbol
## walks by A* at `v_patrol` to its stored resume point, then resumes Patrol
## in its earlier direction; it notices nothing until `renotice_cooldown_s`
## after rejoining (asserted at -dt and +dt), and it is never contact
## eligible while Returning, even when the leader walks through it.
extends GdUnitTestSuite

## `renotice_cooldown_s / _DT` is not whole for 3.0 and 2.5.
const _DT: float = 0.013
const _GRID_SIZE: Vector2i = Vector2i(18, 9)
const _SAFE_X: int = 15
const _PATROL: Array[Vector2] = [Vector2(2.5, 2.5), Vector2(10.5, 2.5)]
const _LEADER: Vector2 = Vector2(6.5, 3.5)
const _SAFE_SPOT: Vector2 = Vector2(15.5, 6.5)


func test_returns_to_resume_point_then_patrols_on() -> void:
	_assert_return(OverworldConfig.new())


func test_returns_to_resume_point_then_patrols_on_with_custom_config() -> void:
	var cfg := OverworldConfig.new()
	cfg.renotice_cooldown_s = 2.5
	cfg.f_patrol = 0.5
	_assert_return(cfg)


func _assert_return(cfg: OverworldConfig) -> void:
	var grid := _grid()
	var brain := SymbolBrain.new(PackedVector2Array(_PATROL), SymbolBrain.PathMode.PINGPONG, 1)
	var guard: int = 2000
	while brain.sub_state == SymbolBrain.SubState.PATROL and guard > 0:
		brain.step(_DT, _LEADER, grid, false, cfg)
		guard -= 1
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.NOTICING)
	var resume: Vector2 = brain.resume_point()
	assert_vector(resume).is_equal(brain.position)
	var next_before: int = brain.next_index()
	var dir_before: int = brain.direction()
	# Chase a little, then the leader steps into a safe zone: give-up.
	for i in 60:
		brain.step(_DT, _LEADER, grid, false, cfg)
	guard = 2000
	while brain.sub_state == SymbolBrain.SubState.CHASING and guard > 0:
		brain.step(_DT, _SAFE_SPOT, grid, false, cfg)
		guard -= 1
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.RETURNING)
	# Walk home; the leader walks right through the symbol.
	guard = 2000
	var queries: int = brain.queries_granted
	while brain.sub_state == SymbolBrain.SubState.RETURNING and guard > 0:
		assert_bool(brain.contact_eligible()).is_false()
		var tests_before: int = brain.notice_tests_run
		brain.step(_DT, brain.position, grid, false, cfg)
		assert_int(brain.notice_tests_run).is_equal(tests_before)
		assert_float(brain.last_distance_moved).is_less_equal(cfg.v_patrol() * _DT + 1e-6)
		if brain.sub_state == SymbolBrain.SubState.RETURNING:
			assert_float(brain.last_distance_moved).is_equal_approx(cfg.v_patrol() * _DT, 1e-5)
		guard -= 1
	assert_int(brain.queries_granted - queries).is_equal(1)
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.PATROL)
	assert_float(brain.position.distance_to(resume)).is_less_equal(cfg.waypoint_tol_m)
	assert_int(brain.next_index()).is_equal(next_before)
	assert_int(brain.direction()).is_equal(dir_before)
	# Re-notice cooldown: a leader 1 m in front every frame.
	var k: int = 0
	var saw_late: bool = false
	while k * _DT < cfg.renotice_cooldown_s + 2.0 * _DT:
		k += 1
		var leader: Vector2 = brain.position + brain.facing_vector()
		brain.step(_DT, leader, grid, false, cfg)
		var t: float = k * _DT
		if t <= cfg.renotice_cooldown_s - _DT:
			assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.PATROL)
		elif t >= cfg.renotice_cooldown_s + _DT:
			assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.NOTICING)
			saw_late = true
			break
	assert_bool(saw_late).is_true()


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
