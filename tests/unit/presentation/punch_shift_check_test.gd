## Story 025 (GDD sprite-camera-presentation AC-21b; ADR-0005 §6, §13): the
## measurement the punch capture relies on. `PunchShiftCheck.best_shift()`
## finds the whole-pixel shift that maps an ID-pass region with no punch
## onto the same region at the punch's peak, exactly; `verdict()` passes only
## when every measured class moved by the same expected shift with no
## mismatched pixel and an unambiguous best. Synthetic images only.
extends GdUnitTestSuite

const SIZE := Vector2i(96, 64)
const RADIUS: int = 7


func _blank() -> Image:
	return Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)


func _rect(img: Image, r: Rect2i, c: Color) -> void:
	img.fill_rect(r, c)


func test_a_block_moved_up_five_pixels_measures_zero_minus_five_exactly() -> void:
	# Arrange: an irregular shape (two blocks) and the same shape 5 px higher.
	var a := _blank()
	var b := _blank()
	_rect(a, Rect2i(30, 30, 12, 20), Color.RED)
	_rect(a, Rect2i(42, 40, 6, 4), Color.RED)
	_rect(b, Rect2i(30, 25, 12, 20), Color.RED)
	_rect(b, Rect2i(42, 35, 6, 4), Color.RED)
	# Act
	var m: Dictionary = PunchShiftCheck.best_shift(a, b, Rect2i(16, 16, 48, 40), RADIUS)
	# Assert
	assert_that(m["shift"]).is_equal(Vector2i(0, -5))
	assert_int(int(m["mismatch"])).is_equal(0)
	assert_int(int(m["runner_up"])).is_greater(0)
	assert_int(int(m["pixels"])).is_greater(0)


func test_no_punch_measures_zero_shift() -> void:
	var a := _blank()
	_rect(a, Rect2i(40, 20, 8, 8), Color.GREEN)
	var m: Dictionary = PunchShiftCheck.best_shift(a, a.duplicate() as Image, Rect2i(20, 8, 48, 40), RADIUS)
	assert_that(m["shift"]).is_equal(Vector2i.ZERO)
	assert_int(int(m["mismatch"])).is_equal(0)


func test_a_shape_that_stretched_has_no_exact_shift() -> void:
	# A translation of near and far by different amounts (what a translation
	# shake would do) cannot be matched by one whole-pixel shift.
	var a := _blank()
	var b := _blank()
	_rect(a, Rect2i(30, 30, 10, 10), Color.RED)
	_rect(a, Rect2i(50, 30, 10, 10), Color.RED)
	_rect(b, Rect2i(30, 27, 10, 10), Color.RED)
	_rect(b, Rect2i(50, 25, 10, 10), Color.RED)
	var m: Dictionary = PunchShiftCheck.best_shift(a, b, Rect2i(16, 12, 60, 40), RADIUS)
	assert_int(int(m["mismatch"])).is_greater(0)


func test_an_l8_class_mask_measures_like_rgba_and_bounds_its_content() -> void:
	# The capture's class masks are L8 (black = not the class, no alpha).
	var a := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_L8)
	var b := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_L8)
	a.fill_rect(Rect2i(40, 30, 6, 9), Color.WHITE)
	b.fill_rect(Rect2i(40, 35, 6, 9), Color.WHITE)
	assert_that(PunchShiftCheck.content_rect(a)).is_equal(Rect2i(40, 30, 6, 9))
	assert_that(PunchShiftCheck.content_rect(_blank())).is_equal(Rect2i())
	var m: Dictionary = PunchShiftCheck.best_shift(a, b, Rect2i(20, 16, 50, 40), RADIUS)
	assert_that(m["shift"]).is_equal(Vector2i(0, 5))
	assert_int(int(m["mismatch"])).is_equal(0)
	assert_int(int(m["pixels"])).is_equal(54)


func test_verdict_passes_only_when_every_class_moved_by_the_expected_shift() -> void:
	var ok := {"shift": Vector2i(0, -5), "mismatch": 0, "runner_up": 12, "pixels": 100}
	var off := {"shift": Vector2i(0, -4), "mismatch": 0, "runner_up": 12, "pixels": 100}
	var smeared := {"shift": Vector2i(0, -5), "mismatch": 3, "runner_up": 12, "pixels": 100}
	var empty := {"shift": Vector2i.ZERO, "mismatch": 0, "runner_up": 0, "pixels": 0}
	assert_bool(PunchShiftCheck.verdict({"near": ok, "far": ok, "set": ok}, Vector2i(0, -5))["pass"]).is_true()
	assert_bool(PunchShiftCheck.verdict({"near": ok, "far": off}, Vector2i(0, -5))["pass"]).is_false()
	assert_bool(PunchShiftCheck.verdict({"near": ok, "set": smeared}, Vector2i(0, -5))["pass"]).is_false()
	assert_bool(PunchShiftCheck.verdict({"near": ok, "set": empty}, Vector2i(0, -5))["pass"]).is_false()
	assert_bool(PunchShiftCheck.verdict({}, Vector2i(0, -5))["pass"]).is_false()
