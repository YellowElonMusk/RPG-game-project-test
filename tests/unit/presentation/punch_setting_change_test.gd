## Story 045, AC-41 (GDD Edge Cases "If the Screen Shake or Reduce Motion
## setting changes mid-punch"; ADR-0005 §6, ADR-0009 §7): with a punch
## running, Screen Shake -> Off and Reduce Motion -> On each zero the very
## next frame's offset on their own; Screen Shake -> Reduced uses the new
## `A_peak` at the unchanged elapsed `t`. Checked both on `HitPunch`'s pixel
## offset and on the battle camera's `frustum_offset`, whose lens-shift
## component is held fixed so only the punch term varies. The setting reaches
## the punch through an injected `PresentationSettings` view.
extends GdUnitTestSuite

const _STAGE_PATH := "res://data/presentation/stages/battle_default.tres"
const _DT := 1.0 / 60.0
const _VIEWPORTS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(3840, 2160)]
## Frames the punch runs before the setting flips (mid-punch at every config).
const _FRAMES_BEFORE := 2


func _config(non_default: bool) -> PresentationConfig:
	var config := PresentationConfig.new()
	if non_default:
		config.punch_duration = 0.12
		config.punch_amplitude_big = 8.0
		config.reaction_hold = 0.30
	return config


## Round half away from zero, independent of `HitPunch`.
func _rhaz(value: float) -> int:
	return int(signf(value) * floorf(absf(value) + 0.5))


## The GDD `hit_punch` offset with Reduced shake at `t`, from config.
func _expected_reduced(t: float, config: PresentationConfig, h: int, dir: Vector2) -> Vector2i:
	var a_full: int = _rhaz(config.punch_amplitude_big * float(h) / 1080.0)
	var a_peak: int = maxi(1, a_full / 2) if a_full > 0 else 0
	if t >= config.punch_duration:
		return Vector2i.ZERO
	var k: float = (1.0 - t / config.punch_duration) * (1.0 - t / config.punch_duration)
	return Vector2i(_rhaz(dir.x * a_peak * k), _rhaz(dir.y * a_peak * k))


## A battle-configured stage (not in the tree) and a running Full punch,
## already `_FRAMES_BEFORE` frames in.
func _running(config: PresentationConfig, settings: PresentationSettings,
		viewport: Vector2i, dir: Vector2) -> Array:
	var stage: DioramaStage = auto_free(DioramaStage.new())
	stage.camera = auto_free(Camera3D.new())
	stage.configure_battle_camera(load(_STAGE_PATH) as BattleStage, config, viewport)
	var punch := HitPunch.new(config, settings)
	punch.start(config.punch_amplitude_big, dir)
	for frame: int in _FRAMES_BEFORE:
		punch.advance(_DT)
	return [stage, punch]


## The next frame as the Battle mode drives it: offset from the punch, written
## to the stage's `frustum_offset`.
func _frame(stage: DioramaStage, punch: HitPunch, h: int) -> Vector2i:
	var offset: Vector2i = punch.current_offset_px(h)
	stage.set_punch_offset_px(offset)
	return offset


func _assert_frustum(stage: DioramaStage, offset: Vector2i, h: int) -> void:
	var expected: Vector2 = stage.battle_base_shift() + BattleFraming.punch_lens_shift(
			offset, stage.camera.size, h)
	assert_vector(stage.camera.frustum_offset).is_equal_approx(expected, Vector2(1e-9, 1e-9))


func test_screen_shake_off_alone_zeroes_the_next_frame(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var config := _config(non_default)
	for viewport: Vector2i in _VIEWPORTS:
		var settings := PresentationSettings.new()
		var pair: Array = _running(config, settings, viewport, Vector2.RIGHT)
		var stage: DioramaStage = pair[0]
		var punch: HitPunch = pair[1]
		var running: Vector2i = _frame(stage, punch, viewport.y)
		assert_that(running).is_not_equal(Vector2i.ZERO)
		var base: Vector2 = stage.battle_base_shift()
		settings.screen_shake = PresentationSettings.ScreenShake.OFF
		assert_bool(settings.reduce_motion).is_false()
		assert_that(_frame(stage, punch, viewport.y)).is_equal(Vector2i.ZERO)
		assert_vector(stage.camera.frustum_offset).is_equal(base)
		assert_bool(punch.is_running()).is_true()  # t keeps running; only A_peak is 0


func test_reduce_motion_on_alone_zeroes_the_next_frame(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var config := _config(non_default)
	for viewport: Vector2i in _VIEWPORTS:
		var settings := PresentationSettings.new()
		var pair: Array = _running(config, settings, viewport, Vector2.DOWN)
		var stage: DioramaStage = pair[0]
		var punch: HitPunch = pair[1]
		assert_that(_frame(stage, punch, viewport.y)).is_not_equal(Vector2i.ZERO)
		var base: Vector2 = stage.battle_base_shift()
		settings.reduce_motion = true
		assert_int(settings.screen_shake).is_equal(PresentationSettings.ScreenShake.FULL)
		assert_that(_frame(stage, punch, viewport.y)).is_equal(Vector2i.ZERO)
		assert_vector(stage.camera.frustum_offset).is_equal(base)


func test_reduced_uses_the_new_peak_at_the_unchanged_t(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var config := _config(non_default)
	for viewport: Vector2i in _VIEWPORTS:
		var settings := PresentationSettings.new()
		var pair: Array = _running(config, settings, viewport, Vector2.LEFT)
		var stage: DioramaStage = pair[0]
		var punch: HitPunch = pair[1]
		_frame(stage, punch, viewport.y)
		var t: float = punch.elapsed()
		var base: Vector2 = stage.battle_base_shift()
		settings.screen_shake = PresentationSettings.ScreenShake.REDUCED
		var offset: Vector2i = _frame(stage, punch, viewport.y)
		assert_float(punch.elapsed()).is_equal(t)
		assert_that(offset).is_equal(_expected_reduced(t, config, viewport.y, Vector2.LEFT))
		assert_vector(stage.battle_base_shift()).is_equal(base)
		_assert_frustum(stage, offset, viewport.y)
		# Keeps decaying from the same t on later frames.
		punch.advance(_DT)
		var later: Vector2i = _frame(stage, punch, viewport.y)
		assert_that(later).is_equal(_expected_reduced(t + _DT, config, viewport.y, Vector2.LEFT))
		_assert_frustum(stage, later, viewport.y)
