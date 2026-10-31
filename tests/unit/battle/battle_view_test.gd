## `BattleView`'s pure helpers: which stage slots enemies stand on, which
## frame an animation shows at a time, and which backdrop a faction gets.
extends GdUnitTestSuite


func _stage(enemy_xs: Array[float]) -> BattleStage:
	var stage := BattleStage.new()
	var slots: Array[Vector2] = [Vector2(-1.8, 11), Vector2(-0.6, 11), Vector2(0.6, 11), Vector2(1.8, 11)]
	for x: float in enemy_xs:
		slots.append(Vector2(x, 20))
	stage.slots = slots
	return stage


func _anim(id: StringName, durations: Array[float], fps: float) -> SpriteAnimationData:
	var anim := SpriteAnimationData.new()
	anim.animation_id = id
	anim.fps = fps
	anim.frame_durations = PackedFloat32Array(durations)
	return anim


func test_enemies_fill_from_the_centre_out() -> void:
	var stage := _stage([-3.0, -1.0, 1.0, 3.0])
	assert_array(BattleView.enemy_slots_for(stage, 1)).is_equal([5])
	assert_array(BattleView.enemy_slots_for(stage, 4)).is_equal([5, 6, 4, 7])


func test_boss_stage_puts_the_first_enemy_in_the_middle() -> void:
	var stage := _stage([0.0, -2.6, 2.6])
	assert_array(BattleView.enemy_slots_for(stage, 2)).is_equal([4, 5])


func test_enemy_slots_never_exceed_the_stage() -> void:
	assert_int(BattleView.enemy_slots_for(_stage([0.0]), 3).size()).is_equal(1)
	assert_array(BattleView.enemy_slots_for(null, 2)).is_empty()


func test_idle_loops_on_its_own_frame_durations() -> void:
	var idle := _anim(&"idle", [1.0, 1.0, 1.0, 1.0], 4.0)  # 0.25 s per frame
	assert_int(BattleView.frame_at(idle, 0.0)).is_equal(0)
	assert_int(BattleView.frame_at(idle, 0.30)).is_equal(1)
	assert_int(BattleView.frame_at(idle, 0.99)).is_equal(3)
	assert_int(BattleView.frame_at(idle, 1.10)).is_equal(0)


func test_action_holds_its_last_frame_once_it_ends() -> void:
	var attack := _anim(&"attack", [1.0, 2.0, 1.0], 10.0)  # 0.1, 0.2, 0.1 s
	assert_int(BattleView.frame_at(attack, 0.05)).is_equal(0)
	assert_int(BattleView.frame_at(attack, 0.25)).is_equal(1)
	assert_int(BattleView.frame_at(attack, 0.35)).is_equal(2)
	assert_int(BattleView.frame_at(attack, 5.0)).is_equal(2)


func test_backdrop_follows_faction_and_boss_flag() -> void:
	var normal := BattleView.load_backdrop("faction_bureaucratia", false)
	var boss := BattleView.load_backdrop("faction_megacorp", true)
	assert_object(normal).is_not_null()
	assert_str(normal.resource_path).ends_with("bg_battle_bureaucratia.png")
	assert_str(boss.resource_path).ends_with("bg_battle_megacorp_boss.png")
	assert_object(BattleView.load_backdrop("faction_nobody", false)).is_null()
