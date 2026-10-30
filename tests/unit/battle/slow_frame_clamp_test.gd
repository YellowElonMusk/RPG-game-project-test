## Story 043 (GDD sprite-camera-presentation AC-39; ADR-0006 §4 "Leftover
## dt is dropped, never carried"): a 0.5 s frame with `dt_max = 0.1` never
## finishes more than one beat, and every outcome still starts, impacts and
## ends exactly once.
extends GdUnitTestSuite

const _SLOW_FRAME: float = 0.5


func _config(dt_max: float) -> PresentationConfig:
	var c := PresentationConfig.new()
	c.follow_camera_dt_max = dt_max
	return c


func test_slow_frame_is_clamped_to_dt_max() -> void:
	for dt_max: float in [0.1, 0.05]:
		var kit := ReplayTestKit.new(_config(dt_max), 0.3)
		kit.emit_hit(kit.squad[0], kit.enemies[0], 5)
		kit.emit_hit(kit.squad[1], kit.enemies[1], 5)
		kit.step(1)  # start frame
		kit.controller.advance(_SLOW_FRAME)
		assert_float(kit.controller.get_windup_progress()).is_equal_approx(dt_max, 1e-6)


func test_slow_frame_mid_replay_finishes_at_most_one_beat() -> void:
	var kit := ReplayTestKit.new(_config(0.1), 0.05)
	kit.emit_hit(kit.squad[0], kit.enemies[0], 5)
	kit.emit_hit(kit.squad[1], kit.enemies[1], 5)
	kit.emit_turn(kit.squad[0])
	kit.h = _SLOW_FRAME
	var calls: int = 0
	while kit.controller.get_state() != BattleReplayController.State.IDLE and calls < 200:
		var before: int = kit.frames_of("beat_finished").size()
		kit.step()
		calls += 1
		assert_int(kit.frames_of("beat_finished").size() - before).is_less_equal(1)
	var plans: Array[BeatPlan] = kit.plans()
	assert_int(plans.size()).is_equal(2)
	for plan: BeatPlan in plans:
		assert_int(kit.frames_of("beat_started", plan).size()).is_equal(1)
		assert_int(kit.frames_of("beat_impact", plan).size()).is_equal(1)
		assert_int(kit.frames_of("beat_finished", plan).size()).is_equal(1)
	assert_int(kit.frames_of("turn").size()).is_equal(1)


func test_dt_max_is_below_beat_min_in_the_shipped_config() -> void:
	var c := PresentationConfig.new()
	assert_bool(c.follow_camera_dt_max < c.beat_min).is_true()
