## Story 055, AC-51: a window resize recomputes the punch and the cameras,
## driven through an injected viewport size so it runs headless (GDD
## `design/gdd/sprite-camera-presentation.md` Edge Cases "window resized";
## ADR-0005 §2, §6). Every recompute is called twice at one size (the refit
## fires `size_changed` twice) and must give identical output. Expected
## values come from config through the formulas, once with a non-default
## config.
extends GdUnitTestSuite

const _STAGE_PATH := "res://data/presentation/stages/battle_default.tres"
const _DT := 1.0 / 60.0
const _FROM := Vector2i(1920, 1080)
const _TO := Vector2i(2560, 1440)


func _config(non_default: bool) -> PresentationConfig:
	var config := PresentationConfig.new()
	if non_default:
		config.texel_base_lines = 320
		config.punch_amplitude_big = 6.0
		config.punch_duration = 0.12
		config.battle_fov_degrees = 24.0
		config.follow_camera_fov_degrees = 18.0
		config.follow_camera_dead_zone_fraction = 0.12
	return config


func _rhaz(value: float) -> int:
	return int(signf(value) * floorf(absf(value) + 0.5))


func test_resize_mid_punch_recomputes_texel_scale_and_peak_keeping_t(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var config := _config(non_default)
	var stage := DioramaStage.new()
	var cam := Camera3D.new()
	stage.add_child(cam)
	stage.camera = cam
	add_child(stage)
	auto_free(stage)
	var battle_stage := load(_STAGE_PATH) as BattleStage
	stage.configure_battle_camera(battle_stage, config, _FROM)
	var punch := HitPunch.new(config)
	punch.on_impact(-9, true, false, Vector2.RIGHT)
	for frame: int in 2:
		stage.set_punch_offset_px(punch.current_offset_px(stage.battle_viewport_height()))
		punch.advance(_DT)
	var t: float = punch.elapsed()
	assert_int(SpriteProjection.texel_scale(_FROM.y, config.texel_base_lines)) \
			.is_equal(maxi(1, _FROM.y / config.texel_base_lines))

	var results: Array = []
	for repeat: int in 2:
		stage.on_viewport_resized(_TO)
		stage.set_punch_offset_px(punch.current_offset_px(stage.battle_viewport_height()))
		results.append([cam.size, cam.frustum_offset, stage.punch_offset_px()])
	assert_that(results[1]).is_equal(results[0])

	# T at the new height (4 at the default 360 base lines).
	var t_new: int = SpriteProjection.texel_scale(_TO.y, config.texel_base_lines)
	assert_int(t_new).is_equal(maxi(1, _TO.y / config.texel_base_lines))
	if not non_default:
		assert_int(t_new).is_equal(4)
	# A_peak from the new height, t unchanged, offset in whole pixels.
	var a_peak: int = _rhaz(config.punch_amplitude_big * float(_TO.y) / 1080.0)
	assert_int(punch.current_peak(_TO.y)).is_equal(a_peak)
	assert_float(punch.elapsed()).is_equal(t)
	var k: float = (1.0 - t / config.punch_duration) * (1.0 - t / config.punch_duration)
	assert_that(stage.punch_offset_px()).is_equal(Vector2i(_rhaz(float(a_peak) * k), 0))
	# The camera re-sized and re-mapped the punch for the new window.
	var aspect: float = float(_TO.x) / float(_TO.y)
	var h_near: float = BattleFraming.h_near(config.battle_camera_near, config.battle_fov_degrees, aspect)
	assert_float(cam.size).is_equal_approx(h_near, 1e-7)
	var expected_shift: Vector2 = BattleFraming.base_lens_shift(battle_stage.horizon_frac, h_near) \
			+ BattleFraming.punch_lens_shift(stage.punch_offset_px(), h_near, _TO.y)
	assert_float(cam.frustum_offset.x).is_equal_approx(expected_shift.x, 1e-7)
	assert_float(cam.frustum_offset.y).is_equal_approx(expected_shift.y, 1e-7)


func test_follow_camera_resize_recomputes_footprint_and_dead_zone_each_time(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var config := _config(non_default)
	var follow := FollowCamera.from_config(config)
	auto_free(follow)
	var sizes: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(2520, 1080), Vector2i(1440, 1080)]
	var seen_w_far: Array[float] = []
	for size: Vector2i in sizes:
		var aspect: float = float(size.x) / float(size.y)
		var widen: float = maxf(1.0, (16.0 / 9.0) / aspect)
		var f_v_eff: float = rad_to_deg(2.0 * atan(tan(deg_to_rad(config.follow_camera_fov_degrees) * 0.5) * widen))
		var expected: FollowCamera.Footprint = FollowCamera.compute_footprint(
				config.follow_camera_height, config.follow_camera_pitch_degrees,
				config.follow_camera_fov_degrees, aspect)
		var snapshots: Array = []
		for repeat: int in 2:
			follow.on_viewport_resized(size)
			snapshots.append([follow.fov, follow.current_footprint.a_near,
					follow.current_footprint.a_far, follow.current_footprint.w_far,
					follow.current_dead_zone])
		assert_that(snapshots[1]).is_equal(snapshots[0])
		assert_float(follow.fov).is_equal_approx(f_v_eff, 1e-4)
		assert_float(follow.current_footprint.f_v_eff_degrees).is_equal_approx(f_v_eff, 1e-4)
		assert_float(follow.current_footprint.w_far).is_equal_approx(expected.w_far, 1e-6)
		assert_float(follow.current_footprint.a_near).is_equal_approx(expected.a_near, 1e-6)
		assert_float(follow.current_footprint.a_far).is_equal_approx(expected.a_far, 1e-6)
		assert_float(follow.current_dead_zone.x).is_equal_approx(
				expected.w_far * config.follow_camera_dead_zone_fraction, 1e-6)
		assert_float(follow.current_dead_zone.y).is_equal_approx(
				(expected.a_near + expected.a_far) * 0.5 * config.follow_camera_dead_zone_fraction, 1e-6)
		seen_w_far.append(follow.current_footprint.w_far)
	# Each resize actually changed the footprint (not only the first).
	assert_bool(absf(seen_w_far[1] - seen_w_far[0]) > 1e-4).is_true()
	assert_bool(absf(seen_w_far[2] - seen_w_far[1]) > 1e-4).is_true()
