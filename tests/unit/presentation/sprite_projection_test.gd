## Story 004, AC-2: `SpriteProjection` returns an exact, pixel-snapped quad
## at the foot anchor for any camera and frame size. `T` at the five GDD
## reference heights, the rectangle's `frame_w*T x frame_h*T` dimensions,
## the round-half-away-from-zero anchor and the `x_left` odd-width rule
## (GDD `texel_scale`); `card_normal`'s ground-projection; one `card_depth`
## sanity check on the optical axis. gdUnit4 `test_parameters`; a
## single-arg case list is wrapped per-case (`[[a], [b]]`).
extends GdUnitTestSuite

const SpriteProjection := preload("res://src/presentation/sprite_projection.gd")

## (viewport_height, expected_t) -- GDD `texel_scale` Output Range.
const _REFERENCE_HEIGHTS: Array = [
	[720, 2], [1080, 3], [1440, 4], [2160, 6], [900, 2],
]

const _BASE_LINES := 360


## A camera at world origin looking down -Z (Godot's default forward),
## built with a symmetric orthogonal projection so `screen_rect`'s pixel
## math is exercised with an exact, hand-computable mapping: world x/y in
## [-10, 10] maps linearly to NDC [-1, 1], independent of any frustum/fov
## numeric detail. `anchor_z` only needs to stay within [near, far].
static func _ortho_cam(cam_transform: Transform3D) -> SpriteProjection.CameraState:
	var proj: Projection = Projection.create_orthogonal(-10.0, 10.0, -10.0, 10.0, 0.05, 100.0)
	return SpriteProjection.CameraState.new(
			cam_transform, proj, 20.0, 0.05, Camera3D.KEEP_HEIGHT, Vector2.ZERO)


func test_texel_scale_matches_formula_at_reference_heights(
		height: int, expected_t: int, test_parameters := _REFERENCE_HEIGHTS) -> void:
	assert_int(SpriteProjection.texel_scale(height, _BASE_LINES)).is_equal(expected_t)


func test_texel_scale_floors_between_reference_heights() -> void:
	# 900p: floor(900/360) = 2, not rounded up to 3 (GDD Output Range).
	assert_int(SpriteProjection.texel_scale(900, _BASE_LINES)).is_equal(2)


func test_texel_scale_never_goes_below_one() -> void:
	assert_int(SpriteProjection.texel_scale(100, _BASE_LINES)).is_equal(1)


## Dimensions are exactly `frame_w*T x frame_h*T`, at every reference
## height, with an on-axis anchor (even viewport dims avoid a .5 pixel so
## this test isolates the dimension formula from rounding).
func test_screen_rect_dimensions_equal_frame_times_t(
		height: int, expected_t: int, test_parameters := _REFERENCE_HEIGHTS) -> void:
	var cam: SpriteProjection.CameraState = _ortho_cam(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 5.0)))
	var viewport_size := Vector2i(1600, height)
	var frame_size := Vector2i(24, 32)

	var rect: Rect2i = SpriteProjection.screen_rect(
			Vector3.ZERO, cam, frame_size, viewport_size, _BASE_LINES)

	assert_vector(Vector2(rect.size)).is_equal(Vector2(frame_size.x * expected_t, frame_size.y * expected_t))


## The rectangle's bottom edge sits at the anchor's rounded screen y, and
## its left edge follows `x_left = x_a - floor(frame_w*T / 2)` -- an odd
## viewport forces a .5 fractional anchor pixel (0.5*641 = 320.5,
## 0.5*481 = 240.5), proving round-half-away-from-zero on both axes.
func test_screen_rect_bottom_centre_is_rounded_anchor_half_away_from_zero() -> void:
	var cam: SpriteProjection.CameraState = _ortho_cam(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 5.0)))
	var viewport_size := Vector2i(641, 481)
	var frame_size := Vector2i(11, 7)  # odd width -> T=1 at this height

	var rect: Rect2i = SpriteProjection.screen_rect(
			Vector3.ZERO, cam, frame_size, viewport_size, _BASE_LINES)

	var t: int = SpriteProjection.texel_scale(viewport_size.y, _BASE_LINES)
	var anchor_x := 321  # round(320.5) away from zero
	var anchor_y := 241  # round(240.5) away from zero
	assert_int(rect.position.x).is_equal(anchor_x - ((frame_size.x * t) / 2))
	assert_int(rect.position.y + rect.size.y).is_equal(anchor_y)


## Replicates the GDD's own worked example: a 33-texel-wide frame at
## T=3 (1080p) with its anchor at screen x=813 has left edge 764 and right
## edge 863 (33 columns of exactly 3 px each).
func test_screen_rect_x_left_matches_gdd_worked_example() -> void:
	var cam: SpriteProjection.CameraState = _ortho_cam(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.0)))
	var viewport_size := Vector2i(1000, 1080)
	var anchor_world := Vector3(6.25, 0.0, -5.0)  # ndc.x = 6.25/10 = 0.625 -> screen_x = 812.5 -> 813

	var rect: Rect2i = SpriteProjection.screen_rect(
			anchor_world, cam, Vector2i(33, 10), viewport_size, _BASE_LINES)

	assert_int(rect.position.x).is_equal(764)
	assert_int(rect.position.x + rect.size.x).is_equal(863)


## A level camera's card normal is the camera's forward direction,
## unaffected by any roll-free horizontal offset of the anchor.
func test_card_normal_level_camera_is_forward() -> void:
	var cam: SpriteProjection.CameraState = _ortho_cam(Transform3D(Basis.IDENTITY, Vector3.ZERO))
	assert_vector(SpriteProjection.card_normal(cam)).is_equal_approx(
			Vector3(0.0, 0.0, -1.0), Vector3(0.0001, 0.0001, 0.0001))


## Pitch (rotation about the camera's local X axis) never changes the
## card normal: it is the forward direction's ground projection, and pitch
## only tilts forward's Y component, which the ground projection discards.
func test_card_normal_ignores_pitch() -> void:
	var transform := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(20.0)), Vector3.ZERO)
	var cam: SpriteProjection.CameraState = _ortho_cam(transform)
	assert_vector(SpriteProjection.card_normal(cam)).is_equal_approx(
			Vector3(0.0, 0.0, -1.0), Vector3(0.0001, 0.0001, 0.0001))


## Yaw (rotation about world Y) rotates the card normal with it.
func test_card_normal_follows_yaw() -> void:
	var transform := Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3.ZERO)
	var cam: SpriteProjection.CameraState = _ortho_cam(transform)
	assert_vector(SpriteProjection.card_normal(cam)).is_equal_approx(
			Vector3(-1.0, 0.0, 0.0), Vector3(0.0001, 0.0001, 0.0001))


## On the optical axis of a level, unshifted perspective camera, the ray
## through screen centre runs straight down -Z; its distance to the
## upright card through an anchor 10 units ahead is exactly 10 (AC-68
## sanity check -- full AC-68 coverage is a later story).
func test_card_depth_on_axis_equals_straight_line_distance() -> void:
	var cam: SpriteProjection.CameraState = SpriteProjection.CameraState.from_perspective(
			Transform3D.IDENTITY, 60.0, 1.0, 0.1, 100.0)
	var anchor_world := Vector3(0.0, 0.0, -10.0)

	var depth: float = SpriteProjection.card_depth(Vector2.ZERO, anchor_world, cam)

	assert_float(depth).is_equal_approx(10.0, 0.001)
