## Story 048, AC-44 (GDD rule 13; ADR-0005 §6/§7, ADR-0009 §7): with Reduce
## Motion On (already On before anything starts) the punch offset is 0 on
## every frame, every ambient set-motion amplitude is 0, and the Victory
## confetti is the still variant -- read live through the injected
## `PresentationSettings` view. Lighting blends and the follow camera behave
## exactly as with it Off: Reduce Motion zeroes amplitudes, never a clock.
extends GdUnitTestSuite

const _DT := 1.0 / 60.0
const _STAGE_PATH := "res://data/presentation/stages/battle_default.tres"


func _stage(settings: PresentationSettings) -> DioramaStage:
	var stage: DioramaStage = auto_free(DioramaStage.new())
	stage.presentation_settings = settings
	return stage


func test_punch_offset_is_zero_on_every_frame_with_reduce_motion_on() -> void:
	var config := PresentationConfig.new()
	for shake: int in [PresentationSettings.ScreenShake.FULL, PresentationSettings.ScreenShake.REDUCED]:
		var settings := PresentationSettings.with_values(
				shake as PresentationSettings.ScreenShake, true)
		var stage := _stage(settings)
		stage.camera = auto_free(Camera3D.new())
		stage.configure_battle_camera(load(_STAGE_PATH) as BattleStage, config, Vector2i(1920, 1080))
		var base: Vector2 = stage.battle_base_shift()
		var punch := HitPunch.new(config, settings)
		punch.start(config.punch_amplitude_big, Vector2.RIGHT)
		for frame: int in 10:
			var offset: Vector2i = punch.current_offset_px(1080)
			stage.set_punch_offset_px(offset)
			assert_that(offset).is_equal(Vector2i.ZERO)
			assert_vector(stage.camera.frustum_offset).is_equal(base)
			punch.advance(_DT)


func test_ambient_amplitudes_are_zero_with_reduce_motion_on() -> void:
	var config := PresentationConfig.new()
	var off: Dictionary = _stage(PresentationSettings.new()).ambient_motion(config)
	var on: Dictionary = _stage(PresentationSettings.with_values(
			PresentationSettings.ScreenShake.FULL, true)).ambient_motion(config)
	assert_array(off.keys()).is_not_empty()
	assert_array(on.keys()).contains_exactly_in_any_order(off.keys())
	for key: Variant in off:
		assert_float(float(off[key])).override_failure_message("%s off" % key).is_greater(0.0)
		assert_float(float(on[key])).override_failure_message("%s on" % key).is_equal(0.0)
	assert_float(float(off[&"cloud_scroll"])).is_equal(config.ambient_cloud_scroll)
	assert_float(float(off[&"foliage_sway"])).is_equal(config.ambient_foliage_sway)
	assert_float(float(off[&"water_ripple"])).is_equal(config.ambient_water_ripple)
	assert_float(float(off[&"particle_drift"])).is_equal(config.ambient_particle_drift)


func test_confetti_is_the_still_variant_with_reduce_motion_on_and_swaps_live() -> void:
	var config := PresentationConfig.new()
	var settings := PresentationSettings.new()
	var stage := _stage(settings)
	assert_str(String(stage.victory_confetti_id(config))).is_equal(String(config.confetti_effect_id))
	settings.reduce_motion = true
	assert_str(String(stage.victory_confetti_id(config))).is_equal(
			String(config.confetti_still_effect_id))
	assert_float(float(stage.ambient_motion(config)[&"cloud_scroll"])).is_equal(0.0)
	settings.reduce_motion = false
	assert_str(String(stage.victory_confetti_id(config))).is_equal(String(config.confetti_effect_id))


## The trap: a lighting blend (on its clock) and the follow camera track
## identically with Reduce Motion On and Off.
func test_lighting_blend_and_follow_camera_are_unaffected() -> void:
	var from := LightingProfile.new()
	var to := LightingProfile.new()
	to.set_energy = 3.0
	to.key_energy = 0.4
	var clock: Array[float] = [0.0]
	var tick := func() -> float: return clock[0]
	var off_stage := _stage(PresentationSettings.new())
	var on_stage := _stage(PresentationSettings.with_values(PresentationSettings.ScreenShake.FULL, true))
	for stage: DioramaStage in [off_stage, on_stage]:
		stage.bind_profiles(func(id: StringName) -> LightingProfile: return from if id == &"a" else to)
		stage.request_profile(&"a", 0.0)
		stage.request_profile(&"b", 0.5, tick)
	var config := PresentationConfig.new()
	var off_cam: FollowCamera = auto_free(FollowCamera.from_config(config))
	var on_cam: FollowCamera = auto_free(FollowCamera.from_config(config))
	for frame: int in 45:
		clock[0] = float(frame) * _DT
		off_stage.refresh_clock_blend()
		on_stage.refresh_clock_blend()
		assert_float(on_stage.blend_p()).is_equal(off_stage.blend_p())
		assert_float(on_stage.current_values.set_energy).is_equal(off_stage.current_values.set_energy)
		var target := Vector2(float(frame) * 0.2, float(frame) * -0.1)
		var a: Vector2 = off_cam.advance(target, _DT, 16.0 / 9.0, Vector2(-50, -50), Vector2(50, 50))
		var b: Vector2 = on_cam.advance(target, _DT, 16.0 / 9.0, Vector2(-50, -50), Vector2(50, 50))
		assert_vector(b).is_equal(a)
	assert_float(on_stage.blend_p()).is_equal(1.0)
