## Story 062, AC-26d (GDD rule 9 "Reactions are mixed", "Permanence"): of N
## reacting civilians at least `ceil(liberation_grumble_min * N)` grumble,
## drawn only from `OverworldMode.rng`; a Clerk respawned onto a liberated
## street uses the deflated sprite set and behaves exactly like a normal one.
extends GdUnitTestSuite

const _CLERK: String = "enc_paris_clerks_east"
const _QUEUE_AT: Vector2 = Vector2(13.0, 14.5)
const _ENEMY: String = "enemy_fixture_clerk"
const _SPRITE_SET: String = "spr_fixture_clerk"
const _SEED: int = 62
const _DT: float = 1.0 / 60.0


func test_grumblers_meet_the_floor_for_every_crowd_size() -> void:
	for share: float in [OccupationStageData.new().liberation_grumble_min, 0.4]:
		for n: int in range(1, 13):
			var rng := RandomNumberGenerator.new()
			rng.seed = _SEED
			var beats: Array[bool] = OverworldMode.roll_reactions(n, share, rng)
			assert_int(beats.size()).is_equal(n)
			assert_int(beats.count(true)).is_greater_equal(ceili(share * float(n)))


func test_floor_boundaries() -> void:
	assert_int(OverworldMode.grumble_floor(0, 0.2)).is_equal(0)
	assert_int(OverworldMode.grumble_floor(1, 0.1)).is_equal(1)
	assert_int(OverworldMode.grumble_floor(10, 0.7)).is_equal(7)
	assert_int(OverworldMode.grumble_floor(5, 0.2)).is_equal(1)
	assert_int(OverworldMode.grumble_floor(3, 1.5)).is_equal(3)


func test_same_seed_gives_same_reactions() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = _SEED
	b.seed = _SEED
	assert_array(OverworldMode.roll_reactions(9, 0.4, a)).is_equal(OverworldMode.roll_reactions(9, 0.4, b))


func test_victory_rolls_the_queues_reactions_from_the_mode_rng() -> void:
	var n: int = 7
	var mode: OverworldMode = _mode(n)
	mode.rng.seed = _SEED
	var twin: OverworldMode = _mode(n)
	twin.rng.seed = _SEED
	mode.on_thawed(_CLERK, GameStateMachine.BattleResult.VICTORY)
	twin.on_thawed(_CLERK, GameStateMachine.BattleResult.VICTORY)
	var beats: Array = mode.liberation_reactions[&"queue_fixture"]
	assert_int(beats.size()).is_equal(n)
	assert_int(beats.count(true)).is_greater_equal(ceili(mode.liberation_grumble_share() * float(n)))
	assert_array(beats).is_equal(twin.liberation_reactions[&"queue_fixture"])


func test_respawned_clerk_on_liberated_street_is_deflated() -> void:
	var normal: OverworldMode = _mode(0)
	var deflated: OverworldMode = _mode(0)
	deflated.world_state.liberate(deflated.world_state.map_id, &"queue_fixture")
	assert_bool(normal.is_deflated(_source(normal))).is_false()
	assert_bool(deflated.is_deflated(_source(deflated))).is_true()
	assert_str(normal.symbol_sprite_set(_source(normal))).is_equal(_SPRITE_SET)
	assert_str(deflated.symbol_sprite_set(_source(deflated))).is_equal(
			_SPRITE_SET + deflated.config.deflated_sprite_suffix)


func test_deflated_suffix_comes_from_config() -> void:
	var deflated: OverworldMode = _mode(0)
	deflated.config.deflated_sprite_suffix = "_sheepish"
	deflated.world_state.liberate(deflated.world_state.map_id, &"queue_fixture")
	assert_str(deflated.symbol_sprite_set(_source(deflated))).is_equal(_SPRITE_SET + "_sheepish")


func test_deflated_clerk_behaves_like_a_normal_one() -> void:
	var normal: OverworldMode = _mode(0)
	var deflated: OverworldMode = _mode(0)
	deflated.world_state.liberate(deflated.world_state.map_id, &"queue_fixture")
	for m: OverworldMode in [normal, deflated]:
		m.set_leader_position(_QUEUE_AT + Vector2(-6.0, 0.0))
	for i: int in 240:
		normal.step_frame(_DT, Vector2.RIGHT)
		deflated.step_frame(_DT, Vector2.RIGHT)
		var a: SymbolBrain = _source(normal).brain
		var b: SymbolBrain = _source(deflated).brain
		assert_vector(b.position).is_equal(a.position)
		assert_int(b.sub_state).is_equal(a.sub_state)
		if not normal.is_exploring():
			break


func _source(mode: OverworldMode) -> EncounterSource:
	for s: EncounterSource in mode.get_encounter_sources():
		if s.symbol_id == _CLERK:
			return s
	return null


func _mode(civilians: int) -> OverworldMode:
	var queue := GagInteractable.new()
	queue.marker_id = &"queue_fixture"
	queue.text = "A queue."
	queue.liberate_symbol = _CLERK
	queue.reacting_civilians = civilians
	queue.blocked_rect = Rect2(_QUEUE_AT - Vector2(0.5, 0.5), Vector2.ONE)
	queue.position = Vector3(_QUEUE_AT.x, 0.0, _QUEUE_AT.y)
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode([queue]))
	var enemy := EnemyData.new()
	enemy.id = _ENEMY
	enemy.sprite_set_id = _SPRITE_SET
	(mode.encounter_catalog as RecordCatalogDouble).add(&"enemy", enemy)
	mode.set_leader_position(_QUEUE_AT + Vector2(-2.0, 0.0))
	return mode
