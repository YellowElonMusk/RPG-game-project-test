## Story 060 (GDD sprite-camera-presentation AC-55b, Formulas `flash_gate`;
## test plan P-13): the flash analyser that reads composited frames.
## `FlashAnalyser` classifies general and red transitions on linear R, G, B
## (WCAG 2.2 SC 2.3.1, the GDD's own definitions), counts a change only when
## it covers `flash_area_min` of some 10° window `(4/9)·H × (1/3)·H`, and
## counts flashes with the gate's conservative N − 1 rule per closed
## one-second window. Synthetic frames only: values are written as linear
## light and encoded to sRGB bytes, as a screen grab would hold them.
extends GdUnitTestSuite

## Analysis frame size: H = 36 gives a 16 × 12 window (192 px; 25% = 48 px).
const W: int = 64
const H: int = 36
const FPS: int = 60
const BLACK := Color(0.0, 0.0, 0.0)
const WHITE := Color(1.0, 1.0, 1.0)


## A frame filled with `linear`, encoded to sRGB bytes (what a grab holds).
func _frame(linear: Color) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	img.fill(linear.linear_to_srgb())
	return img


## `base` with `rect` filled with `linear` (sRGB-encoded).
func _frame_with(base_linear: Color, rect: Rect2i, linear: Color) -> Image:
	var img := _frame(base_linear)
	img.fill_rect(rect, linear.linear_to_srgb())
	return img


## Feeds `frames` copies of `linear` to `a`.
func _hold(a: FlashAnalyser, linear: Color, frames: int) -> void:
	for i: int in frames:
		a.add_frame(_frame(linear))


func _gray(v: float) -> Color:
	return Color(v, v, v)


func test_flash_analyser_window_size_is_four_ninths_by_one_third_of_height() -> void:
	assert_that(FlashAnalyser.window_size(36)).is_equal(Vector2i(16, 12))
	assert_that(FlashAnalyser.window_size(1080)).is_equal(Vector2i(480, 360))


func test_flash_analyser_static_frames_have_no_transition_and_pass() -> void:
	# Arrange
	var a := FlashAnalyser.new()
	# Act
	_hold(a, _gray(0.2), 90)
	# Assert
	assert_int(a.frame_count()).is_equal(90)
	assert_int(a.events().size()).is_equal(0)
	assert_int(a.max_flashes_in_window(FlashAnalyser.GENERAL)).is_equal(0)
	assert_bool(a.passes()).is_true()


func test_flash_analyser_four_alternations_in_one_second_count_four_flashes_and_fail() -> void:
	# Arrange: black, then white/black every 10 frames: transitions at 10
	# (up), 20, 30, 40, 50: five transitions, N - 1 = 4 flashes (20..50).
	var a := FlashAnalyser.new()
	_hold(a, BLACK, 10)
	for k: int in 5:
		_hold(a, WHITE if k % 2 == 0 else BLACK, 10)
	# Assert
	assert_int(a.events().size()).is_equal(5)
	assert_bool(bool(a.events()[0]["rising"])).is_true()
	assert_int(int(a.events()[0]["frame"])).is_equal(10)
	assert_that(a.flash_frames(FlashAnalyser.GENERAL)).is_equal(PackedInt32Array([20, 30, 40, 50]))
	assert_int(a.max_flashes_in_window(FlashAnalyser.GENERAL)).is_equal(4)
	assert_bool(a.passes()).is_false()


func test_flash_analyser_three_flashes_in_one_second_pass_at_rate_max_three() -> void:
	var a := FlashAnalyser.new()
	_hold(a, BLACK, 10)
	for k: int in 4:
		_hold(a, WHITE if k % 2 == 0 else BLACK, 10)
	_hold(a, BLACK, 60)
	assert_int(a.max_flashes_in_window(FlashAnalyser.GENERAL)).is_equal(3)
	assert_bool(a.passes()).is_true()


func test_flash_analyser_flashes_exactly_one_second_apart_share_a_closed_window() -> void:
	# Flashes at frames 20, 30, 40 and then 80: 80 - 20 = 60 frames = 1.0 s,
	# so the closed window [20, 80] holds four.
	var a := FlashAnalyser.new()
	_hold(a, BLACK, 10)
	for k: int in 4:
		_hold(a, WHITE if k % 2 == 0 else BLACK, 10)
	_hold(a, BLACK, 30)   # frames 50..79
	_hold(a, WHITE, 10)   # up at frame 80, a flash (opposes the down at 40)
	assert_that(a.flash_frames(FlashAnalyser.GENERAL)).is_equal(PackedInt32Array([20, 30, 40, 80]))
	assert_int(a.max_flashes_in_window(FlashAnalyser.GENERAL)).is_equal(4)
	assert_bool(a.passes()).is_false()


func test_flash_analyser_flashes_just_over_one_second_apart_do_not_share_a_window() -> void:
	var a := FlashAnalyser.new()
	_hold(a, BLACK, 10)
	for k: int in 4:
		_hold(a, WHITE if k % 2 == 0 else BLACK, 10)
	_hold(a, BLACK, 31)   # frames 50..80
	_hold(a, WHITE, 10)   # up at frame 81: 61 frames after 20
	assert_int(a.max_flashes_in_window(FlashAnalyser.GENERAL)).is_equal(3)
	assert_bool(a.passes()).is_true()


func test_flash_analyser_rate_max_is_a_parameter() -> void:
	var a := FlashAnalyser.new(FPS, 0.10, 0.25, 2.0)
	_hold(a, BLACK, 10)
	for k: int in 4:
		_hold(a, WHITE if k % 2 == 0 else BLACK, 10)
	assert_int(a.max_flashes_in_window(FlashAnalyser.GENERAL)).is_equal(3)
	assert_bool(a.passes()).is_false()


func test_flash_analyser_swing_below_luma_delta_is_not_a_transition() -> void:
	# 0.30 <-> 0.39 relative luminance: a 0.09 swing, under 0.10.
	var a := FlashAnalyser.new()
	for k: int in 12:
		_hold(a, _gray(0.30 if k % 2 == 0 else 0.39), 5)
	assert_int(a.events().size()).is_equal(0)
	assert_bool(a.passes()).is_true()


func test_flash_analyser_swing_at_luma_delta_is_a_transition() -> void:
	var a := FlashAnalyser.new()
	for k: int in 12:
		_hold(a, _gray(0.30 if k % 2 == 0 else 0.42), 5)
	assert_int(a.events().size()).is_greater(4)
	assert_bool(a.passes()).is_false()


func test_flash_analyser_swing_whose_darker_state_is_above_0_80_is_not_general() -> void:
	var a := FlashAnalyser.new()
	for k: int in 12:
		_hold(a, _gray(0.85 if k % 2 == 0 else 1.0), 5)
	assert_int(a.events().size()).is_equal(0)


func test_flash_analyser_slow_ramp_is_one_transition_and_no_flash() -> void:
	# 0 -> 0.5 over 60 frames: per-frame steps far under 0.10, one swing.
	var a := FlashAnalyser.new()
	for i: int in 61:
		a.add_frame(_frame(_gray(0.5 * float(i) / 60.0)))
	_hold(a, _gray(0.5), 30)
	var rising: int = 0
	for e: Dictionary in a.events():
		rising += 1 if bool(e["rising"]) else 0
	assert_int(rising).is_equal(1)
	assert_int(a.events().size()).is_equal(1)
	assert_int(a.flash_frames(FlashAnalyser.GENERAL).size()).is_equal(0)


func test_flash_analyser_change_under_area_min_of_every_window_is_not_counted() -> void:
	# A 6 x 7 = 42 px square toggling: under 48 px (25% of 16 x 12).
	var a := FlashAnalyser.new()
	var r := Rect2i(20, 10, 6, 7)
	for k: int in 12:
		a.add_frame(_frame_with(BLACK, r, WHITE if k % 2 == 1 else BLACK))
		for i: int in 4:
			a.add_frame(_frame_with(BLACK, r, WHITE if k % 2 == 1 else BLACK))
	assert_int(a.events().size()).is_equal(0)
	assert_bool(a.passes()).is_true()


func test_flash_analyser_change_at_area_min_of_one_window_is_counted() -> void:
	# An 8 x 6 = 48 px square toggling: exactly 25% of a 16 x 12 window.
	var a := FlashAnalyser.new()
	var r := Rect2i(40, 20, 8, 6)
	for k: int in 12:
		for i: int in 5:
			a.add_frame(_frame_with(BLACK, r, WHITE if k % 2 == 1 else BLACK))
	assert_int(a.events().size()).is_equal(11)
	assert_float(float(a.events()[0]["coverage"])).is_equal_approx(0.25, 1e-6)
	assert_bool(a.passes()).is_false()


func test_flash_analyser_saturated_red_swing_counts_as_red_not_general() -> void:
	# Linear (0.3, 0, 0) <-> black: luminance swing 0.064 (not general),
	# (R - G - B) * 320 swing 96 (> 20), saturated red: a red transition.
	var a := FlashAnalyser.new()
	_hold(a, BLACK, 10)
	for k: int in 5:
		_hold(a, Color(0.3, 0.0, 0.0) if k % 2 == 0 else BLACK, 10)
	assert_int(a.flash_frames(FlashAnalyser.GENERAL).size()).is_equal(0)
	assert_that(a.flash_frames(FlashAnalyser.RED)).is_equal(PackedInt32Array([20, 30, 40, 50]))
	assert_int(a.max_flashes_in_window(FlashAnalyser.RED)).is_equal(4)
	assert_bool(a.passes()).is_false()


func test_flash_analyser_desaturated_red_swing_is_not_red() -> void:
	# R / (R + G + B) = 0.3 / 0.5 = 0.6 < 0.8: never saturated red.
	var a := FlashAnalyser.new()
	_hold(a, BLACK, 10)
	for k: int in 5:
		_hold(a, Color(0.3, 0.1, 0.1) if k % 2 == 0 else BLACK, 10)
	assert_int(a.flash_frames(FlashAnalyser.RED).size()).is_equal(0)


func test_flash_analyser_flashes_outside_spans_lists_only_unattributed_flashes() -> void:
	var a := FlashAnalyser.new()
	_hold(a, BLACK, 10)
	for k: int in 5:
		_hold(a, WHITE if k % 2 == 0 else BLACK, 10)
	var spans: Array[Vector2i] = [Vector2i(15, 35)]
	assert_that(a.flashes_outside(spans)).is_equal(PackedInt32Array([40, 50]))


func test_flash_analyser_luma_series_holds_each_frames_mean_relative_luminance() -> void:
	var a := FlashAnalyser.new()
	a.add_frame(_frame(BLACK))
	a.add_frame(_frame(_gray(0.5)))
	var s: PackedFloat32Array = a.luma_series()
	assert_int(s.size()).is_equal(2)
	assert_float(s[0]).is_equal_approx(0.0, 1e-3)
	assert_float(s[1]).is_equal_approx(0.5, 5e-3)


func test_flash_analyser_to_analysis_halves_until_near_target_height() -> void:
	var big := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	big.fill(Color(0.5, 0.5, 0.5))
	var small: Image = FlashAnalyser.to_analysis(big, 90)
	assert_that(small.get_size()).is_equal(Vector2i(160, 90))
	assert_int(small.get_format()).is_equal(Image.FORMAT_RGB8)
