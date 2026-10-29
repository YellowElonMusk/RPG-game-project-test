## ADR-0012 §2.3: corner assist is leader-only. `GroundMover.step()` applies
## it only when the caller opts in (`corner_assist = true`, the leader).
extends GdUnitTestSuite

const _WALL_CELL: Vector2i = Vector2i(1, 0)


func test_symbol_default_corner_graze_blocks() -> void:
	_check(OverworldConfig.new(), false)


func test_leader_opt_in_corner_graze_passes() -> void:
	_check(OverworldConfig.new(), true)


func test_symbol_default_corner_graze_blocks_with_custom_config() -> void:
	var cfg := OverworldConfig.new()
	cfg.corner_assist_m = 0.2
	_check(cfg, false)


func _check(cfg: OverworldConfig, assist: bool) -> void:
	var grid := WalkGrid.new()
	grid.cell_m = 1.0
	grid.size = Vector2i(3, 2)
	grid.cells.resize(6)
	for y in range(2):
		for x in range(3):
			grid.cells[y * 3 + x] = 0 if Vector2i(x, y) == _WALL_CELL else WalkGrid.FLAG_WALKABLE
	var overlap: float = cfg.corner_assist_m * 0.5
	var resolved_x: float = 1.0 - (cfg.body_radius - overlap)
	var start := Vector2(resolved_x - 0.3, 1.5)
	var disp := Vector2(0.3, -0.6)
	var r: GroundMover.MoveResult = GroundMover.step(start, disp.normalized(),
			disp.length() / cfg.walk_speed, grid, cfg, cfg.walk_speed, 0, assist) if assist \
			else GroundMover.step(start, disp.normalized(), disp.length() / cfg.walk_speed,
			grid, cfg, cfg.walk_speed, 0)
	assert_bool(r.blocked_y).is_equal(not assist)
	if assist:
		assert_float(r.position.x).is_equal_approx(resolved_x - overlap, 1e-4)
		assert_float(r.position.y).is_equal_approx(start.y - 0.6, 1e-4)
	else:
		assert_float(r.position.y).is_equal_approx(grid.cell_m + cfg.body_radius, 1e-4)
