## Story 068, AC-63 (GDD rule 13 and `flash_gate` "exempt by swing"; ADR-0005
## §3/§7, ADR-0009 §7): in Camp, the campfire flicker's luminance swing with
## Reduce Flashing On is half its swing with it Off, within 1e-4, on every
## frame; the mean and frequency are unchanged; the setting is read live
## through the injected `FlashSettings` view; the flicker runs on mode time.
extends GdUnitTestSuite

const _CAMP_PATH := "res://data/presentation/profiles/camp.tres"
const _DT := 1.0 / 60.0
## Ten seconds of frames at 60 Hz.
const _FRAMES := 600
const _EPS := 1e-4


func _camp_stage(settings: FlashSettings) -> DioramaStage:
	var stage: DioramaStage = auto_free(DioramaStage.new())
	stage.flash_settings = settings
	stage.apply_profile(load(_CAMP_PATH) as LightingProfile, 0.0)
	return stage


func test_camp_ships_a_flicker_below_the_flash_threshold() -> void:
	var camp := load(_CAMP_PATH) as LightingProfile
	assert_float(camp.practical_flicker_swing).is_greater(0.0)
	assert_float(camp.practical_flicker_swing).is_less(PresentationConfig.FLASH_LUMA_DELTA)
	assert_float(camp.practical_flicker_rate).is_greater(0.0)


func test_reduce_flashing_halves_the_swing_on_every_frame() -> void:
	var off_settings := FlashSettings.new()
	var on_settings := FlashSettings.new()
	on_settings.reduce_flashing_on = true
	var off_stage := _camp_stage(off_settings)
	var on_stage := _camp_stage(on_settings)
	var mean: float = off_stage.current_values.practical_flicker_mean
	var off_min: float = INF
	var off_max: float = -INF
	var on_min: float = INF
	var on_max: float = -INF
	var moved: bool = false
	for frame: int in _FRAMES:
		var t: float = float(frame) * _DT
		var off_luma: float = off_stage.campfire_flicker_luma(t)
		var on_luma: float = on_stage.campfire_flicker_luma(t)
		assert_float(on_luma - mean).override_failure_message("frame %d" % frame) \
				.is_equal_approx(0.5 * (off_luma - mean), _EPS)
		moved = moved or absf(off_luma - mean) > 1e-3
		off_min = minf(off_min, off_luma)
		off_max = maxf(off_max, off_luma)
		on_min = minf(on_min, on_luma)
		on_max = maxf(on_max, on_luma)
	assert_bool(moved).override_failure_message("the flicker never moved").is_true()
	assert_float(on_max - on_min).is_equal_approx(0.5 * (off_max - off_min), _EPS)
	# Peak-to-peak never exceeds the authored swing (so it stays exempt).
	assert_float(off_max - off_min).is_less_equal(
			off_stage.current_values.practical_flicker_swing + _EPS)


func test_reduce_flashing_change_applies_on_the_next_frame() -> void:
	var settings := FlashSettings.new()
	var stage := _camp_stage(settings)
	var reference := _camp_stage(FlashSettings.new())
	var mean: float = stage.current_values.practical_flicker_mean
	for frame: int in _FRAMES:
		var t: float = float(frame) * _DT
		if frame == 137:
			settings.reduce_flashing_on = true
		if frame == 411:
			settings.reduce_flashing_on = false
		var scale: float = 0.5 if (frame >= 137 and frame < 411) else 1.0
		assert_float(stage.campfire_flicker_luma(t) - mean).is_equal_approx(
				scale * (reference.campfire_flicker_luma(t) - mean), _EPS)


## The flicker is a function of mode time only: a frozen mode time (the Menu)
## holds the exact value; no profile without a flicker moves.
func test_flicker_runs_on_mode_time_and_only_where_authored() -> void:
	var stage := _camp_stage(FlashSettings.new())
	assert_float(stage.campfire_flicker_luma(3.25)).is_equal(stage.campfire_flicker_luma(3.25))
	var battle: DioramaStage = auto_free(DioramaStage.new())
	battle.flash_settings = FlashSettings.new()
	battle.apply_profile(load("res://data/presentation/profiles/battle.tres") as LightingProfile, 0.0)
	for frame: int in 120:
		assert_float(battle.campfire_flicker_luma(float(frame) * _DT)).is_equal(
				battle.current_values.practical_flicker_mean)


## A stage with no `FlashSettings` injected reads Reduce Flashing as Off.
func test_missing_settings_reads_as_off() -> void:
	var with_off := _camp_stage(FlashSettings.new())
	var without := _camp_stage(null)
	for frame: int in 60:
		var t: float = float(frame) * _DT
		assert_float(without.campfire_flicker_luma(t)).is_equal(with_off.campfire_flicker_luma(t))
