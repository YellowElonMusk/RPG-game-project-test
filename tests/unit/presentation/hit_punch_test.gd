## Stories 012 (AC-10), 014 (AC-12), 021 (AC-18) and 024 (AC-21): the
## battle hit-punch (GDD `design/gdd/sprite-camera-presentation.md` rule 8
## and Formulas `hit_punch`; ADR-0005 §6). `HitPunch` is driven frame by
## frame with an injected window height and an injected
## `PresentationSettings` view (no SettingsService exists yet). Expected
## values are computed independently from config through the formula, and
## each formula test also runs with a non-default config.
extends GdUnitTestSuite

const _STAGE_PATH := "res://data/presentation/stages/battle_default.tres"
const _DT := 1.0 / 60.0
const _HEIGHTS: Array[int] = [720, 1080, 1440, 2160]
const _DIRS: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
## AC-21's play duration: at dt = 1/60 no frame lands on a tie or on D.
const _PLAY_D := 0.105
## A 1x action wind-up for the replay simulations (seconds, before speed).
const _WINDUP_1X := 0.30


func _config(non_default: bool) -> PresentationConfig:
	var config := PresentationConfig.new()
	if non_default:
		config.punch_duration = 0.12
		config.punch_amplitude_normal = 2.0
		config.punch_amplitude_big = 8.0
		config.reaction_hold = 0.30
		config.ff_mult = 2.5
	return config


## Round half away from zero, written independently of `HitPunch`.
func _rhaz(value: float) -> int:
	return int(signf(value) * floorf(absf(value) + 0.5))


func _expected_peak(a_beat: float, h: int, shake: PresentationSettings.ScreenShake,
		reduce: bool) -> int:
	var a_full: int = _rhaz(a_beat * float(h) / 1080.0)
	if reduce or shake == PresentationSettings.ScreenShake.OFF:
		return 0
	if shake == PresentationSettings.ScreenShake.REDUCED:
		return maxi(1, a_full / 2) if a_full > 0 else 0
	return a_full


func _expected_offset(t: float, d: float, a_peak: int, dir: Vector2) -> Vector2i:
	if t < 0.0 or t >= d:
		return Vector2i.ZERO
	var k: float = (1.0 - t / d) * (1.0 - t / d)
	return Vector2i(_rhaz(dir.x * float(a_peak) * k), _rhaz(dir.y * float(a_peak) * k))


# --- AC-21 (story 024): the formula ----------------------------------------

func test_offset_px_matches_formula_at_1080p_and_2160p(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var config := _config(non_default)
	var d: float = config.punch_duration
	for h: int in [1080, 2160]:
		for a_beat: float in [config.punch_amplitude_normal, config.punch_amplitude_big]:
			var a_peak: int = HitPunch.full_amplitude(a_beat, h)
			assert_int(a_peak).is_equal(_rhaz(a_beat * float(h) / 1080.0))
			for dir: Vector2 in _DIRS:
				for frac: float in [0.0, 0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9, 0.999, 1.0, 1.5]:
					var t: float = d * frac
					assert_that(HitPunch.offset_px(t, d, a_peak, dir)) \
							.override_failure_message("h %d a %.1f dir %s t %.4f" % [h, a_beat, dir, t]) \
							.is_equal(_expected_offset(t, d, a_peak, dir))


## The tie is the point here: A_peak = 2 at t = D/2 is exactly 0.5 -> 1 px.
func test_tie_peak_two_at_half_duration_rounds_away_to_one_px(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var d: float = _config(non_default).punch_duration
	assert_that(HitPunch.offset_px(d / 2.0, d, 2, Vector2.RIGHT)).is_equal(Vector2i(1, 0))
	assert_that(HitPunch.offset_px(d / 2.0, d, 2, Vector2.LEFT)).is_equal(Vector2i(-1, 0))
	assert_that(HitPunch.offset_px(d / 2.0, d, 2, Vector2.UP)).is_equal(Vector2i(0, -1))


## The GDD's worked example (big beat 7 px, Reduced, t = 0.05 of D = 0.10).
func test_gdd_worked_example_reduced_big_beat() -> void:
	var a_1080: int = HitPunch.peak_amplitude(HitPunch.full_amplitude(7.0, 1080),
			PresentationSettings.ScreenShake.REDUCED, false)
	var a_2160: int = HitPunch.peak_amplitude(HitPunch.full_amplitude(7.0, 2160),
			PresentationSettings.ScreenShake.REDUCED, false)
	assert_int(a_1080).is_equal(3)
	assert_int(a_2160).is_equal(7)
	assert_that(HitPunch.offset_px(0.05, 0.10, a_1080, Vector2.RIGHT)).is_equal(Vector2i(1, 0))
	assert_that(HitPunch.offset_px(0.05, 0.10, a_2160, Vector2.RIGHT)).is_equal(Vector2i(2, 0))


## In play at dt = 1/60 with D = 0.105: non-zero on the impact frame, never
## changes sign, never exceeds A_peak, never grows, and 0 from the first
## frame at or after D.
func test_play_at_60hz_starts_on_impact_decays_without_sign_change(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var config := _config(non_default)
	config.punch_duration = _PLAY_D
	for h: int in [1080, 2160]:
		for dir: Vector2 in _DIRS:
			var punch := HitPunch.new(config)
			var a_peak: int = _expected_peak(config.punch_amplitude_big, h,
					PresentationSettings.ScreenShake.FULL, false)
			assert_bool(punch.on_impact(-5, true, false, dir)).is_true()
			var previous: int = a_peak
			for frame: int in 12:
				var offset: Vector2i = punch.current_offset_px(h)
				var signed: int = offset.x * int(dir.x) + offset.y * int(dir.y)
				var t: float = float(frame) * _DT
				if frame == 0:
					assert_int(signed).is_equal(a_peak)
				if t >= _PLAY_D:
					assert_that(offset).is_equal(Vector2i.ZERO)
				else:
					assert_that(offset).is_equal(_expected_offset(t, _PLAY_D, a_peak, dir))
				assert_int(signed).is_between(0, a_peak)
				assert_int(signed).is_less_equal(previous)
				# Only the punch's own axis ever moves.
				assert_int(offset.x * int(dir.y) + offset.y * int(dir.x)).is_equal(0)
				previous = signed
				punch.advance(_DT)


## A full replay latched at ff_mult: wind-ups run at ff_mult, the reaction
## hold never speeds up, so no punch starts while another is non-zero.
func test_latched_replay_never_starts_a_punch_over_a_running_one(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var config := _config(non_default)
	var punch := HitPunch.new(config)
	var beats: int = 8
	var period: float = _WINDUP_1X / config.ff_mult + config.reaction_hold
	var next_beat: int = 0
	var frame: int = 0
	while next_beat < beats:
		var now: float = float(frame) * _DT
		var impact_at: float = float(next_beat) * period + _WINDUP_1X / config.ff_mult
		if now >= impact_at:
			assert_that(punch.current_offset_px(1080)).is_equal(Vector2i.ZERO)
			assert_bool(punch.is_running()).is_false()
			assert_bool(punch.on_impact(-3, false, false, Vector2.RIGHT)).is_true()
			next_beat += 1
		punch.advance(_DT)
		frame += 1
	assert_int(punch.started_count).is_equal(beats)
	assert_int(punch.refused_count).is_equal(0)


## The guard itself: a start while a punch is still running is refused.
func test_start_while_running_is_refused() -> void:
	var config := _config(false)
	var punch := HitPunch.new(config)
	assert_bool(punch.start(config.punch_amplitude_normal, Vector2.RIGHT)).is_true()
	punch.advance(_DT)
	assert_bool(punch.start(config.punch_amplitude_big, Vector2.LEFT)).is_false()
	assert_int(punch.refused_count).is_equal(1)
	assert_float(punch.elapsed()).is_equal_approx(_DT, 1e-9)


## The ADR-0005 §6 erratum (story 024): the lens shift moves the image BY the
## offset on screen, at every depth, per the GDD. Checked through the CPU
## projection the battle camera uses.
func test_punch_lens_shift_moves_image_by_offset(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var config := _config(non_default)
	var viewport := Vector2i(1920, 1080)
	var aspect: float = float(viewport.x) / float(viewport.y)
	var h_near: float = BattleFraming.h_near(config.battle_camera_near, config.battle_fov_degrees, aspect)
	var base: Vector2 = BattleFraming.base_lens_shift(0.30, h_near)
	var xf := Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, 10.0))
	var rest := SpriteProjection.CameraState.from_frustum(xf, h_near, aspect, base,
			config.battle_camera_near, config.battle_camera_far)
	for punch_px: Vector2i in [Vector2i(3, 0), Vector2i(-7, 0), Vector2i(0, 5), Vector2i(0, -2)]:
		var shifted := SpriteProjection.CameraState.from_frustum(xf, h_near, aspect,
				base + BattleFraming.punch_lens_shift(punch_px, h_near, viewport.y),
				config.battle_camera_near, config.battle_camera_far)
		for point: Vector3 in [Vector3(0.0, 0.0, 0.0), Vector3(-2.0, 1.0, -5.0), Vector3(3.0, 0.5, -30.0)]:
			var delta: Vector2 = SpriteProjection.project_to_screen(point, shifted, viewport) \
					- SpriteProjection.project_to_screen(point, rest, viewport)
			assert_float(delta.x).is_equal_approx(float(punch_px.x), 1e-3)
			assert_float(delta.y).is_equal_approx(float(punch_px.y), 1e-3)


# --- AC-10 (story 012): one punch per beat, on impact ----------------------

class Beat:
	var hp_delta: int
	var knocked_out: bool
	var actor_is_boss: bool

	func _init(p_hp_delta: int, p_knocked_out: bool, p_actor_is_boss: bool) -> void:
		hp_delta = p_hp_delta
		knocked_out = p_knocked_out
		actor_is_boss = p_actor_is_boss


func test_replay_of_hp_lowering_beats_starts_one_punch_each_on_impact(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var config := _config(non_default)
	var beats: Array[Beat] = [Beat.new(-4, false, false), Beat.new(-9, true, false),
			Beat.new(-2, false, true), Beat.new(-1, false, false), Beat.new(-12, true, true)]
	var punch := HitPunch.new(config)
	var starts: Array = []  # [frame, a_beat] pairs; Array box for the lambda.
	var frame_box: Array[int] = [0]
	punch.started.connect(func(a_beat: float, _dir: Vector2) -> void:
		starts.append([frame_box[0], a_beat]))
	var period: float = _WINDUP_1X + config.reaction_hold
	var impact_frames: Array[int] = []
	var next_beat: int = 0
	while next_beat < beats.size():
		var now: float = float(frame_box[0]) * _DT
		if now >= float(next_beat) * period + _WINDUP_1X:
			var beat: Beat = beats[next_beat]
			impact_frames.append(frame_box[0])
			punch.on_impact(beat.hp_delta, beat.knocked_out, beat.actor_is_boss, Vector2.RIGHT)
			assert_that(punch.current_offset_px(1080)).is_not_equal(Vector2i.ZERO)
			next_beat += 1
		punch.advance(_DT)
		frame_box[0] += 1
	assert_int(starts.size()).is_equal(beats.size())
	for i: int in beats.size():
		var big: bool = beats[i].knocked_out or beats[i].actor_is_boss
		assert_int(starts[i][0]).is_equal(impact_frames[i])
		assert_float(starts[i][1]).is_equal(
				config.punch_amplitude_big if big else config.punch_amplitude_normal)


## Heal, Defend, Speak to the Manager, Viral Stunt and a 0-damage Attack:
## none lowers HP, so none punches (boss actor or not).
func test_non_damaging_outcome_starts_no_punch(hp_delta: int, actor_is_boss: bool,
		test_parameters := [[12, false], [0, false], [0, true], [7, true]]) -> void:
	var punch := HitPunch.new(_config(false))
	assert_bool(punch.on_impact(hp_delta, false, actor_is_boss, Vector2.RIGHT)).is_false()
	assert_int(punch.started_count).is_equal(0)
	assert_that(punch.current_offset_px(1080)).is_equal(Vector2i.ZERO)


# --- AC-18 (story 021): comfort settings ------------------------------------

func test_off_or_reduce_motion_on_keeps_offset_zero(shake: int, reduce: bool,
		test_parameters := [
			[PresentationSettings.ScreenShake.OFF, false],
			[PresentationSettings.ScreenShake.OFF, true],
			[PresentationSettings.ScreenShake.REDUCED, true],
			[PresentationSettings.ScreenShake.FULL, true]]) -> void:
	var config := _config(false)
	var settings := PresentationSettings.with_values(shake as PresentationSettings.ScreenShake, reduce)
	for h: int in _HEIGHTS:
		var punch := HitPunch.new(config, settings)
		punch.on_impact(-20, true, true, Vector2.DOWN)
		for frame: int in 10:
			assert_that(punch.current_offset_px(h)).is_equal(Vector2i.ZERO)
			punch.advance(_DT)


func test_reduced_peak_is_half_floored_never_below_one(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var config := _config(non_default)
	var reduced := PresentationSettings.with_values(PresentationSettings.ScreenShake.REDUCED, false)
	for h: int in _HEIGHTS:
		for a_beat: float in [config.punch_amplitude_normal, config.punch_amplitude_big]:
			var punch := HitPunch.new(config, reduced)
			punch.start(a_beat, Vector2.RIGHT)
			var expected: int = _expected_peak(a_beat, h, PresentationSettings.ScreenShake.REDUCED, false)
			assert_int(punch.current_peak(h)).is_equal(expected)
			assert_int(expected).is_greater_equal(1)
	# The floor-to-zero case never happens: A_full 1 -> 1, A_full 0 -> 0.
	assert_int(HitPunch.peak_amplitude(1, PresentationSettings.ScreenShake.REDUCED, false)).is_equal(1)
	assert_int(HitPunch.peak_amplitude(0, PresentationSettings.ScreenShake.REDUCED, false)).is_equal(0)


## AC-18's boundary: 720p, A_beat = 2, Reduced -> 1, not 0.
func test_reduced_at_720p_with_a_beat_two_is_one() -> void:
	assert_int(HitPunch.peak_amplitude(HitPunch.full_amplitude(2.0, 720),
			PresentationSettings.ScreenShake.REDUCED, false)).is_equal(1)


## Reduced changes amplitude only: the punch runs for the same frames.
func test_reduced_keeps_the_same_duration(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var config := _config(non_default)
	var full := HitPunch.new(config, PresentationSettings.with_values(
			PresentationSettings.ScreenShake.FULL, false))
	var reduced := HitPunch.new(config, PresentationSettings.with_values(
			PresentationSettings.ScreenShake.REDUCED, false))
	full.start(config.punch_amplitude_big, Vector2.RIGHT)
	reduced.start(config.punch_amplitude_big, Vector2.RIGHT)
	for frame: int in 12:
		assert_bool(reduced.is_running()).is_equal(full.is_running())
		assert_float(reduced.elapsed()).is_equal(full.elapsed())
		full.advance(_DT)
		reduced.advance(_DT)


## The setting is read live: a change mid-punch applies on the next frame,
## with t unchanged.
func test_settings_change_mid_punch_applies_next_frame() -> void:
	var config := _config(false)
	var settings := PresentationSettings.new()
	var punch := HitPunch.new(config, settings)
	punch.start(config.punch_amplitude_big, Vector2.RIGHT)
	punch.advance(_DT)
	var t: float = punch.elapsed()
	assert_that(punch.current_offset_px(2160)).is_not_equal(Vector2i.ZERO)
	settings.reduce_motion = true
	assert_that(punch.current_offset_px(2160)).is_equal(Vector2i.ZERO)
	settings.reduce_motion = false
	settings.screen_shake = PresentationSettings.ScreenShake.REDUCED
	var peak: int = _expected_peak(config.punch_amplitude_big, 2160,
			PresentationSettings.ScreenShake.REDUCED, false)
	assert_that(punch.current_offset_px(2160)).is_equal(
			_expected_offset(t, config.punch_duration, peak, Vector2.RIGHT))
	assert_float(punch.elapsed()).is_equal(t)


# --- AC-12 (story 014): actors never move -----------------------------------

func test_punch_never_moves_an_actor_world_position() -> void:
	var config := _config(false)
	var stage := DioramaStage.new()
	var cam := Camera3D.new()
	stage.add_child(cam)
	stage.camera = cam
	var actors: Array[CharacterSprite] = []
	for pos: Vector3 in [Vector3(-2.0, 0.0, -3.0), Vector3(0.5, 0.0, -6.0), Vector3(3.0, 0.0, -12.0)]:
		var sprite := CharacterSprite.new()
		sprite.position = pos
		stage.add_child(sprite)
		actors.append(sprite)
	add_child(stage)
	auto_free(stage)
	var viewport := Vector2i(1920, 1080)
	stage.configure_battle_camera(load(_STAGE_PATH) as BattleStage, config, viewport)
	var cam_xf: Transform3D = cam.global_transform
	var before: Array[Transform3D] = []
	for sprite: CharacterSprite in actors:
		before.append(sprite.global_transform)
	var punch := HitPunch.new(config)
	var moved_view: Array[bool] = [false]
	for beat: int in 3:
		punch.on_impact(-5, beat == 2, false, _DIRS[beat])
		for frame: int in 8:
			stage.set_punch_offset_px(punch.current_offset_px(stage.battle_viewport_height()))
			if stage.punch_offset_px() != Vector2i.ZERO:
				moved_view[0] = true
				assert_that(cam.frustum_offset).is_not_equal(stage.battle_base_shift())
			for i: int in actors.size():
				assert_that(actors[i].global_transform).is_equal(before[i])
				assert_that(actors[i].scale).is_equal(Vector3.ONE)
				assert_that(actors[i].rotation).is_equal(Vector3.ZERO)
			assert_that(cam.global_transform).is_equal(cam_xf)
			assert_float(cam.h_offset).is_equal(0.0)
			assert_float(cam.v_offset).is_equal(0.0)
			punch.advance(_DT)
	assert_bool(moved_view[0]).is_true()
	assert_that(cam.frustum_offset).is_equal(stage.battle_base_shift())


# --- AC-11 (story 013): a punch during a boss takeover is dropped -----------

## A battle stage (not in the tree) entered on Battle, with a takeover clock.
func _takeover_stage(config: PresentationConfig, clock: Callable) -> DioramaStage:
	var stage: DioramaStage = auto_free(DioramaStage.new())
	stage.camera = auto_free(Camera3D.new())
	stage.configure_battle_camera(load(_STAGE_PATH) as BattleStage, config, Vector2i(1920, 1080))
	var battle := LightingProfile.new()
	var boss := LightingProfile.new()
	boss.set_energy = 2.0
	stage.bind_profiles(func(id: StringName) -> LightingProfile:
			return boss if String(id).begins_with("boss_") else battle)
	stage.apply_profile(battle, 0.0)
	return stage


## Runs `frames` frames the way the Battle mode does, asserting no offset.
func _assert_no_punch(stage: DioramaStage, punch: HitPunch, frames: int, clock_t: Array[float]) -> void:
	var base: Vector2 = stage.battle_base_shift()
	for frame: int in frames:
		clock_t[0] += _DT
		stage.refresh_clock_blend()
		var offset: Vector2i = punch.current_offset_px(stage.battle_viewport_height())
		stage.set_punch_offset_px(offset)
		assert_that(offset).is_equal(Vector2i.ZERO)
		assert_that(stage.camera.frustum_offset).is_equal(base)
		punch.advance(_DT)


func test_punch_requested_during_takeover_blend_is_dropped_never_deferred() -> void:
	var config := _config(false)
	var clock_t: Array[float] = [0.0]
	var stage := _takeover_stage(config, func() -> float: return clock_t[0])
	stage.request_profile(&"boss_megacorp", config.blend_boss, func() -> float: return clock_t[0])
	var punch := HitPunch.new(config)
	punch.takeover_active = stage.is_takeover_active
	clock_t[0] = config.blend_boss * 0.5
	stage.refresh_clock_blend()
	assert_bool(stage.is_takeover_active()).is_true()

	assert_bool(punch.on_impact(-20, false, true, Vector2.RIGHT)).is_false()
	assert_bool(punch.start(config.punch_amplitude_big, Vector2.LEFT)).is_false()

	assert_int(punch.started_count).is_equal(0)
	assert_int(punch.dropped_count).is_equal(2)
	assert_int(punch.refused_count).is_equal(0)
	assert_bool(punch.is_running()).is_false()
	# Through the rest of the blend and well past it: nothing ever plays.
	_assert_no_punch(stage, punch, 120, clock_t)
	assert_bool(stage.is_takeover_active()).is_false()
	assert_int(punch.started_count).is_equal(0)


func test_punch_requested_during_takeover_hold_is_dropped_and_later_beats_punch() -> void:
	var config := _config(false)
	var clock_t: Array[float] = [0.0]
	var stage := _takeover_stage(config, func() -> float: return clock_t[0])
	stage.request_profile(&"boss_bureaucratia", config.blend_boss, func() -> float: return clock_t[0])
	clock_t[0] = config.blend_boss + 0.01
	stage.refresh_clock_blend()
	assert_bool(stage.is_blending()).is_false()
	stage.takeover_hold_active = true
	var punch := HitPunch.new(config)
	punch.takeover_active = stage.is_takeover_active

	assert_bool(punch.on_impact(-20, true, true, Vector2.DOWN)).is_false()
	_assert_no_punch(stage, punch, 30, clock_t)
	stage.takeover_hold_active = false
	_assert_no_punch(stage, punch, 30, clock_t)
	assert_int(punch.started_count).is_equal(0)

	# Only a new request after the takeover punches.
	assert_bool(punch.on_impact(-5, false, false, Vector2.RIGHT)).is_true()
	assert_that(punch.current_offset_px(1080)).is_not_equal(Vector2i.ZERO)


## The stage itself never shows a punch offset during a takeover, whoever asks.
func test_stage_ignores_a_punch_offset_during_takeover() -> void:
	var config := _config(false)
	var clock_t: Array[float] = [0.0]
	var stage := _takeover_stage(config, func() -> float: return clock_t[0])
	stage.request_profile(&"boss_megacorp", config.blend_boss, func() -> float: return clock_t[0])
	clock_t[0] = 0.1
	stage.refresh_clock_blend()
	stage.set_punch_offset_px(Vector2i(4, 0))
	assert_that(stage.punch_offset_px()).is_equal(Vector2i.ZERO)
	assert_that(stage.camera.frustum_offset).is_equal(stage.battle_base_shift())


## A non-boss clock blend is not a takeover.
func test_non_boss_blend_does_not_gate_the_punch() -> void:
	var config := _config(false)
	var clock_t: Array[float] = [0.0]
	var stage := _takeover_stage(config, func() -> float: return clock_t[0])
	stage.request_profile(&"battle", 0.5, func() -> float: return clock_t[0])
	clock_t[0] = 0.2
	stage.refresh_clock_blend()
	assert_bool(stage.is_takeover_active()).is_false()
	var punch := HitPunch.new(config)
	punch.takeover_active = stage.is_takeover_active
	assert_bool(punch.on_impact(-5, false, false, Vector2.RIGHT)).is_true()
