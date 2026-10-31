## Sprite-camera story 039 (feet into floor): the upright card's plane
## passes through the ground point under the sprite's ROUNDED bottom edge
## (`SpriteProjection.card_plane_point()`), so no depth sample inside the
## pixel rectangle lies below the ground line. The 039 capture measured a
## 1 px cut: with the plane through the true foot anchor, an anchor that
## rounds UP by more than 1/4 px puts the lower 2x MSAA sample of the
## bottom pixel row (+0.25 px) under the foot line, where the floor is
## nearer than the card. These cases rebuild that with the shipped
## Overworld camera (h 12, pitch 30, fov 20) and the level battle camera.
extends GdUnitTestSuite

const _VIEWPORT := Vector2i(1920, 1080)
## 2x MSAA sample offsets from the pixel centre (Vulkan/D3D standard
## pattern: (0.25, 0.25) and (0.75, 0.75) inside the pixel).
const _MSAA_2X: Array[float] = [-0.25, 0.25]


func _overworld_cam() -> SpriteProjection.CameraState:
	var fp: FollowCamera.Footprint = FollowCamera.compute_footprint(12.0, 30.0, 20.0, 16.0 / 9.0)
	var xf := Transform3D(Basis.from_euler(Vector3(deg_to_rad(-30.0), 0.0, 0.0)),
			Vector3(0.0, 12.0, fp.d_focus))
	return SpriteProjection.CameraState.from_perspective(xf, 20.0, 16.0 / 9.0, 0.05, 200.0)


func _battle_cam() -> SpriteProjection.CameraState:
	var size: float = BattleFraming.h_near(0.05, 20.0, 16.0 / 9.0)
	return SpriteProjection.CameraState.from_frustum(Transform3D(Basis.IDENTITY, Vector3(0.0, 1.6, 0.0)),
			size, 16.0 / 9.0, BattleFraming.base_lens_shift(0.40, size), 0.05, 200.0)


## Window pixel (y down) -> the `card_depth` NDC convention (y up).
func _ndc(px: Vector2) -> Vector2:
	return Vector2(px.x / _VIEWPORT.x * 2.0 - 1.0, 1.0 - px.y / _VIEWPORT.y * 2.0)


## Independent: the view depth where the ray through `px` meets the ground
## plane `y = ground_y` (INF when it never does).
func _floor_depth(px: Vector2, ground_y: float, cam: SpriteProjection.CameraState) -> float:
	var ndc: Vector2 = _ndc(px)
	var v: Vector4 = cam.projection.inverse() * Vector4(ndc.x, ndc.y, 0.5, 1.0)
	var dir: Vector3 = (cam.transform.basis * (Vector3(v.x, v.y, v.z) / v.w)).normalized()
	if dir.y >= -1e-9:
		return INF
	var t: float = (ground_y - cam.transform.origin.y) / dir.y
	return (dir * t).dot(-cam.transform.basis.z.normalized())


## Foot anchors along the view whose projection rounds UP by more than 1/4
## px (the failing case), from a fixed deterministic sweep.
func _round_up_anchors(cam: SpriteProjection.CameraState, z_from: float, z_to: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var z: float = z_from
	while z > z_to and out.size() < 6:
		var a := Vector3(0.37, 0.0, z)
		var y: float = SpriteProjection.project_to_screen(a, cam, _VIEWPORT).y
		var frac: float = y - floorf(y)
		if frac >= 0.5 and frac < 0.75:
			out.append(a)
		z -= 0.0137
	return out


func _assert_bottom_row_in_front_of_floor(cam: SpriteProjection.CameraState, anchors: Array[Vector3]) -> void:
	assert_int(anchors.size()).is_greater(0)
	for a: Vector3 in anchors:
		var rect: Rect2i = SpriteProjection.screen_rect(a, cam, Vector2i(24, 32), _VIEWPORT, 360)
		var plane_point: Vector3 = SpriteProjection.card_plane_point(rect, a, cam, _VIEWPORT)
		var bottom: float = float(rect.end.y) - 0.5
		for dx: float in _MSAA_2X:
			for dy: float in _MSAA_2X:
				var px := Vector2(float(rect.get_center().x) + 0.5 + dx, bottom + dy)
				var card: float = SpriteProjection.card_depth(_ndc(px), plane_point, cam)
				var ground: float = _floor_depth(px, a.y, cam)
				assert_bool(card < ground + 1e-5).override_failure_message(
						"anchor %s rect %s sample %s: card depth %.6f is behind the floor %.6f" \
						% [a, rect, px, card, ground]).is_true()


func test_overworld_card_bottom_row_rounding_up_stays_in_front_of_floor() -> void:
	var cam := _overworld_cam()
	var focus_z: float = 0.0
	_assert_bottom_row_in_front_of_floor(cam, _round_up_anchors(cam, focus_z + 4.0, focus_z - 6.0))


func test_battle_card_bottom_row_rounding_up_stays_in_front_of_floor() -> void:
	var cam := _battle_cam()
	_assert_bottom_row_in_front_of_floor(cam, _round_up_anchors(cam, -8.0, -13.5))


## The plane meets the ground exactly at the rounded bottom edge, and moves
## the card by at most half a pixel of ground from the foot anchor.
func test_card_plane_point_meets_ground_on_rounded_bottom_edge() -> void:
	var cam := _overworld_cam()
	var a := Vector3(-1.2, 0.0, -2.31)
	var rect: Rect2i = SpriteProjection.screen_rect(a, cam, Vector2i(24, 32), _VIEWPORT, 360)
	var p: Vector3 = SpriteProjection.card_plane_point(rect, a, cam, _VIEWPORT)
	var edge := Vector2(float(rect.get_center().x), float(rect.end.y))
	assert_float(p.y).is_equal_approx(a.y, 1e-5)
	assert_float(SpriteProjection.project_to_screen(p, cam, _VIEWPORT).y).is_equal_approx(edge.y, 1e-3)
	var half_px_ground: float = absf(_floor_depth(edge + Vector2(0, 0.5), a.y, cam)
			- _floor_depth(edge - Vector2(0, 0.5), a.y, cam)) * 0.5
	var normal: Vector3 = SpriteProjection.card_normal(cam)
	assert_float(absf((p - a).dot(normal))).is_less_equal(half_px_ground + 1e-5)
