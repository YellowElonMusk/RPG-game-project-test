## Story 101, AC-40b (GDD Formulas `symbol_speeds`): on open ground, with a
## chase starting at `d0 = 2*body_radius + 0.05` m and the leader walking
## straight away at `walk_speed`, the symbol is still Chasing at
## `t_escape(d0) - dt` and Returning at `t_escape(d0) + dt`.
extends GdUnitTestSuite

const _GRID_SIZE: Vector2i = Vector2i(60, 9)
const _SYMBOL: Vector2 = Vector2(4.5, 4.5)


func test_the_chase_ends_at_t_escape(dt: float, test_parameters := [[1.0 / 60.0], [0.017], [0.05]]) -> void:
	var cfg := OverworldConfig.new()
	var d0: float = 2.0 * cfg.body_radius + 0.05
	var t_escape: float = cfg.t_escape(d0)
	var grid := _open_grid()
	# marker_index 1: no sideways chase-target offset (GDD rule 5), which the
	# open-ground formula does not model.
	var brain := SymbolBrain.new(PackedVector2Array([_SYMBOL]), SymbolBrain.PathMode.LOOP, 1)
	brain.facing = SymbolBrain.Facing.SE
	# The leader stands d0 east of the symbol while it notices.
	var leader: Vector2 = _SYMBOL + Vector2(d0, 0.0)
	var frames: int = 0
	while brain.sub_state != SymbolBrain.SubState.CHASING and frames < 200:
		brain.step(dt, leader, grid, false, cfg)
		frames += 1
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.CHASING)
	assert_float(brain.position.distance_to(leader)).is_equal_approx(d0, 1e-4)
	# From the chase's start (t = 0) the leader walks straight east.
	var t: float = 0.0
	var state_before: int = -1
	var state_after: int = -1
	while t < t_escape + 2.0 * dt:
		leader += Vector2(cfg.walk_speed * dt, 0.0)
		brain.step(dt, leader, grid, false, cfg)
		t += dt
		if state_before < 0 and t >= t_escape - dt:
			state_before = brain.sub_state
		if state_after < 0 and t >= t_escape + dt:
			state_after = brain.sub_state
	assert_int(state_before).override_failure_message("dt %.4f: not Chasing at t_escape - dt" % dt) \
			.is_equal(SymbolBrain.SubState.CHASING)
	assert_int(state_after).override_failure_message("dt %.4f: not Returning at t_escape + dt" % dt) \
			.is_equal(SymbolBrain.SubState.RETURNING)


func _open_grid() -> WalkGrid:
	var grid := WalkGrid.new()
	grid.size = _GRID_SIZE
	grid.cell_m = 1.0
	grid.cells.resize(_GRID_SIZE.x * _GRID_SIZE.y)
	grid.cells.fill(WalkGrid.FLAG_WALKABLE)
	return grid
