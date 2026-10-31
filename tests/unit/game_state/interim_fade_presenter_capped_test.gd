## Regression (story 060 Finding 2; ADR-0002 amendment, ADR-0008 §8, GDD
## sprite-camera-presentation rule 13 / `flash_gate`): `InterimFadePresenter`
## ignored `capped`, so with Reduce Flashing On the refused battle wipe and
## retry flash still played the full Ink Navy fade. A capped transition must
## play its capped variant: a swell whose worst-case luminance swing (over a
## white screen) stays below the source's declared `capped_luma_swing`, and
## never the full cover.
extends GdUnitTestSuite

const _SOURCES: Array[StringName] = [&"battle_wipe", &"battle_wipe_reverse", &"retry_flash"]

var _layer: CanvasLayer


func before_test() -> void:
	_layer = auto_free(CanvasLayer.new()) as CanvasLayer
	add_child(_layer)


func _rect() -> ColorRect:
	return _layer.get_child(0) as ColorRect


## Relative luminance (WCAG, linear RGB) of an sRGB colour.
static func _luma(c: Color) -> float:
	var lin: Color = c.srgb_to_linear()
	return 0.2126 * lin.r + 0.7152 * lin.g + 0.0722 * lin.b


func test_capped_out_never_reaches_the_full_cover() -> void:
	var presenter := InterimFadePresenter.new(_layer)
	for source: StringName in _SOURCES:
		presenter.play_out(source, 0.0, true)
		assert_float(_rect().modulate.a).override_failure_message(
				"%s capped OUT played the full cover (alpha %.3f)" % [source, _rect().modulate.a]).is_less(0.5)
		presenter.play_in(source, 0.0, true)
		assert_float(_rect().modulate.a).is_equal(0.0)


func test_capped_peak_swing_is_below_each_declared_cap() -> void:
	var presenter := InterimFadePresenter.new(_layer)
	for source: StringName in _SOURCES:
		var decl := load("res://data/presentation/flash_sources/%s.tres" % source) as FlashSourceDecl
		presenter.play_out(source, 0.0, true)
		var a: float = _rect().modulate.a
		# Worst case: the fade over pure white (sRGB blend, as the 2D canvas draws).
		var over_white: Color = Color.WHITE.lerp(_rect().color, a)
		var swing: float = _luma(Color.WHITE) - _luma(over_white)
		assert_float(swing).override_failure_message(
				"%s capped swing %.3f >= declared %.3f" % [source, swing, decl.capped_luma_swing]) \
				.is_less(decl.capped_luma_swing)


func test_uncapped_out_still_covers_and_locks_input() -> void:
	var presenter := InterimFadePresenter.new(_layer)
	presenter.play_out(&"retry_flash", 0.0, false)
	assert_float(_rect().modulate.a).is_equal(1.0)
	assert_int(_rect().mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)


func test_capped_out_still_locks_input() -> void:
	var presenter := InterimFadePresenter.new(_layer)
	presenter.play_out(&"retry_flash", 0.0, true)
	assert_int(_rect().mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	presenter.play_in(&"retry_flash", 0.0, true)
	assert_int(_rect().mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
