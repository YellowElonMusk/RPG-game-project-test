## Story 031 (AC-10a, GDD rule 5 Chasing row): a chasing symbol moves at
## `v_chase`; it repaths at most once per `repath_s`, never while the target
## cell is unchanged and no `set_blocked` call happened; and notice queries
## plus repaths never exceed `repath_per_frame_max` on any frame.
extends GdUnitTestSuite

const _DT: float = 1.0 / 60.0
const _GRID_SIZE: Vector2i = Vector2i(24, 9)
const _SYMBOL: Vector2 = Vector2(2.5, 4.5)
const _LEADER_START: Vector2 = Vector2(5.0, 4.5)
const _WINDOW_S: float = 2.0


func test_chase_moves_at_v_chase() -> void:
	_assert_speed(OverworldConfig.new())


func test_chase_moves_at_v_chase_with_custom_config() -> void:
	_assert_speed(_custom_cfg())


func test_static_target_never_repaths() -> void:
	var cfg := OverworldConfig.new()
	var grid := _grid()
	var brain := _chasing_brain(grid, cfg, _LEADER_START)
	var before: int = grid.query_count
	var t: float = 0.0
	while t < _WINDOW_S:
		brain.step(_DT, _LEADER_START, grid, false, cfg)
		t += _DT
	assert_int(brain.repaths_run).is_equal(0)
	assert_int(grid.query_count).is_equal(before)


func test_moving_target_repaths_at_most_once_per_repath_s() -> void:
	_assert_throttle(OverworldConfig.new())


func test_moving_target_repaths_at_most_once_per_repath_s_with_custom_config() -> void:
	_assert_throttle(_custom_cfg())


## One chaser and three Patrol symbols the leader walks past, on one budget.
func test_notice_plus_repath_never_exceed_budget_per_frame() -> void:
	var cfg := OverworldConfig.new()
	cfg.repath_per_frame_max = 1
	var grid := _grid()
	var chaser := _chasing_brain(grid, cfg, _LEADER_START)
	var patrols: Array[SymbolBrain] = []
	for x: float in [9.5, 11.5, 13.5]:
		var b := SymbolBrain.new(PackedVector2Array([Vector2(x, 2.5)]), SymbolBrain.PathMode.LOOP, 1)
		b.facing = SymbolBrain.Facing.SE
		patrols.append(b)
	var budget := QueryBudget.new(cfg.repath_per_frame_max)
	var leader: Vector2 = _LEADER_START
	var t: float = 0.0
	var noticed: int = 0
	while t < 3.0:
		leader.x += cfg.walk_speed * _DT
		var before: int = grid.query_count
		budget.begin_frame()
		chaser.step(_DT, leader, grid, false, cfg, budget)
		for b in patrols:
			b.step(_DT, leader, grid, false, cfg, budget)
		assert_int(grid.query_count - before).is_less_equal(cfg.repath_per_frame_max)
		t += _DT
	for b in patrols:
		if b.sub_state != SymbolBrain.SubState.PATROL:
			noticed += 1
	assert_int(noticed).is_greater(0)
	assert_int(chaser.repaths_run).is_greater(0)


func _assert_speed(cfg: OverworldConfig) -> void:
	var grid := _grid()
	var brain := _chasing_brain(grid, cfg, _LEADER_START)
	var leader: Vector2 = _LEADER_START
	var start: Vector2 = brain.position
	var sum_dt: float = 0.0
	while sum_dt < _WINDOW_S:
		leader.x += cfg.walk_speed * _DT
		brain.step(_DT, leader, grid, false, cfg)
		assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.CHASING)
		sum_dt += _DT
	assert_float(brain.position.distance_to(start)).is_equal_approx(cfg.v_chase() * sum_dt, 1e-4)


func _assert_throttle(cfg: OverworldConfig) -> void:
	var grid := _grid()
	var brain := _chasing_brain(grid, cfg, _LEADER_START)
	var leader: Vector2 = _LEADER_START
	var t: float = 0.0
	var last_repath_t: float = -INF
	var count: int = brain.repaths_run
	while t < _WINDOW_S:
		leader.x += cfg.walk_speed * _DT
		brain.step(_DT, leader, grid, false, cfg)
		t += _DT
		if brain.repaths_run > count:
			assert_int(brain.repaths_run - count).is_equal(1)
			assert_float(t - last_repath_t).is_greater_equal(cfg.repath_s - 1e-9)
			last_repath_t = t
			count = brain.repaths_run
	assert_int(count).is_greater_equal(floori(_WINDOW_S / (cfg.repath_s + _DT)) - 1)


## A brain that noticed `leader` and has just entered Chasing (stepped
## unbudgeted through `notice_delay_s`, leader still).
func _chasing_brain(grid: WalkGrid, cfg: OverworldConfig, leader: Vector2) -> SymbolBrain:
	var brain := SymbolBrain.new(PackedVector2Array([_SYMBOL]), SymbolBrain.PathMode.LOOP, 1)
	brain.facing = SymbolBrain.Facing.SE
	var guard: int = 1000
	while brain.sub_state != SymbolBrain.SubState.CHASING and guard > 0:
		brain.step(_DT, leader, grid, false, cfg)
		guard -= 1
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.CHASING)
	return brain


func _custom_cfg() -> OverworldConfig:
	var cfg := OverworldConfig.new()
	cfg.f_chase = 0.75
	cfg.repath_s = 0.3
	return cfg


func _grid() -> WalkGrid:
	var grid := WalkGrid.new()
	grid.size = _GRID_SIZE
	grid.cell_m = 1.0
	grid.cells.resize(_GRID_SIZE.x * _GRID_SIZE.y)
	grid.cells.fill(WalkGrid.FLAG_WALKABLE)
	return grid
