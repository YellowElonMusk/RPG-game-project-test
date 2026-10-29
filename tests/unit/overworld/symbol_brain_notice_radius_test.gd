## Story 022 (AC-9c, GDD rule 5 notice test check 1): the notice radius is
## `symbol_chase_m` across the symbol's front half-plane and
## `symbol_notice_rear_m` across its rear half-plane, centre to centre. A
## leader in the rear band (between the two radii) is rejected at check 1,
## before any search; inside the rear radius it is noticed. Checks 2-4 are
## held eligible (open grid, no `SAFE` cells, short path).
extends GdUnitTestSuite

const _DT: float = 0.013
const _GRID_SIZE: Vector2i = Vector2i(12, 12)
const _ORIGIN: Vector2 = Vector2(5.5, 5.5)


func test_leader_in_rear_band_is_not_noticed_and_no_search_runs() -> void:
	_assert_rear_band_ignored(OverworldConfig.new())


## Formula test harness rule: run once more against a non-default config.
func test_leader_in_rear_band_is_not_noticed_and_no_search_runs_with_custom_config() -> void:
	_assert_rear_band_ignored(_custom_cfg())


func test_leader_inside_rear_radius_is_noticed() -> void:
	_assert_inside_rear_noticed(OverworldConfig.new())


func test_leader_inside_rear_radius_is_noticed_with_custom_config() -> void:
	_assert_inside_rear_noticed(_custom_cfg())


## The same rear-band distance in front is noticed: the split is by facing.
func test_rear_band_distance_in_front_is_noticed() -> void:
	var cfg := OverworldConfig.new()
	var brain := _stationary_brain(SymbolBrain.Facing.SE)
	var d: float = 0.5 * (cfg.symbol_notice_rear_m + cfg.symbol_chase_m)
	brain.step(_DT, _ORIGIN + brain.facing_vector() * d, _open_grid(), false, cfg)
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.NOTICING)


func _assert_rear_band_ignored(cfg: OverworldConfig) -> void:
	var grid := _open_grid()
	var brain := _stationary_brain(SymbolBrain.Facing.SE)
	var d: float = 0.5 * (cfg.symbol_notice_rear_m + cfg.symbol_chase_m)
	var leader: Vector2 = _ORIGIN - brain.facing_vector() * d
	for i in 30:
		brain.step(_DT, leader, grid, false, cfg)
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.PATROL)
	assert_int(brain.notice_tests_run).is_equal(30)
	assert_int(brain.notice_searches_run).is_equal(0)


func _assert_inside_rear_noticed(cfg: OverworldConfig) -> void:
	var brain := _stationary_brain(SymbolBrain.Facing.SE)
	var leader: Vector2 = _ORIGIN - brain.facing_vector() * (0.5 * cfg.symbol_notice_rear_m)
	brain.step(_DT, leader, _open_grid(), false, cfg)
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.NOTICING)
	assert_int(brain.notice_searches_run).is_equal(1)


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
	cfg.symbol_notice_rear_m = 2.0
	cfg.symbol_chase_m = 3.4
	cfg.notice_path_cap_m = 5.0
	return cfg
