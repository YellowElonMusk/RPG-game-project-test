## Story 027 (AC-9i, GDD rule 5 Facing clause): a symbol moving exactly
## along a screen axis (between two diagonals) with +-1e-6 noise for 10 s
## never changes facing, at `dt = 1/60` and at `dt_max`; a stopped symbol
## (turn pause, Noticing, Stunned) keeps its facing; the facing changes only
## past 45 + 5 degrees from the current diagonal. Unrelated to story 009's
## arc-length follower hysteresis.
extends GdUnitTestSuite

const _SIM_S: float = 10.0
const _NOISE: float = 1e-6
## Just inside / just outside the hysteresis band edge, in degrees.
const _EDGE_EPS_DEG: float = 0.01
const _LONG_GRID: Vector2i = Vector2i(32, 5)
const _GRID_SIZE: Vector2i = Vector2i(12, 12)
const _ORIGIN: Vector2 = Vector2(5.5, 5.5)


func test_axis_heading_with_noise_never_changes_facing() -> void:
	for dt: float in _dts():
		for axis: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
			var facing: SymbolBrain.Facing = SymbolBrain.nearest_facing(axis, -1)
			var start: SymbolBrain.Facing = facing
			var perp: Vector2 = axis.orthogonal()
			for k in ceili(_SIM_S / dt):
				var noise: float = _NOISE if k % 2 == 0 else -_NOISE
				facing = SymbolBrain.snap_facing(facing, axis + perp * noise)
				assert_int(facing).is_equal(start)


## The same noise through a moving brain: a patrol polyline along the
## screen x axis whose vertices alternate by +-1e-6 m.
func test_patrol_along_axis_with_noisy_vertices_never_changes_facing() -> void:
	for cfg: OverworldConfig in [OverworldConfig.new(), _custom_cfg()]:
		for dt: float in _dts():
			var path := PackedVector2Array()
			for i in _LONG_GRID.x - 2:
				var noise: float = _NOISE if i % 2 == 0 else -_NOISE
				path.append(Vector2(1.5 + i, 2.5 + noise))
			assert_float(cfg.v_patrol() * _SIM_S).is_less(path[0].distance_to(path[path.size() - 1]))
			var brain := SymbolBrain.new(path, SymbolBrain.PathMode.LOOP)
			var start: SymbolBrain.Facing = brain.facing
			var grid := _grid(_LONG_GRID)
			for k in ceili(_SIM_S / dt):
				brain.step(dt, Vector2(-100.0, -100.0), grid, false, cfg)
				assert_float(brain.last_distance_moved).is_greater(0.0)
				assert_int(brain.facing).is_equal(start)


func test_facing_changes_only_past_45_plus_5_degrees() -> void:
	var edge: float = 45.0 + SymbolBrain.FACING_HYSTERESIS_DEG
	for i in SymbolBrain.DIAGONALS.size():
		var current := i as SymbolBrain.Facing
		var base: float = SymbolBrain.DIAGONALS[i].angle()
		for side: float in [1.0, -1.0]:
			var inside := Vector2.from_angle(base + side * deg_to_rad(edge - _EDGE_EPS_DEG))
			assert_int(SymbolBrain.snap_facing(current, inside)).is_equal(current)
			var outside := Vector2.from_angle(base + side * deg_to_rad(edge + _EDGE_EPS_DEG))
			var flipped: SymbolBrain.Facing = SymbolBrain.snap_facing(current, outside)
			assert_int(flipped).is_not_equal(current)
			assert_int(flipped).is_equal(SymbolBrain.nearest_facing(outside, current))


func test_zero_direction_keeps_facing() -> void:
	for i in SymbolBrain.DIAGONALS.size():
		assert_int(SymbolBrain.snap_facing(i as SymbolBrain.Facing, Vector2.ZERO)).is_equal(i)


func test_stunned_symbol_keeps_facing() -> void:
	var cfg := OverworldConfig.new()
	var brain := _patrolling_brain()
	brain.sub_state = SymbolBrain.SubState.STUNNED
	var start: SymbolBrain.Facing = brain.facing
	for k in ceili(_SIM_S / (1.0 / 60.0)):
		brain.step(1.0 / 60.0, _circling_leader(k), _grid(_GRID_SIZE), false, cfg)
		assert_int(brain.facing).is_equal(start)


func test_noticing_symbol_keeps_entry_facing() -> void:
	var cfg := OverworldConfig.new()
	var brain := SymbolBrain.new(PackedVector2Array([_ORIGIN]), SymbolBrain.PathMode.LOOP)
	brain.facing = SymbolBrain.Facing.SE
	brain.step(1.0 / 60.0, _ORIGIN + brain.facing_vector(), _grid(_GRID_SIZE), false, cfg)
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.NOTICING)
	var entry: SymbolBrain.Facing = brain.facing
	var k: int = 0
	while brain.sub_state == SymbolBrain.SubState.NOTICING:
		k += 1
		brain.step(1.0 / 60.0, _circling_leader(k), _grid(_GRID_SIZE), false, cfg)
		assert_int(brain.facing).is_equal(entry)
	assert_int(k).is_greater(1)


func test_turn_pause_keeps_facing() -> void:
	var cfg := OverworldConfig.new()
	var brain := SymbolBrain.new(
			PackedVector2Array([Vector2(2.5, 2.5), Vector2(5.5, 5.5)]), SymbolBrain.PathMode.PINGPONG)
	var paused_frames: int = 0
	var total_paused: int = 0
	var entry: SymbolBrain.Facing = brain.facing
	for k in ceili(_SIM_S / (1.0 / 60.0)):
		var was_paused: bool = brain.is_turn_pausing()
		if was_paused:
			entry = brain.facing if paused_frames == 0 else entry
		brain.step(1.0 / 60.0, Vector2(-100.0, -100.0), _grid(_GRID_SIZE), false, cfg)
		if was_paused and brain.is_turn_pausing():
			assert_int(brain.facing).is_equal(entry)
			paused_frames += 1
			total_paused += 1
		elif not brain.is_turn_pausing():
			paused_frames = 0
	assert_int(total_paused).is_greater(0)
	# TODO(overworld): "contact pending" has no sub-state yet (contact story).


func _circling_leader(k: int) -> Vector2:
	return _ORIGIN + Vector2.from_angle(k * 0.37) * 2.0


func _patrolling_brain() -> SymbolBrain:
	return SymbolBrain.new(
			PackedVector2Array([Vector2(2.5, 2.5), Vector2(8.5, 2.5)]), SymbolBrain.PathMode.PINGPONG)


func _dts() -> Array[float]:
	return [1.0 / 60.0, PresentationConfig.new().follow_camera_dt_max]


func _grid(size: Vector2i) -> WalkGrid:
	var grid := WalkGrid.new()
	grid.size = size
	grid.cell_m = 1.0
	grid.cells.resize(size.x * size.y)
	grid.cells.fill(WalkGrid.FLAG_WALKABLE)
	return grid


func _custom_cfg() -> OverworldConfig:
	var cfg := OverworldConfig.new()
	cfg.f_patrol = 0.5
	cfg.walk_speed = 3.1
	return cfg
