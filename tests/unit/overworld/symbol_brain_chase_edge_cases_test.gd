## Story 037 (AC-12, GDD Edge Cases): an empty chase path with nothing
## pending holds the symbol still and gives up on schedule; a first repath
## deferred by the budget keeps following the notice path with the give-up
## timer off; an unreachable resume point holds the symbol still, deaf,
## with exactly one warning.
extends GdUnitTestSuite

## `giveup_s / _DT` is not whole for 1.5 and 2.0.
const _DT: float = 0.017
const _GRID_SIZE: Vector2i = Vector2i(16, 10)
const _SYMBOL: Vector2 = Vector2(4.5, 4.5)
const _LEADER_A: Vector2 = Vector2(7.2, 4.5)
const _LEADER_B: Vector2 = Vector2(7.5, 6.5)


## A pathfinder stub that can be forced to return `[]`.
class StubGrid extends WalkGrid:
	var force_empty: bool = false

	func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
		if force_empty:
			query_count += 1
			var none: Array[Vector2i] = []
			return none
		return super.find_path(from, to)


func test_empty_path_holds_still_then_gives_up() -> void:
	_assert_empty_path(OverworldConfig.new())


func test_empty_path_holds_still_then_gives_up_with_custom_config() -> void:
	var cfg := OverworldConfig.new()
	cfg.giveup_s = 2.0
	_assert_empty_path(cfg)


func test_deferred_first_repath_follows_notice_path_without_giveup_timer() -> void:
	for cfg: OverworldConfig in [OverworldConfig.new(), _budget_cfg()]:
		var grid := _grid()
		var brain := _chasing_brain(grid, cfg)
		_run_until_repath_due(brain, grid, cfg)
		var budget := QueryBudget.new(cfg.repath_per_frame_max)
		budget.begin_frame()
		for id in 40:
			budget.request(-1 - id)  # Older deferred requests fill the queue.
		var frames: int = 0
		var moved: float = 0.0
		while frames < 10:
			budget.begin_frame()
			brain.step(_DT, _LEADER_B, grid, false, cfg, budget)
			_assert_pending_never_empty(brain)
			assert_bool(brain.is_repath_pending()).is_true()
			assert_float(brain.giveup_elapsed()).is_equal(0.0)
			moved += brain.last_distance_moved
			frames += 1
		assert_int(brain.repaths_run).is_equal(0)
		assert_float(moved).is_greater(0.0)


func test_unreachable_resume_point_holds_still_deaf_with_one_warning() -> void:
	var cfg := OverworldConfig.new()
	var grid := _grid()
	var brain := _chasing_brain(grid, cfg)
	for i in 30:
		brain.step(_DT, _LEADER_A, grid, false, cfg)
	brain.on_grace_started()
	var resume: Vector2i = grid.cell_of(brain.resume_point())
	grid.set_blocked([resume], true)
	var held: Vector2 = brain.position
	var tests_before: int = brain.notice_tests_run
	for i in 200:
		brain.step(_DT, brain.position + Vector2(1.0, 0.0), grid, false, cfg)
		assert_vector(brain.position).is_equal(held)
		assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.RETURNING)
	assert_bool(brain.is_return_stuck()).is_true()
	assert_int(brain.notice_tests_run).is_equal(tests_before)
	assert_int(brain.warnings_logged).is_equal(1)


func _assert_empty_path(cfg: OverworldConfig) -> void:
	var grid := _grid()
	var brain := _chasing_brain(grid, cfg)
	_run_until_repath_due(brain, grid, cfg)
	grid.force_empty = true
	var k: int = 0
	var k0: int = -1
	var chasing_until: int = -1
	var returning_from: int = -1
	while k < 1000:
		k += 1
		brain.step(_DT, _LEADER_B, grid, false, cfg)
		_assert_pending_never_empty(brain)
		if k0 < 0 and brain.has_empty_route():
			k0 = k
			chasing_until = k0 + floori((cfg.giveup_s - _DT) / _DT)
			returning_from = k0 + ceili((cfg.giveup_s + _DT) / _DT)
		if k0 < 0:
			continue
		if k <= chasing_until:
			assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.CHASING)
			if k > k0:
				assert_float(brain.last_distance_moved).is_equal(0.0)
		if k == returning_from:
			assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.RETURNING)
			break
	assert_int(k0).is_equal(1)
	assert_int(k).is_equal(returning_from)


## Shared Edge Cases check: a pending path is never reported empty.
func _assert_pending_never_empty(brain: SymbolBrain) -> void:
	if brain.is_repath_pending():
		assert_bool(brain.has_empty_route()).is_false()


## A brain that noticed `_LEADER_A` and has entered Chasing.
func _chasing_brain(grid: WalkGrid, cfg: OverworldConfig) -> SymbolBrain:
	var brain := SymbolBrain.new(PackedVector2Array([_SYMBOL]), SymbolBrain.PathMode.LOOP, 1)
	brain.facing = SymbolBrain.Facing.SE
	var guard: int = 1000
	while brain.sub_state != SymbolBrain.SubState.CHASING and guard > 0:
		brain.step(_DT, _LEADER_A, grid, false, cfg)
		guard -= 1
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.CHASING)
	return brain


## Steps with the leader still at A until a target change would repath at
## once (the throttle has run out), without any repath so far.
func _run_until_repath_due(brain: SymbolBrain, grid: WalkGrid, cfg: OverworldConfig) -> void:
	var t: float = cfg.notice_delay_s
	while t < cfg.repath_s + _DT:
		brain.step(_DT, _LEADER_A, grid, false, cfg)
		t += _DT
	assert_int(brain.repaths_run).is_equal(0)


func _budget_cfg() -> OverworldConfig:
	var cfg := OverworldConfig.new()
	cfg.repath_per_frame_max = 3
	cfg.repath_s = 0.6
	return cfg


func _grid() -> StubGrid:
	var grid := StubGrid.new()
	grid.size = _GRID_SIZE
	grid.cell_m = 1.0
	grid.cells.resize(_GRID_SIZE.x * _GRID_SIZE.y)
	grid.cells.fill(WalkGrid.FLAG_WALKABLE)
	return grid
