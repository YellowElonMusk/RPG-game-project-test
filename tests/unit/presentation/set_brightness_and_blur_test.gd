## Story 028, AC-24 (GDD `set_brightness_and_blur`; ADR-0005 §3/§5, ADR-0009 §7):
## steady-state set brightness, the Victory curve frame by frame, Victory
## after a boss, the sky's energy, the boss takeover's fill and set-light
## direction, and Reduce Blur scaling blur only (Menu backdrop included, live
## on a frozen frame). Expected values come from the config through an
## independent copy of the formula; the AC's own named numbers (0.70, 0.90,
## 0.85 at the defaults) are asserted literally, as boundaries.
extends GdUnitTestSuite

const _PROFILES_DIR := "res://data/presentation/profiles"
const _DT := 1.0 / 60.0
const _EPS := 1e-4
## Victory frames simulated (well past the settle at every in-range config).
const _FRAMES := 90


func _profile(id: String) -> LightingProfile:
	return ResourceLoader.load(_PROFILES_DIR.path_join("%s.tres" % id)) as LightingProfile


## A stage fixture with non-unit native energies, so a missing `B_native`
## factor cannot pass by accident.
func _stage() -> BattleStage:
	var stage := BattleStage.new()
	stage.set_energy_native = 2.0
	stage.sky_energy_native = 1.5
	return stage


func _config(non_default: bool) -> PresentationConfig:
	var config := PresentationConfig.new()
	if non_default:
		config.set_brightness_battle = 0.65
		config.set_brightness_boss = 0.80
		config.set_brightness_victory = 0.95
		config.set_brightness_victory_settle = 0.78
		config.set_brightness_defeat = 0.35
		config.blend_victory = 0.25
		config.victory_settle = 0.45
		config.set_key_fill_ratio_boss = 5.5
		config.reduce_blur_factor = 0.25
	return config


## Independent smoothstep and Victory curve (GDD text, not `SetBrightness`).
func _ss(x: float) -> float:
	var c: float = clampf(x, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


func _victory_k(t: float, k_from: float, c: PresentationConfig) -> float:
	if t <= c.blend_victory:
		return k_from + (c.set_brightness_victory - k_from) * _ss(t / c.blend_victory)
	return c.set_brightness_victory + (c.set_brightness_victory_settle - c.set_brightness_victory) \
			* _ss((t - c.blend_victory) / c.victory_settle)


func _victory_frame(frame: int, flood: LightingProfile, c: PresentationConfig,
		reduce_blur: bool = false) -> LightingProfile:
	var stage := _stage()
	return SetBrightness.state_values(SetBrightness.State.VICTORY, float(frame) * _DT,
			_profile("victory"), _profile("battle"), flood, stage.set_energy_native,
			stage.sky_energy_native, reduce_blur, c)


func test_steady_states_scale_native_by_k_state_below_one(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var c := _config(non_default)
	var stage := _stage()
	var cases: Array = [
		[SetBrightness.State.BATTLE, "battle", c.set_brightness_battle],
		[SetBrightness.State.BOSS_TAKEOVER, "boss_megacorp", c.set_brightness_boss],
		[SetBrightness.State.DEFEAT, "defeat", c.set_brightness_defeat]]
	for row: Array in cases:
		var k: float = row[2]
		assert_float(k).is_less(1.0)
		var v: LightingProfile = SetBrightness.state_values(row[0], 0.0, _profile(row[1]),
				_profile("battle"), null, stage.set_energy_native, stage.sky_energy_native, false, c)
		assert_float(v.set_energy).is_equal_approx(stage.set_energy_native * k, _EPS)


func test_victory_curve_named_frames_at_defaults() -> void:
	var c := _config(false)
	var b: float = _stage().set_energy_native
	assert_float(_victory_frame(0, null, c).set_energy).is_equal_approx(0.70 * b, _EPS)
	assert_float(_victory_frame(18, null, c).set_energy).is_equal_approx(0.90 * b, _EPS)
	for frame: int in range(42, _FRAMES):
		assert_float(_victory_frame(frame, null, c).set_energy).is_equal_approx(0.85 * b, _EPS)


func test_victory_every_frame_follows_curve_and_never_exceeds_peak(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var c := _config(non_default)
	var b: float = _stage().set_energy_native
	for frame: int in _FRAMES:
		var t: float = float(frame) * _DT
		var v: LightingProfile = _victory_frame(frame, null, c)
		assert_float(v.set_energy).is_equal_approx(
				b * _victory_k(t, c.set_brightness_battle, c), _EPS)
		assert_float(v.set_energy).is_less_equal(c.set_brightness_victory * b + _EPS)


func test_victory_actor_key_and_rim_return_to_battle_and_rise_between(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var c := _config(non_default)
	var battle := _profile("battle")
	var settle_end: float = c.blend_victory + c.victory_settle
	for frame: int in _FRAMES:
		var t: float = float(frame) * _DT
		var v: LightingProfile = _victory_frame(frame, null, c)
		assert_bool(v.key_color.is_equal_approx(battle.key_color)).is_true()
		assert_bool(v.rim_color.is_equal_approx(battle.rim_color)).is_true()
		if frame == 0 or t >= settle_end - 1e-9:
			assert_float(v.key_energy).is_equal_approx(battle.key_energy, _EPS)
			assert_float(v.rim_strength).is_equal_approx(battle.rim_strength, _EPS)
		else:
			assert_float(v.key_energy).override_failure_message(
					"frame %d key %f" % [frame, v.key_energy]).is_greater(battle.key_energy)
			assert_float(v.rim_strength).is_greater(battle.rim_strength)


func test_victory_after_boss_starts_at_boss_level_never_dips_and_keeps_flood_sky(
		non_default: bool, test_parameters := [[false], [true]]) -> void:
	var c := _config(non_default)
	var b: float = _stage().set_energy_native
	var flood := _profile("boss_megacorp")
	assert_float(_victory_frame(0, flood, c).set_energy).is_equal_approx(
			c.set_brightness_boss * b, _EPS)
	for frame: int in _FRAMES:
		var t: float = float(frame) * _DT
		var v: LightingProfile = _victory_frame(frame, flood, c)
		if t <= c.blend_victory:
			assert_float(v.set_energy).is_greater_equal(c.set_brightness_boss * b - _EPS)
		assert_float(v.set_energy).is_equal_approx(b * _victory_k(t, c.set_brightness_boss, c), _EPS)
		for field: String in ["sky_top", "sky_bottom", "sky_horizon"]:
			assert_bool((v.get(field) as Color).is_equal_approx(flood.get(field))).override_failure_message(
					"frame %d: %s is not the flood swatch" % [frame, field]).is_true()


func test_sky_energy_follows_k_state_in_every_non_takeover_state(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var c := _config(non_default)
	var stage := _stage()
	for row: Array in [[SetBrightness.State.BATTLE, "battle"], [SetBrightness.State.DEFEAT, "defeat"]]:
		var v: LightingProfile = SetBrightness.state_values(row[0], 0.0, _profile(row[1]),
				_profile("battle"), null, stage.set_energy_native, stage.sky_energy_native, false, c)
		assert_float(v.sky_energy).is_equal_approx(
				stage.sky_energy_native * SetBrightness.k_state(row[0], c), _EPS)
	for frame: int in _FRAMES:
		var t: float = float(frame) * _DT
		assert_float(_victory_frame(frame, null, c).sky_energy).is_equal_approx(
				stage.sky_energy_native * _victory_k(t, c.set_brightness_battle, c), _EPS)


func test_boss_takeover_fill_is_set_over_ratio_and_sky_is_the_swatch(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var c := _config(non_default)
	var stage := _stage()
	var boss := _profile("boss_bureaucratia")
	var v: LightingProfile = SetBrightness.state_values(SetBrightness.State.BOSS_TAKEOVER, 0.0,
			boss, _profile("battle"), null, stage.set_energy_native, stage.sky_energy_native, false, c)
	assert_float(v.fill_energy).is_equal_approx(v.set_energy / c.set_key_fill_ratio_boss, _EPS)
	assert_float(v.sky_energy).is_equal_approx(boss.sky_energy, _EPS)


## The set light's direction is stage data: applying a boss preset over the
## Battle preset leaves it exactly where Battle had it.
func test_boss_takeover_keeps_the_battle_set_light_direction() -> void:
	var stage: DioramaStage = auto_free(DioramaStage.new())
	stage.key_light = DirectionalLight3D.new()
	stage.set_light = DirectionalLight3D.new()
	stage.fill_light = DirectionalLight3D.new()
	stage.add_child(stage.key_light)
	stage.add_child(stage.set_light)
	stage.add_child(stage.fill_light)
	stage.set_light.rotation_degrees = Vector3(-40.0, 25.0, 0.0)
	stage.apply_profile(_profile("battle"), 0.0)
	var battle_basis: Basis = stage.set_light.transform.basis
	for id: String in ["boss_bureaucratia", "boss_megacorp"]:
		stage.apply_profile(_profile(id), 0.0)
		assert_bool(stage.set_light.transform.basis.is_equal_approx(battle_basis)).is_true()


func test_reduce_blur_scales_blur_only_never_brightness(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var c := _config(non_default)
	var stage := _stage()
	var rows: Array = [[SetBrightness.State.BATTLE, "battle"], [SetBrightness.State.DEFEAT, "defeat"],
			[SetBrightness.State.BOSS_TAKEOVER, "boss_megacorp"], [SetBrightness.State.VICTORY, "victory"]]
	for row: Array in rows:
		for t: float in [0.0, 0.15, 0.3, 0.5, 1.0]:
			var off: LightingProfile = SetBrightness.state_values(row[0], t, _profile(row[1]),
					_profile("battle"), null, stage.set_energy_native, stage.sky_energy_native, false, c)
			var on: LightingProfile = SetBrightness.state_values(row[0], t, _profile(row[1]),
					_profile("battle"), null, stage.set_energy_native, stage.sky_energy_native, true, c)
			assert_float(on.set_energy).is_equal(off.set_energy)
			assert_float(on.sky_energy).is_equal(off.sky_energy)
			assert_float(on.fill_energy).is_equal(off.fill_energy)
			assert_float(on.key_energy).is_equal(off.key_energy)
			assert_float(on.dof_amount).is_equal_approx(off.dof_amount * c.reduce_blur_factor, _EPS)
	# The GDD worked example: strength 6 with Reduce Blur On gives 1.8 at the default factor.
	assert_float(SetBrightness.blur(6.0, true, _config(false))).is_equal_approx(1.8, _EPS)


## The Menu backdrop blurs a frozen frame: mode time does not advance, yet
## toggling Reduce Blur through the live `PresentationSettings` view changes
## the backdrop blur on the next evaluation; the frozen frame's brightness
## does not change.
func test_reduce_blur_applies_live_to_the_frozen_menu_backdrop() -> void:
	var c := _config(false)
	var stage := _stage()
	var settings := PresentationSettings.new()
	var backdrop_base: float = 8.0
	var frozen_t: float = 0.2
	var before: LightingProfile = SetBrightness.state_values(SetBrightness.State.VICTORY, frozen_t,
			_profile("victory"), _profile("battle"), null, stage.set_energy_native,
			stage.sky_energy_native, settings.reduce_blur, c)
	assert_float(SetBrightness.blur(backdrop_base, settings.reduce_blur, c)).is_equal(backdrop_base)
	var changed_count: Array[int] = [0]
	settings.changed.connect(func() -> void: changed_count[0] += 1)
	settings.reduce_blur = true
	assert_int(changed_count[0]).is_equal(1)
	assert_float(SetBrightness.blur(backdrop_base, settings.reduce_blur, c)).is_equal_approx(
			backdrop_base * c.reduce_blur_factor, _EPS)
	var after: LightingProfile = SetBrightness.state_values(SetBrightness.State.VICTORY, frozen_t,
			_profile("victory"), _profile("battle"), null, stage.set_energy_native,
			stage.sky_energy_native, settings.reduce_blur, c)
	assert_float(after.set_energy).is_equal(before.set_energy)
	assert_float(after.sky_energy).is_equal(before.sky_energy)
	assert_float(after.dof_amount).is_equal_approx(before.dof_amount * c.reduce_blur_factor, _EPS)
