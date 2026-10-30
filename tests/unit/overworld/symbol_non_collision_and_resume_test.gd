## Story 129, AC-57 (GDD rule 5 "Symbols and each other", "Contact"): two
## symbols, a follower and a civilian on the same point never block or push
## one another; a symbol touched during Patrol stores its patrol position at
## contact as its resume point and, after a Fled battle, walks back to it
## and resumes the patrol from there in the same direction.
extends GdUnitTestSuite

const _DT: float = 1.0 / 60.0
## Both patrols cross (6.5, 6.5).
const _CROSS: Vector2 = Vector2(6.5, 6.5)
const _PATH_A: PackedVector2Array = [Vector2(2.5, 6.5), Vector2(10.5, 6.5)]
const _PATH_B: PackedVector2Array = [Vector2(6.5, 2.5), Vector2(6.5, 10.5)]
## Far from both patrols, so neither notices.
const _LEADER_FAR: Vector2 = Vector2(0.5, 0.5)


func test_crossing_symbols_followers_and_a_civilian_never_displace_each_other() -> void:
	var cfg := OverworldConfig.new()
	var grid: WalkGrid = ContactFixture.open_grid()
	# Each symbol alone, then both together: identical positions every frame.
	var alone_a := SymbolBrain.new(_PATH_A, SymbolBrain.PathMode.PINGPONG, 0)
	var alone_b := SymbolBrain.new(_PATH_B, SymbolBrain.PathMode.PINGPONG, 1)
	var a := SymbolBrain.new(_PATH_A, SymbolBrain.PathMode.PINGPONG, 0)
	var b := SymbolBrain.new(_PATH_B, SymbolBrain.PathMode.PINGPONG, 1)
	var met: bool = false
	for i: int in 600:
		alone_a.step(_DT, _LEADER_FAR, grid, true, cfg)
		alone_b.step(_DT, _LEADER_FAR, grid, true, cfg)
		a.step(_DT, _LEADER_FAR, grid, true, cfg)
		b.step(_DT, _LEADER_FAR, grid, true, cfg)
		assert_vector(a.position).is_equal(alone_a.position)
		assert_vector(b.position).is_equal(alone_b.position)
		met = met or a.position.distance_to(b.position) < 2.0 * cfg.body_radius
	assert_bool(met).override_failure_message("the patrols never overlapped").is_true()
	# A civilian (NpcSpawn) and followers on the crossing point block nothing:
	# NPCs never mark the walk grid, and followers are not on it at all.
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode([ProbeFixture.npc(ProbeFixture.OPEN_SPOT)]))
	var at: Vector2i = mode.get_walk_grid().cell_of(ProbeFixture.OPEN_SPOT)
	assert_bool(mode.get_walk_grid().is_walkable(at)).is_true()
	assert_bool(mode.get_walk_grid().is_symbol_legal(at)).is_true()
	mode.set_follower_positions([ProbeFixture.OPEN_SPOT, ProbeFixture.OPEN_SPOT] as Array[Vector2])
	assert_bool(mode.get_walk_grid().is_walkable(at)).is_true()


func test_a_patrol_contact_is_the_resume_point_after_fled() -> void:
	var cfg := OverworldConfig.new()
	var grid: WalkGrid = ContactFixture.open_grid()
	var brain := SymbolBrain.new(_PATH_A, SymbolBrain.PathMode.PINGPONG, 0)
	for i: int in 50:
		brain.step(_DT, _LEADER_FAR, grid, true, cfg)
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.PATROL)
	var touched_at: Vector2 = brain.position
	var next_before: int = brain.next_index()
	var dir_before: int = brain.direction()
	brain.on_contact()
	assert_vector(brain.resume_point()).is_equal(touched_at)
	# Fled: stunned and pushed away (the leader stood just west of it).
	brain.on_fled(touched_at + Vector2(-0.5, 0.0), Vector2.RIGHT, grid, cfg)
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.STUNNED)
	assert_vector(brain.position).is_not_equal(touched_at)
	var frames: int = 0
	while brain.sub_state != SymbolBrain.SubState.PATROL and frames < 2000:
		brain.step(_DT, _LEADER_FAR, grid, true, cfg)
		frames += 1
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.PATROL)
	assert_float(brain.position.distance_to(touched_at)).is_less_equal(cfg.waypoint_tol_m + 1e-3)
	assert_int(brain.next_index()).is_equal(next_before)
	assert_int(brain.direction()).is_equal(dir_before)
