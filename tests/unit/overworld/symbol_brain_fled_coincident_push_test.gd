## Story 046, AC-19c: with coincident centres the flee push goes opposite
## the leader's facing (GDD Edge Cases), still 4-connected and capped.
extends GdUnitTestSuite

const _ENC: String = "enc_fixture_clerk"
const _AT: Vector2 = Vector2(6.5, 5.5)


func test_coincident_push_opposite_facing(facing: Vector2, test_parameters := [
		[Vector2(1, -1)], [Vector2(1, 1)], [Vector2(-1, 1)], [Vector2(-1, -1)]]) -> void:
	for cfg: OverworldConfig in [OverworldConfig.new(), _custom()]:
		var mode: OverworldMode = auto_free(ContactFixture.make_mode(
				RequestSpyMachine.new(), cfg, _AT, [_ENC]))
		mode.set_leader_facing(facing)
		var source: EncounterSource = mode.add_symbol(_ENC,
				SymbolBrain.new(PackedVector2Array([_AT]), SymbolBrain.PathMode.LOOP))
		mode.start_encounter(_ENC, source)
		mode.on_thawed(_ENC, GameStateMachine.BattleResult.FLED)
		var moved: Vector2 = source.brain.position - _AT
		var expected: Vector2 = -facing.normalized() * cfg.flee_push_m
		assert_float(moved.distance_to(expected)).is_less(1e-5)
		assert_bool(mode.get_leader_position() == _AT).is_true()


func test_direction_is_negated_facing_not_symbol_facing() -> void:
	var dir: Vector2 = SymbolBrain.flee_push_direction(_AT, _AT, Vector2(0.6, 0.8))
	assert_vector(dir).is_equal_approx(Vector2(-0.6, -0.8), Vector2(1e-6, 1e-6))


func test_zero_facing_and_coincident_stuns_without_push() -> void:
	var b := SymbolBrain.new(PackedVector2Array([_AT]), SymbolBrain.PathMode.LOOP)
	b.on_fled(_AT, Vector2.ZERO, ContactFixture.open_grid(), OverworldConfig.new())
	assert_vector(b.position).is_equal(_AT)
	assert_int(b.sub_state).is_equal(SymbolBrain.SubState.STUNNED)


func test_coincident_push_still_stops_at_blocker() -> void:
	var cfg := OverworldConfig.new()
	var grid: WalkGrid = ContactFixture.open_grid()
	var wall: Array[Vector2i] = [Vector2i(7, 5)]
	grid.set_blocked(wall, true)
	var b := SymbolBrain.new(PackedVector2Array([_AT]), SymbolBrain.PathMode.LOOP)
	b.on_fled(_AT, Vector2.LEFT, grid, cfg)
	assert_float(b.position.x - _AT.x).is_equal_approx(0.5 - cfg.body_radius, 1e-5)


func _custom() -> OverworldConfig:
	var cfg := OverworldConfig.new()
	cfg.flee_push_m = 1.0
	return cfg
