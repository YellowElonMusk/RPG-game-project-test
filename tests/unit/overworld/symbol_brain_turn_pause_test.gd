## Story 026 (AC-9g, GDD rule 5 Patrol row, Noticing row, Facing clause):
## Noticing turns the facing to the leader (snapped to a displayed
## diagonal); a `pingpong` end and a `loop` vertex turning by more than 90
## degrees hold the symbol still in its look-back pose from arrival through
## `turn_pause_s - dt`, the old facing deciding the half-planes, and the
## facing has flipped by `turn_pause_s + dt`; a 90-degree vertex causes no
## pause; a leader exactly on the dividing line gets the front radius.
extends GdUnitTestSuite

## `turn_pause_s / _DT` is not whole for the default (0.9) or custom (1.2)
## pause (test harness timing rule).
const _DT: float = 0.013
const _POS_TOL: float = 1e-3
const _GRID_SIZE: Vector2i = Vector2i(12, 12)
const _ORIGIN: Vector2 = Vector2(5.5, 5.5)
const _FAR_LEADER: Vector2 = Vector2(-100.0, -100.0)
const _PINGPONG_PATH: Array[Vector2] = [Vector2(2.5, 2.5), Vector2(5.5, 5.5)]
## Turns by 135 degrees at vertex 1.
const _SHARP_LOOP: Array[Vector2] = [Vector2(2.5, 2.5), Vector2(6.5, 6.5), Vector2(6.5, 2.5)]
## Turns by exactly 90 degrees at every vertex.
const _SQUARE_LOOP: Array[Vector2] = [
	Vector2(2.5, 2.5), Vector2(6.5, 2.5), Vector2(6.5, 6.5), Vector2(2.5, 6.5)]


func test_noticing_faces_leader_snapped_to_diagonal() -> void:
	var cfg := OverworldConfig.new()
	var brain := _stationary_brain(SymbolBrain.Facing.NE)
	var offset := Vector2(2.0, 0.5)
	brain.step(_DT, _ORIGIN + offset, _open_grid(), false, cfg)
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.NOTICING)
	assert_int(brain.facing).is_equal(SymbolBrain.Facing.SE)
	assert_int(brain.facing).is_equal(SymbolBrain.nearest_facing(offset, SymbolBrain.Facing.NE))


func test_pingpong_end_pauses_with_old_facing_then_flips() -> void:
	_assert_pause(_default_cfg(), _PINGPONG_PATH, SymbolBrain.PathMode.PINGPONG)


## Formula test harness rule: run once more against a non-default config.
func test_pingpong_end_pauses_with_old_facing_then_flips_with_custom_config() -> void:
	_assert_pause(_custom_cfg(), _PINGPONG_PATH, SymbolBrain.PathMode.PINGPONG)


func test_loop_vertex_over_90_degrees_pauses_then_flips() -> void:
	_assert_pause(_default_cfg(), _SHARP_LOOP, SymbolBrain.PathMode.LOOP)


func test_loop_vertex_over_90_degrees_pauses_then_flips_with_custom_config() -> void:
	_assert_pause(_custom_cfg(), _SHARP_LOOP, SymbolBrain.PathMode.LOOP)


func test_loop_vertex_at_90_degrees_never_pauses() -> void:
	for cfg: OverworldConfig in [_default_cfg(), _custom_cfg()]:
		var brain := SymbolBrain.new(PackedVector2Array(_SQUARE_LOOP), SymbolBrain.PathMode.LOOP)
		var lap: float = 4.0 * _SQUARE_LOOP[0].distance_to(_SQUARE_LOOP[1])
		var frames: int = ceili(1.25 * lap / (cfg.v_patrol() * _DT))
		for i in frames:
			brain.step(_DT, _FAR_LEADER, _open_grid(), false, cfg)
			assert_bool(brain.is_turn_pausing()).is_false()
			assert_float(brain.last_distance_moved).is_equal_approx(cfg.v_patrol() * _DT, 1e-4)


## During the pause the old facing decides the half-planes: a leader in the
## old rear band is ignored until the flip puts it in front.
func test_old_facing_decides_half_planes_during_pause() -> void:
	for cfg: OverworldConfig in [_default_cfg(), _custom_cfg()]:
		var brain := SymbolBrain.new(PackedVector2Array(_PINGPONG_PATH), SymbolBrain.PathMode.PINGPONG)
		var vertex: Vector2 = _PINGPONG_PATH[1]
		var t_arrive: float = _PINGPONG_PATH[0].distance_to(vertex) / cfg.v_patrol()
		var t_flip: float = t_arrive + cfg.turn_pause_s
		var old_front: Vector2 = brain.facing_vector()
		var band: float = 0.5 * (cfg.symbol_notice_rear_m + cfg.symbol_chase_m)
		var leader: Vector2 = _FAR_LEADER
		var noticed_after: bool = false
		for k in range(1, ceili((t_flip + 2.0 * _DT) / _DT) + 1):
			if brain.is_turn_pausing():
				leader = vertex - old_front * band
			brain.step(_DT, leader, _open_grid(), false, cfg)
			var t: float = k * _DT
			if t <= t_flip - _DT:
				assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.PATROL)
			elif t >= t_flip + _DT:
				assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.NOTICING)
				noticed_after = true
		assert_bool(noticed_after).is_true()


func test_leader_on_dividing_line_gets_front_radius() -> void:
	for cfg: OverworldConfig in [OverworldConfig.new(), _custom_cfg()]:
		var brain := _stationary_brain(SymbolBrain.Facing.NE)
		# Perpendicular to NE (1, -1): dot product exactly 0, distance in the
		# band between the rear and front radii.
		var offset := Vector2(2.0, 2.0)
		assert_float(offset.dot(SymbolBrain.DIAGONALS[SymbolBrain.Facing.NE])).is_equal(0.0)
		assert_float(offset.length()).is_greater(cfg.symbol_notice_rear_m)
		assert_float(offset.length()).is_less(cfg.symbol_chase_m)
		brain.step(_DT, _ORIGIN + offset, _open_grid(), false, cfg)
		assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.NOTICING)
		# A hair behind the line, the rear radius applies.
		var behind := _stationary_brain(SymbolBrain.Facing.NE)
		behind.step(_DT, _ORIGIN + Vector2(2.0, 2.01), _open_grid(), false, cfg)
		assert_int(behind.sub_state).is_equal(SymbolBrain.SubState.PATROL)


func _assert_pause(cfg: OverworldConfig, path_arr: Array[Vector2], mode: SymbolBrain.PathMode) -> void:
	var path := PackedVector2Array(path_arr)
	var brain := SymbolBrain.new(path, mode)
	var vertex: Vector2 = path[1]
	var old_facing: SymbolBrain.Facing = brain.facing
	var new_leg: Vector2 = path[2 % path.size()] - vertex if mode == SymbolBrain.PathMode.LOOP \
			else path[0] - vertex
	var new_facing: SymbolBrain.Facing = SymbolBrain.snap_facing(old_facing, new_leg)
	assert_int(new_facing).is_not_equal(old_facing)
	var t_arrive: float = path[0].distance_to(vertex) / cfg.v_patrol()
	var t_flip: float = t_arrive + cfg.turn_pause_s
	var paused_frames: int = 0
	var flipped_checks: int = 0
	for k in range(1, ceili((t_flip + 0.5) / _DT) + 1):
		brain.step(_DT, _FAR_LEADER, _open_grid(), false, cfg)
		var t: float = k * _DT
		if t - _DT >= t_arrive and t <= t_flip - _DT:
			assert_bool(brain.is_turn_pausing()).is_true()
			assert_float(brain.last_distance_moved).is_equal(0.0)
			assert_vector(brain.position).is_equal_approx(vertex, Vector2(_POS_TOL, _POS_TOL))
			assert_int(brain.facing).is_equal(old_facing)
			paused_frames += 1
		elif t >= t_flip + _DT:
			assert_bool(brain.is_turn_pausing()).is_false()
			assert_int(brain.facing).is_equal(new_facing)
			flipped_checks += 1
	assert_int(paused_frames).is_greater(0)
	assert_int(flipped_checks).is_greater(0)


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


func _default_cfg() -> OverworldConfig:
	return OverworldConfig.new()


func _custom_cfg() -> OverworldConfig:
	var cfg := OverworldConfig.new()
	cfg.turn_pause_s = 1.2
	cfg.f_patrol = 0.5
	cfg.symbol_notice_rear_m = 2.0
	cfg.symbol_chase_m = 3.4
	cfg.notice_path_cap_m = 5.0
	return cfg
