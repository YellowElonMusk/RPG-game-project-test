## Story 019 (AC-16's ΔE): `ColorDifference` reproduces the CIEDE2000
## reference data of Sharma, Wu & Dalal (2005), and sRGB -> CIELAB (D65)
## gives the textbook white, black and primary values.
extends GdUnitTestSuite


## [L1, a1, b1, L2, a2, b2, ΔE00] -- Sharma et al. 2005, Table 1 (pairs 1, 7,
## 17, 25, 33).
func test_delta_e_2000_matches_sharma_reference_pairs(l1: float, a1: float, b1: float,
		l2: float, a2: float, b2: float, expected: float, test_parameters := [
			[50.0, 2.6772, -79.7751, 50.0, 0.0, -82.7485, 2.0425],
			[50.0, 0.0, 0.0, 50.0, -1.0, 2.0, 2.3669],
			[50.0, 2.5, 0.0, 73.0, 25.0, -18.0, 27.1492],
			[60.2574, -34.0099, 36.2677, 60.4626, -34.1751, 39.4387, 1.2644],
			[2.0776, 0.0795, -1.135, 0.9033, -0.0636, -0.5514, 0.9082]]) -> void:
	var de: float = ColorDifference.delta_e_2000(Vector3(l1, a1, b1), Vector3(l2, a2, b2))
	assert_float(de).is_equal_approx(expected, 1e-4)
	# Symmetric.
	assert_float(ColorDifference.delta_e_2000(Vector3(l2, a2, b2), Vector3(l1, a1, b1))) \
			.is_equal_approx(expected, 1e-4)


func test_srgb_to_lab_white_black_and_red() -> void:
	var white: Vector3 = ColorDifference.srgb_to_lab(Color.WHITE)
	assert_float(white.x).is_equal_approx(100.0, 0.01)
	assert_float(white.y).is_equal_approx(0.0, 0.01)
	assert_float(white.z).is_equal_approx(0.0, 0.01)
	var black: Vector3 = ColorDifference.srgb_to_lab(Color.BLACK)
	assert_float(black.x).is_equal_approx(0.0, 0.01)
	var red: Vector3 = ColorDifference.srgb_to_lab(Color(1, 0, 0))
	assert_float(red.x).is_equal_approx(53.24, 0.05)
	assert_float(red.y).is_equal_approx(80.09, 0.1)
	assert_float(red.z).is_equal_approx(67.20, 0.1)


func test_identical_colors_are_zero_apart() -> void:
	assert_float(ColorDifference.delta_e_srgb(Color("#d23a2e"), Color("#d23a2e"))) \
			.is_equal_approx(0.0, 1e-6)
