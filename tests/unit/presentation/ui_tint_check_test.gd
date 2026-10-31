## Story sprite-camera-presentation 057 (AC-53, TR-presentation-024): the UI
## layer is never tinted by the world's tonemapper. The measurement itself
## needs a GPU and a window (`tools/capture/ui_tint_capture.gd`, evidence in
## `production/qa/evidence/ui-never-tinted/`); this suite checks what the
## verdict is computed from: the UI-alone opacity mask (the UI rendered over
## black and over white), the ΔE 1 every-pixel verdict, the failure map, and
## the fixture environments (the world under AgX, and the negative control
## that routes the UI canvas through the world's tonemapper).
extends GdUnitTestSuite

const _BATTLE_PROFILE: String = "res://data/presentation/profiles/battle.tres"


## A `w` x `h` RGBA8 image filled with `c`.
func _solid(w: int, h: int, c: Color) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return img


## An L8 mask, white inside `rect`.
func _mask(w: int, h: int, rect: Rect2i) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_L8)
	img.fill_rect(rect, Color.WHITE)
	return img


# -- opaque mask from the UI over black and over white --

func test_ui_opaque_mask_opaque_pixels_equal_on_both_backgrounds() -> void:
	var on_black: Image = _solid(4, 1, Color.BLACK)
	var on_white: Image = _solid(4, 1, Color.WHITE)
	# Pixel 0: an opaque red UI pixel, the same over either background.
	on_black.set_pixel(0, 0, Color8(200, 40, 30))
	on_white.set_pixel(0, 0, Color8(200, 40, 30))
	# Pixel 1: half-transparent grey -- differs with the background.
	on_black.set_pixel(1, 0, Color8(64, 64, 64))
	on_white.set_pixel(1, 0, Color8(191, 191, 191))
	var m: Dictionary = CaptureChecks.ui_opaque_mask(on_black, on_white)
	var img: Image = m["image"]
	assert_int(int(m["pixels"])).is_equal(1)
	assert_float(img.get_pixel(0, 0).r).is_greater(0.5)
	assert_float(img.get_pixel(1, 0).r).is_less(0.5)
	assert_float(img.get_pixel(2, 0).r).is_less(0.5)


func test_ui_opaque_mask_one_level_rounding_still_opaque() -> void:
	var on_black: Image = _solid(1, 1, Color8(100, 100, 100))
	var on_white: Image = _solid(1, 1, Color8(101, 100, 99))
	var m: Dictionary = CaptureChecks.ui_opaque_mask(on_black, on_white)
	assert_int(int(m["pixels"])).is_equal(1)


func test_ui_opaque_mask_size_mismatch_empty() -> void:
	var m: Dictionary = CaptureChecks.ui_opaque_mask(_solid(2, 2, Color.RED), _solid(3, 3, Color.RED))
	assert_int(int(m["pixels"])).is_equal(0)


# -- the AC-53 verdict: ΔE <= 1 on every opaque UI pixel --

func test_ui_tint_verdict_identical_pixels_pass() -> void:
	var a: Image = _solid(6, 6, Color8(40, 50, 70))
	var stats: Dictionary = CaptureChecks.masked_delta_e(a, a.duplicate() as Image, _mask(6, 6, Rect2i(0, 0, 6, 6)))
	assert_bool(bool(CaptureChecks.ui_tint_verdict(stats)["pass"])).is_true()


func test_ui_tint_verdict_one_pixel_over_limit_fails() -> void:
	var a: Image = _solid(10, 10, Color8(40, 50, 70))
	var b: Image = a.duplicate() as Image
	# "On every pixel": one tinted pixel among 100 fails, though the mean is tiny.
	b.set_pixel(3, 3, Color8(60, 50, 70))
	var stats: Dictionary = CaptureChecks.masked_delta_e(a, b, _mask(10, 10, Rect2i(0, 0, 10, 10)))
	assert_float(float(stats["mean"])).is_less(CaptureChecks.UI_TINT_DELTA_E_MAX)
	var v: Dictionary = CaptureChecks.ui_tint_verdict(stats)
	assert_bool(bool(v["pass"])).is_false()
	assert_int((v["failures"] as PackedStringArray).size()).is_equal(1)


func test_ui_tint_verdict_no_opaque_pixels_is_invalid_not_pass() -> void:
	var v: Dictionary = CaptureChecks.ui_tint_verdict({"pixels": 0, "mean": 0.0, "p95": 0.0, "max": 0.0})
	assert_bool(bool(v["pass"])).is_false()


func test_ui_tint_limit_is_delta_e_one() -> void:
	assert_float(CaptureChecks.UI_TINT_DELTA_E_MAX).is_equal(1.0)


# -- failure map --

func test_delta_e_failure_map_marks_only_masked_pixels_over_limit() -> void:
	var a: Image = _solid(3, 1, Color8(40, 50, 70))
	var b: Image = a.duplicate() as Image
	b.set_pixel(0, 0, Color8(90, 50, 70))   # over, inside the mask
	b.set_pixel(2, 0, Color8(90, 50, 70))   # over, outside the mask
	var m: Dictionary = CaptureChecks.delta_e_failure_map(a, b, _mask(3, 1, Rect2i(0, 0, 2, 1)),
			CaptureChecks.UI_TINT_DELTA_E_MAX)
	var img: Image = m["image"]
	assert_int(int(m["pixels"])).is_equal(1)
	assert_float(img.get_pixel(0, 0).r).is_greater(0.5)
	assert_float(img.get_pixel(1, 0).r).is_less(0.5)
	assert_float(img.get_pixel(2, 0).r).is_less(0.5)


# -- fixture environments --

func _shipped_env() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = -1
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	return env


func test_world_agx_environment_applies_profile_tone() -> void:
	var p: LightingProfile = load(_BATTLE_PROFILE) as LightingProfile
	var base: Environment = _shipped_env()
	var env: Environment = UiTintFixture.world_agx(base, p)
	assert_int(env.tonemap_mode).is_equal(Environment.TONE_MAPPER_AGX)
	assert_float(env.tonemap_exposure).is_equal_approx(p.exposure, 1e-6)
	assert_float(env.tonemap_agx_white).is_equal_approx(p.agx_white, 1e-6)
	assert_float(env.tonemap_agx_contrast).is_equal_approx(p.agx_contrast, 1e-6)
	# The UI stays out of the world: the background canvas range is untouched.
	assert_int(env.background_canvas_max_layer).is_equal(-1)
	# A copy: the shipped environment is not modified.
	assert_int(base.tonemap_mode).is_equal(Environment.TONE_MAPPER_LINEAR)


func test_ui_through_world_fixture_puts_ui_layers_in_background_canvas() -> void:
	var p: LightingProfile = load(_BATTLE_PROFILE) as LightingProfile
	var env: Environment = UiTintFixture.ui_through_world(_shipped_env(), p, 10)
	assert_int(env.tonemap_mode).is_equal(Environment.TONE_MAPPER_AGX)
	assert_int(env.background_mode).is_equal(Environment.BG_CANVAS)
	assert_int(env.background_canvas_max_layer).is_equal(10)
