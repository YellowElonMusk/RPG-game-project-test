## Story 023, AC-20: `FollowCamera`'s dead zone, `tau` ease, `dt_max` clamp
## and ground-footprint clamp match the GDD `follow_camera` formula exactly.
## Every case drives the pure static functions directly against a synthetic
## target and `dt` -- no scene tree, per the Implementation Notes. Each
## formula piece is also run once with a non-default config.
extends GdUnitTestSuite

const FollowCamera := preload("res://src/presentation/follow_camera.gd")

## The Formulas example camera: h=10m, pitch=30 deg, F_v=20 deg.
const _EXAMPLE_HEIGHT := 10.0
const _EXAMPLE_PITCH := 30.0
const _EXAMPLE_FOV := 20.0
const _SIXTEEN_NINE := 16.0 / 9.0
const _TWENTYONE_NINE := 21.0 / 9.0
const _FOUR_THREE := 4.0 / 3.0


# --- dead zone / ease_step --------------------------------------------------

func test_ease_step_inside_dead_zone_does_not_move_camera() -> void:
	var cam := Vector2(0.0, 0.0)
	var target := Vector2(0.5, -0.5)
	var dz := Vector2(1.0, 1.0)

	var result: Vector2 = FollowCamera.ease_step(cam, target, dz, 0.17, 1.0 / 60.0, 0.10)

	assert_vector(result).is_equal(cam)


## Outside the dead zone, the movement equals the formula within 1e-4 m;
## run once more with a non-default tau/dt_max to exercise those knobs too.
func test_ease_step_outside_dead_zone_matches_formula(
		tau: float, dt_max: float, test_parameters := [[0.17, 0.10], [0.15, 0.05]]) -> void:
	var cam := Vector2(0.0, 0.0)
	var target := Vector2(5.0, -3.0)
	var dz := Vector2(1.0, 0.5)
	var dt := 1.0 / 60.0

	var result: Vector2 = FollowCamera.ease_step(cam, target, dz, tau, dt, dt_max)

	var offset: Vector2 = target - cam
	var excess := Vector2(offset.x - clampf(offset.x, -dz.x, dz.x), offset.y - clampf(offset.y, -dz.y, dz.y))
	var factor: float = 1.0 - exp(-minf(dt, dt_max) / tau)
	var expected: Vector2 = cam + excess * factor

	assert_vector(result).is_equal_approx(expected, Vector2(0.0001, 0.0001))


## `dt = 0.5` clamps to `dt_max`, so the two frames move identically.
func test_ease_step_dt_above_dt_max_matches_dt_max() -> void:
	var cam := Vector2(0.0, 0.0)
	var target := Vector2(5.0, 2.0)
	var dz := Vector2(0.5, 0.5)
	var dt_max := 0.10

	var at_dt_max: Vector2 = FollowCamera.ease_step(cam, target, dz, 0.17, dt_max, dt_max)
	var at_large_dt: Vector2 = FollowCamera.ease_step(cam, target, dz, 0.17, 0.5, dt_max)

	assert_vector(at_large_dt).is_equal(at_dt_max)


# --- frame-rate independence -----------------------------------------------

## 60 fps and 30 fps agree within 1e-3 m at every shared 1/30 s step, and
## the camera never passes the static target on either axis.
func test_ease_step_agrees_across_frame_rates_and_never_overshoots() -> void:
	var target := Vector2(5.0, 3.0)
	var dz := Vector2(0.2, 0.2)
	var tau := 0.17
	var dt_max := 0.10

	var cam60 := Vector2.ZERO
	var cam30 := Vector2.ZERO
	# 2 steps of 1/60 s per 1 step of 1/30 s, for 30 shared steps (1 second).
	for shared_step in range(30):
		for _sub_step in range(2):
			cam60 = FollowCamera.ease_step(cam60, target, dz, tau, 1.0 / 60.0, dt_max)
		cam30 = FollowCamera.ease_step(cam30, target, dz, tau, 1.0 / 30.0, dt_max)

		assert_vector(cam60).is_equal_approx(cam30, Vector2(0.001, 0.001))
		assert_float(cam60.x).is_less_equal(target.x)
		assert_float(cam60.y).is_less_equal(target.y)
		assert_float(cam30.x).is_less_equal(target.x)
		assert_float(cam30.y).is_less_equal(target.y)


## With the dead zone at 0 and a static target 2 m away, at 60 fps, frame 15
## (t = 0.25 s) has covered at least 75% of the distance for every `tau` in
## the safe range.
func test_ease_step_covers_seventy_five_percent_by_frame_fifteen(
		tau: float, test_parameters := [[0.15], [0.17], [0.18]]) -> void:
	var cam := Vector2.ZERO
	var target := Vector2(2.0, 0.0)
	var dz := Vector2.ZERO
	var dt := 1.0 / 60.0
	var dt_max := 0.10

	for _frame in range(15):
		cam = FollowCamera.ease_step(cam, target, dz, tau, dt, dt_max)

	assert_float(cam.x).is_greater_equal(target.x * 0.75)
	assert_float(cam.x).is_less_equal(target.x)


# --- footprint ---------------------------------------------------------------

## The Formulas example camera gives a_near, a_far and w_far of 5.40, 10.15
## and 9.03 m at 16:9, within 1e-2.
func test_compute_footprint_matches_gdd_worked_example() -> void:
	var footprint: FollowCamera.Footprint = FollowCamera.compute_footprint(
			_EXAMPLE_HEIGHT, _EXAMPLE_PITCH, _EXAMPLE_FOV, _SIXTEEN_NINE)

	assert_float(footprint.a_near).is_equal_approx(5.40, 0.01)
	assert_float(footprint.a_far).is_equal_approx(10.15, 0.01)
	assert_float(footprint.w_far).is_equal_approx(9.03, 0.01)


## With the target driven into every edge and corner of a 60x40 m map, at
## 16:9, 21:9 and 4:3, the clamped focus point's footprint rectangle stays
## inside the map on every frame -- which is exactly what keeps the ground
## hits of the view's four corner rays inside the map (`w_far` is the
## footprint's widest point, conservative over the near corners too).
func test_clamp_to_footprint_keeps_ground_footprint_inside_map(
		aspect: float, test_parameters := [[_SIXTEEN_NINE], [_TWENTYONE_NINE], [_FOUR_THREE]]) -> void:
	var footprint: FollowCamera.Footprint = FollowCamera.compute_footprint(
			_EXAMPLE_HEIGHT, _EXAMPLE_PITCH, _EXAMPLE_FOV, aspect)
	var map_min := Vector2(0.0, 0.0)
	var map_max := Vector2(60.0, 40.0)
	var corners: Array[Vector2] = [
		Vector2(-1000.0, -1000.0), Vector2(1000.0, -1000.0),
		Vector2(-1000.0, 1000.0), Vector2(1000.0, 1000.0), Vector2(30.0, 20.0),
	]

	for raw_target in corners:
		var cam: Vector2 = FollowCamera.clamp_to_footprint(raw_target, footprint, map_min, map_max)

		assert_float(cam.x - footprint.w_far).is_greater_equal(map_min.x - 0.0001)
		assert_float(cam.x + footprint.w_far).is_less_equal(map_max.x + 0.0001)
		assert_float(cam.y - footprint.a_near).is_greater_equal(map_min.y - 0.0001)
		assert_float(cam.y + footprint.a_far).is_less_equal(map_max.y + 0.0001)


# --- horizon guard -----------------------------------------------------------

## A camera config with `pitch - F_v_eff(4:3)/2` 0.1 deg below
## `horizon_margin` fails validation, even though the same margin would
## pass if checked at 16:9 (demonstrating the guard checks 4:3, the
## narrowest supported aspect, and not 16:9).
func test_validate_horizon_fails_at_four_three_margin_even_though_sixteen_nine_would_pass() -> void:
	var footprint_4_3: FollowCamera.Footprint = FollowCamera.compute_footprint(
			_EXAMPLE_HEIGHT, _EXAMPLE_PITCH, _EXAMPLE_FOV, _FOUR_THREE)
	var margin_at_4_3: float = _EXAMPLE_PITCH - footprint_4_3.f_v_eff_degrees * 0.5
	var horizon_margin: float = margin_at_4_3 + 0.1

	var passes: bool = FollowCamera.validate_horizon(
			_EXAMPLE_HEIGHT, _EXAMPLE_PITCH, _EXAMPLE_FOV, horizon_margin)

	assert_bool(passes).is_false()

	# The same (pitch, F_v, margin) would pass if the guard used 16:9 instead.
	var footprint_16_9: FollowCamera.Footprint = FollowCamera.compute_footprint(
			_EXAMPLE_HEIGHT, _EXAMPLE_PITCH, _EXAMPLE_FOV, _SIXTEEN_NINE)
	var margin_at_16_9: float = _EXAMPLE_PITCH - footprint_16_9.f_v_eff_degrees * 0.5
	assert_float(margin_at_16_9).is_greater_equal(horizon_margin)


## The exact boundary (`pitch - F_v_eff(4:3)/2 == horizon_margin`) passes
## (`>=`, not `>`).
func test_validate_horizon_passes_at_exact_boundary() -> void:
	var footprint_4_3: FollowCamera.Footprint = FollowCamera.compute_footprint(
			_EXAMPLE_HEIGHT, _EXAMPLE_PITCH, _EXAMPLE_FOV, _FOUR_THREE)
	var margin_at_4_3: float = _EXAMPLE_PITCH - footprint_4_3.f_v_eff_degrees * 0.5

	var passes: bool = FollowCamera.validate_horizon(
			_EXAMPLE_HEIGHT, _EXAMPLE_PITCH, _EXAMPLE_FOV, margin_at_4_3)

	assert_bool(passes).is_true()


# --- from_config --------------------------------------------------------------

## `from_config()` copies every `PresentationConfig.follow_camera_*` field.
func test_from_config_copies_every_camera_field() -> void:
	var config := PresentationConfig.new()
	config.follow_camera_height = 12.0
	config.follow_camera_pitch_degrees = 35.0
	config.follow_camera_fov_degrees = 18.0
	config.follow_camera_dead_zone_fraction = 0.08
	config.follow_camera_tau = 0.15
	config.follow_camera_dt_max = 0.08
	config.follow_camera_horizon_margin_degrees = 6.0

	var camera: FollowCamera = auto_free(FollowCamera.from_config(config))

	assert_float(camera.height).is_equal(12.0)
	assert_float(camera.pitch_degrees).is_equal(35.0)
	assert_float(camera.fov_degrees).is_equal(18.0)
	assert_float(camera.dead_zone_fraction).is_equal(0.08)
	assert_float(camera.tau).is_equal(0.15)
	assert_float(camera.dt_max).is_equal(0.08)
	assert_float(camera.horizon_margin_degrees).is_equal(6.0)
