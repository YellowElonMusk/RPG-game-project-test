## Stories 009 (AC-7) and 026 (AC-22): `DioramaStage`'s lighting_blend
## (GDD Formulas `lighting_blend`) -- the clock-driven takeover path, the
## tween path (Victory/Defeat), mode entry at `blend_time = 0`, the exact
## `p = 0.5` midpoint, a mid-blend re-request and discrete stepping. Frames
## are driven explicitly: the clock path from an injected clock, the tween
## path with `Tween.custom_step()`.
extends GdUnitTestSuite

const _BATTLE := "res://data/presentation/profiles/battle.tres"
const _BOSS := "res://data/presentation/profiles/boss_bureaucratia.tres"
const _VICTORY := "res://data/presentation/profiles/victory.tres"
const _DT := 1.0 / 60.0
## AC-7's blend length in frames (frame 0 is the request frame).
const _BLEND_FRAMES := 26.5
const _TOL := 1e-4


func _profile(path: String) -> LightingProfile:
	return (load(path) as LightingProfile).duplicate() as LightingProfile


## A target that differs from `battle` in every discrete flag too.
func _target() -> LightingProfile:
	var to: LightingProfile = _profile(_BOSS)
	var from: LightingProfile = _profile(_BATTLE)
	to.dof_far_enabled = not from.dof_far_enabled
	to.travel_light_enabled = not from.travel_light_enabled
	return to


func _stage(profiles: Dictionary) -> DioramaStage:
	var stage := DioramaStage.new()
	add_child(stage)
	auto_free(stage)
	stage.bind_profiles(func(id: StringName) -> LightingProfile: return profiles.get(id))
	return stage


## Every continuous parameter of `actual` equals `lerp(from, to, p)` (colors
## in linear space) within `_TOL`; returns the first mismatch or "".
func _continuous_mismatch(actual: LightingProfile, from: LightingProfile, to: LightingProfile,
		p: float) -> String:
	for prop: Dictionary in actual.get_property_list():
		if (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var key: StringName = StringName(prop["name"])
		var a: Variant = from.get(key)
		var b: Variant = to.get(key)
		var v: Variant = actual.get(key)
		match typeof(a):
			TYPE_FLOAT:
				if is_nan(v) or absf(float(v) - lerpf(a, b, p)) > _TOL:
					return "%s: %s vs %s" % [key, v, lerpf(a, b, p)]
			TYPE_VECTOR3:
				if ((v as Vector3) - (a as Vector3).lerp(b, p)).length() > _TOL:
					return String(key)
			TYPE_COLOR:
				var want: Color = (a as Color).srgb_to_linear().lerp((b as Color).srgb_to_linear(), p)
				var got: Color = (v as Color).srgb_to_linear()
				for c: int in 4:
					if absf(got[c] - want[c]) > _TOL:
						return String(key)
	return ""


## AC-7 on both paths: frame 26 has `p < 1 - 1e-4`, frame 27 has `p = 1` and
## completes, and every frame's continuous values equal `lerp(from, to, p)`.
func test_blend_26_5_frames_completes_on_frame_27_without_popping(use_clock: bool,
		test_parameters := [[true], [false]]) -> void:
	var from: LightingProfile = _profile(_BATTLE)
	var to: LightingProfile = _target()
	var stage: DioramaStage = _stage({&"battle": from, &"boss": to})
	stage.apply_profile(from, 0.0)
	var blend_time: float = _BLEND_FRAMES * _DT
	var now: Array[float] = [0.0]
	var completed: Array[int] = [0]
	stage.blend_completed.connect(func() -> void: completed[0] += 1)
	var clock: Callable = (func() -> float: return now[0]) if use_clock else Callable()
	stage.request_profile(&"boss", blend_time, clock)
	if use_clock:
		assert_object(stage._blend_tween).is_null()
	for frame: int in range(0, 31):
		if frame > 0:
			now[0] = frame * _DT
			if use_clock:
				stage.refresh_clock_blend()
			elif stage._blend_tween != null and stage._blend_tween.is_valid():
				stage._blend_tween.custom_step(_DT)
		var p: float = stage.blend_p()
		assert_float(p).override_failure_message("frame %d p" % frame) \
				.is_equal_approx(DioramaStage.blend_progress(frame * _DT, blend_time), _TOL)
		assert_str(_continuous_mismatch(stage.current_values, from, to, p)) \
				.override_failure_message("frame %d" % frame).is_empty()
		if frame == 26:
			assert_float(p).is_less(1.0 - 1e-4)
			assert_bool(stage.is_blending()).is_true()
			assert_int(completed[0]).is_equal(0)
		if frame == 27:
			assert_float(p).is_equal(1.0)
			assert_bool(stage.is_blending()).is_false()
			assert_int(completed[0]).is_equal(1)
	assert_int(completed[0]).is_equal(1)


## AC-7 / AC-22: mode entry (`blend_time = 0`) gives `p = 1` on its first
## frame with no NaN in any parameter.
func test_mode_entry_zero_blend_time_gives_p_one_without_nan() -> void:
	var profile: LightingProfile = _profile(_VICTORY)
	var stage: DioramaStage = _stage({})

	stage.apply_profile(profile, 0.0)

	assert_float(stage.blend_p()).is_equal(1.0)
	assert_float(DioramaStage.blend_progress(0.0, 0.0)).is_equal(1.0)
	assert_bool(stage.is_blending()).is_false()
	assert_str(_continuous_mismatch(stage.current_values, profile, profile, 1.0)).is_empty()


## AC-22: at `t_blend = blend_time / 2`, called directly, `p = 0.5` -- for the
## shipped blend lengths and once for a non-default one.
func test_blend_progress_at_half_duration_is_one_half() -> void:
	var config := PresentationConfig.new()
	var non_default := PresentationConfig.new()
	non_default.blend_boss = 0.6
	non_default.blend_victory = 0.35
	for blend_time: float in [config.blend_boss, config.blend_victory, config.blend_defeat,
			non_default.blend_boss, non_default.blend_victory, _profile(_BOSS).blend_time]:
		assert_float(DioramaStage.blend_progress(blend_time * 0.5, blend_time)) \
				.is_equal_approx(0.5, 1e-6)


## AC-22: a blend requested mid-blend starts from the current values (no jump
## on its first frame), and no frame-to-frame change exceeds the formula's
## largest single-frame step times the parameter's span.
func test_mid_blend_request_starts_from_current_values() -> void:
	var a: LightingProfile = _profile(_BATTLE)
	var b: LightingProfile = _target()
	var c: LightingProfile = _profile(_VICTORY)
	var stage: DioramaStage = _stage({&"b": b, &"c": c})
	stage.apply_profile(a, 0.0)
	var config := PresentationConfig.new()
	stage.request_profile(&"b", config.blend_boss)
	for i: int in 10:
		stage._blend_tween.custom_step(_DT)
	var captured: LightingProfile = stage.current_values

	stage.request_profile(&"c", config.blend_victory)

	assert_str(_continuous_mismatch(stage.current_values, captured, c, 0.0)).is_empty()
	var max_step: float = 0.0
	var frames: int = ceili(config.blend_victory / _DT) + 1
	for k: int in frames:
		max_step = maxf(max_step, DioramaStage.blend_progress((k + 1) * _DT, config.blend_victory)
				- DioramaStage.blend_progress(k * _DT, config.blend_victory))
	var prev: LightingProfile = stage.current_values
	for k: int in frames:
		if stage._blend_tween.is_valid():
			stage._blend_tween.custom_step(_DT)
		var cur: LightingProfile = stage.current_values
		for key: StringName in [&"key_energy", &"set_energy", &"fill_energy", &"rim_strength",
				&"exposure", &"sky_energy", &"glow_intensity"]:
			var span: float = absf(float(c.get(key)) - float(captured.get(key)))
			assert_float(absf(float(cur.get(key)) - float(prev.get(key)))) \
					.override_failure_message("%s frame %d" % [key, k]) \
					.is_less_equal(max_step * span + _TOL)
		prev = cur
	assert_str(_continuous_mismatch(stage.current_values, c, c, 1.0)).is_empty()


## AC-22: with a 26.5-frame blend, a discrete parameter has its old value on
## frame 13 and its new value on frame 14.
func test_discrete_parameter_steps_between_frames_13_and_14() -> void:
	var from: LightingProfile = _profile(_BATTLE)
	var to: LightingProfile = _target()
	var stage: DioramaStage = _stage({&"to": to})
	stage.apply_profile(from, 0.0)
	stage.request_profile(&"to", _BLEND_FRAMES * _DT)
	for frame: int in range(1, 15):
		stage._blend_tween.custom_step(_DT)
		if frame == 13:
			assert_bool(stage.current_values.dof_far_enabled).is_equal(from.dof_far_enabled)
			assert_bool(stage.current_values.travel_light_enabled) \
					.is_equal(from.travel_light_enabled)
	assert_bool(stage.current_values.dof_far_enabled).is_equal(to.dof_far_enabled)
	assert_bool(stage.current_values.travel_light_enabled).is_equal(to.travel_light_enabled)
