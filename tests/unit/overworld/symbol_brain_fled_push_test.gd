## Story 044, AC-19a: Fled stuns a non-Static symbol in `on_thawed` and
## pushes it along the leader-to-symbol line by `flee_push_m` in 4-connected
## cell steps, less when a non-symbol-legal cell comes first; the leader
## never moves (GDD rule 7, Edge Cases flee push).
extends GdUnitTestSuite

const _ENC: String = "enc_fixture_clerk"


func test_fled_stuns_and_pushes_full_distance_default_config() -> void:
	_assert_full_push(OverworldConfig.new(), Vector2(3.5, 5.5), Vector2(4.0, 5.5))


func test_fled_push_diagonal_line_custom_config() -> void:
	var cfg := OverworldConfig.new()
	cfg.flee_push_m = 1.5
	cfg.body_radius = 0.25
	_assert_full_push(cfg, Vector2(5.0, 5.0), Vector2(5.3, 5.4))


func test_push_stops_before_first_illegal_cell() -> void:
	for cfg: OverworldConfig in [OverworldConfig.new(), _custom()]:
		var grid: WalkGrid = ContactFixture.open_grid()
		var wall: Array[Vector2i] = []
		for y in grid.size.y:
			wall.append(Vector2i(5, y))
		grid.set_blocked(wall, true)
		var sym := Vector2(4.0, 5.5)
		var b := SymbolBrain.new(PackedVector2Array([sym]), SymbolBrain.PathMode.LOOP)
		b.on_fled(Vector2(3.5, 5.5), Vector2.RIGHT, grid, cfg)
		var expected: float = maxf(0.0, (5.0 * grid.cell_m - sym.x) - cfg.body_radius)
		assert_float(b.position.x - sym.x).is_equal_approx(expected, 1e-5)
		assert_float(b.position.x - sym.x).is_less(cfg.flee_push_m)
		assert_bool(grid.is_symbol_legal(grid.cell_of(b.position))).is_true()
		assert_int(b.sub_state).is_equal(SymbolBrain.SubState.STUNNED)


func test_corner_never_hopped_diagonally() -> void:
	# A 45-degree line through the exact corner (5, 4) with cell (5, 4)
	# blocked: the x neighbour is tried first (4-connected), so the push
	# stops there instead of hopping to (5, 3) diagonally.
	var grid: WalkGrid = ContactFixture.open_grid()
	var blocked: Array[Vector2i] = [Vector2i(5, 4), Vector2i(4, 3)]
	grid.set_blocked(blocked, true)
	var crossed: Array[Vector2i] = []
	var cfg := OverworldConfig.new()
	SymbolBrain.push_distance(grid, Vector2(4.5, 4.5), Vector2(1, -1).normalized(),
			cfg.flee_push_m, cfg.body_radius, crossed)
	assert_array(crossed).is_equal([Vector2i(4, 4)])


func test_static_symbol_never_pushed() -> void:
	var cfg := OverworldConfig.new()
	var b := SymbolBrain.new(PackedVector2Array([Vector2(4.0, 5.5)]), SymbolBrain.PathMode.LOOP)
	b.sub_state = SymbolBrain.SubState.STATIC
	b.on_fled(Vector2(3.5, 5.5), Vector2.RIGHT, ContactFixture.open_grid(), cfg)
	assert_vector(b.position).is_equal(Vector2(4.0, 5.5))
	assert_int(b.sub_state).is_equal(SymbolBrain.SubState.STATIC)


func _assert_full_push(cfg: OverworldConfig, leader: Vector2, sym: Vector2) -> void:
	var mode: OverworldMode = auto_free(ContactFixture.make_mode(
			RequestSpyMachine.new(), cfg, leader, [_ENC]))
	var source: EncounterSource = mode.add_symbol(_ENC,
			SymbolBrain.new(PackedVector2Array([sym]), SymbolBrain.PathMode.LOOP))
	mode.start_encounter(_ENC, source)
	mode.on_thawed(_ENC, GameStateMachine.BattleResult.FLED)
	var b: SymbolBrain = source.brain
	assert_int(b.sub_state).is_equal(SymbolBrain.SubState.STUNNED)
	assert_float(b.stun_left()).is_equal(cfg.flee_grace_s)
	var moved: Vector2 = b.position - sym
	assert_float(moved.length()).is_equal_approx(cfg.flee_push_m, 1e-5)
	assert_float(moved.normalized().dot((sym - leader).normalized())).is_equal_approx(1.0, 1e-6)
	assert_bool(mode.get_leader_position() == leader).is_true()
	var crossed: Array[Vector2i] = []
	SymbolBrain.push_distance(mode.get_walk_grid(), sym, (sym - leader).normalized(),
			cfg.flee_push_m, cfg.body_radius, crossed)
	assert_int(crossed.size()).is_greater(1)
	for i in range(1, crossed.size()):
		var d: Vector2i = crossed[i] - crossed[i - 1]
		assert_int(absi(d.x) + absi(d.y)).is_equal(1)


func _custom() -> OverworldConfig:
	var cfg := OverworldConfig.new()
	cfg.flee_push_m = 3.0
	cfg.body_radius = 0.2
	return cfg
