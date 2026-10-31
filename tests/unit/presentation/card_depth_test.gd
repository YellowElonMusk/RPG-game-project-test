## Sprite-camera story 073, GDD AC-68 [L] (P-03; ADR-0005 §2 as amended by
## story 039): under a pitched camera, the pure card-depth function
## `SpriteProjection.sprite_card_depth()` returns, for every view ray through
## the sprite's pixel rectangle, the view depth (metres) where that ray meets
## the upright card through `card_plane_point()` (the ground point under the
## rounded bottom edge), within 1e-4 of the analytic value.
##
## The analytic value is computed here independently of `SpriteProjection`:
## the ray comes from the pinhole model (`tan(fov/2)`, aspect, KEEP_HEIGHT),
## not from the projection matrix; the plane point and the ground-projected
## normal are rebuilt from the camera transform. The plane is then
## `(X - P) . n = 0`, and with an unnormalised view ray whose forward
## component is 1, the hit parameter IS the view depth.
##
## Cameras: the shipped Overworld follow camera (h 12 m, pitch 30 deg, fov
## 20 deg) at 16:9 and 4:3, and a yawed, steeper fixed camera standing in for
## Camp's "fixed angle looking down" (GDD rule 4). Camp has no camera
## content yet (no 3D Camp scene), so no shipped Camp number exists to use.
extends GdUnitTestSuite

const _TOLERANCE_M: float = 1e-4
const _FRAME := Vector2i(24, 32)
const _BASE_LINES: int = 360
## The fixture wall stands this far behind the card (AC-68).
const _WALL_BEHIND_M: float = 0.5


class _Cam:
	extends RefCounted
	var name: String
	var state: SpriteProjection.CameraState
	var fov_deg: float
	var aspect: float
	var viewport: Vector2i


func _pitched_cam(label: String, height: float, pitch_deg: float, yaw_deg: float, fov_deg: float,
		viewport: Vector2i, focus: Vector3) -> _Cam:
	var aspect: float = float(viewport.x) / float(viewport.y)
	var basis := Basis.from_euler(Vector3(deg_to_rad(-pitch_deg), deg_to_rad(yaw_deg), 0.0))
	var back: Vector3 = basis.z * (height / sin(deg_to_rad(pitch_deg)))
	var c := _Cam.new()
	c.name = label
	c.fov_deg = fov_deg
	c.aspect = aspect
	c.viewport = viewport
	c.state = SpriteProjection.CameraState.from_perspective(Transform3D(basis, focus + back),
			fov_deg, aspect, 0.05, 200.0)
	return c


func _cams() -> Array[_Cam]:
	return [
		_pitched_cam("overworld 16:9", 12.0, 30.0, 0.0, 20.0, Vector2i(1920, 1080), Vector3(3.0, 0.0, -4.0)),
		_pitched_cam("overworld 4:3", 12.0, 30.0, 0.0, 20.0, Vector2i(1440, 1080), Vector3(-2.0, 0.0, 1.5)),
		_pitched_cam("fixed camp-like, yawed", 6.0, 45.0, 35.0, 30.0, Vector2i(1280, 800), Vector3(0.5, 0.0, 0.25)),
	]


## Anchors around the focus, off-axis, at different depths in the frame.
func _anchors(c: _Cam) -> Array[Vector3]:
	var fwd: Vector3 = _flat_forward(c.state.transform)
	var side: Vector3 = fwd.cross(Vector3.UP).normalized()
	var origin: Vector3 = c.state.transform.origin
	var focus: Vector3 = origin + (-c.state.transform.basis.z) * (origin.y / -(-c.state.transform.basis.z).y)
	return [focus + side * 1.37 + fwd * 0.21, focus - side * 2.9 - fwd * 1.13, focus + side * 0.04 + fwd * 3.3]


func _flat_forward(xf: Transform3D) -> Vector3:
	var f: Vector3 = -xf.basis.z
	return Vector3(f.x, 0.0, f.z).normalized()


## Independent pinhole ray through window pixel `px` (y down), in world
## space, scaled so its component along the camera's forward axis is 1.
func _ray(c: _Cam, px: Vector2) -> Vector3:
	var half_v: float = tan(deg_to_rad(c.fov_deg) * 0.5)
	var nx: float = px.x / float(c.viewport.x) * 2.0 - 1.0
	var ny: float = 1.0 - px.y / float(c.viewport.y) * 2.0
	return c.state.transform.basis * Vector3(nx * half_v * c.aspect, ny * half_v, -1.0)


## Independent: the ground point (y = anchor.y) under the middle of the
## rect's rounded bottom edge.
func _plane_point(c: _Cam, rect: Rect2i, anchor: Vector3) -> Vector3:
	var d: Vector3 = _ray(c, Vector2(rect.position.x + rect.size.x * 0.5, rect.end.y))
	var o: Vector3 = c.state.transform.origin
	return o + d * ((anchor.y - o.y) / d.y)


## Analytic view depth of the ray through `px` against the vertical plane
## through `p` with normal `n`.
func _analytic_depth(c: _Cam, px: Vector2, p: Vector3, n: Vector3) -> float:
	var d: Vector3 = _ray(c, px)
	return (p - c.state.transform.origin).dot(n) / d.dot(n)


## Every pixel centre of the rect, plus its four exact corners.
func _pixels(rect: Rect2i) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			out.append(Vector2(x + 0.5, y + 0.5))
	out.append_array([Vector2(rect.position), Vector2(rect.end.x, rect.position.y),
			Vector2(rect.position.x, rect.end.y), Vector2(rect.end)])
	return out


func test_card_depth_every_ray_in_rect_pitched_cameras_matches_analytic_within_1e4() -> void:
	var checked: int = 0
	var worst: float = 0.0
	for c: _Cam in _cams():
		var n: Vector3 = _flat_forward(c.state.transform)
		for a: Vector3 in _anchors(c):
			var rect: Rect2i = SpriteProjection.screen_rect(a, c.state, _FRAME, c.viewport, _BASE_LINES)
			var p: Vector3 = _plane_point(c, rect, a)
			for px: Vector2 in _pixels(rect):
				var got: float = SpriteProjection.sprite_card_depth(px, rect, a, c.state, c.viewport)
				var want: float = _analytic_depth(c, px, p, n)
				worst = maxf(worst, absf(got - want))
				checked += 1
				if absf(got - want) > _TOLERANCE_M:
					var msg: String = "%s anchor %s rect %s px %s: card depth %.6f, analytic %.6f" % [c.name, a, rect, px, got, want]
					assert_float(got).override_failure_message(msg).is_equal_approx(want, _TOLERANCE_M)
					return
	assert_int(checked).is_greater(10000)
	assert_float(worst).is_less_equal(_TOLERANCE_M)


## The card goes through the rounded bottom edge's ground point, not the foot
## anchor: for an anchor whose projection rounds by a large fraction of a
## pixel, the two planes' depths differ by far more than the tolerance, so the
## test above tells them apart.
func test_card_depth_anchor_rounding_by_0_4_px_differs_from_foot_anchor_plane() -> void:
	var c: _Cam = _cams()[0]
	var n: Vector3 = _flat_forward(c.state.transform)
	var a: Vector3 = _anchors(c)[0]
	# Walk the anchor along the view until its projection's fraction is ~0.4 px off.
	var step: Vector3 = n * 0.0011
	for i: int in 200:
		var y: float = SpriteProjection.project_to_screen(a, c.state, c.viewport).y
		var off: float = absf(y - roundf(y))
		if off > 0.35:
			break
		a += step
	var rect: Rect2i = SpriteProjection.screen_rect(a, c.state, _FRAME, c.viewport, _BASE_LINES)
	var px := Vector2(rect.get_center()) + Vector2(0.5, 0.5)
	var through_anchor: float = _analytic_depth(c, px, a, n)
	var got: float = SpriteProjection.sprite_card_depth(px, rect, a, c.state, c.viewport)
	assert_float(absf(got - through_anchor)).is_greater(10.0 * _TOLERANCE_M)


## The AC-68 fixture: a wall 0.5 m behind the card. Every ray through the
## rect meets the card well before the wall, so the wall never cuts into
## the sprite (the [C] half measures the same on screen).
func test_card_depth_wall_half_metre_behind_every_ray_in_rect_is_nearer() -> void:
	for c: _Cam in _cams():
		var n: Vector3 = _flat_forward(c.state.transform)
		for a: Vector3 in _anchors(c):
			var rect: Rect2i = SpriteProjection.screen_rect(a, c.state, _FRAME, c.viewport, _BASE_LINES)
			var wall_point: Vector3 = _plane_point(c, rect, a) + n * _WALL_BEHIND_M
			for px: Vector2 in _pixels(rect):
				var card: float = SpriteProjection.sprite_card_depth(px, rect, a, c.state, c.viewport)
				var wall: float = _analytic_depth(c, px, wall_point, n)
				if not (card < wall - 0.25):
					var msg: String = "%s px %s: card %.4f, wall %.4f" % [c.name, px, card, wall]
					assert_float(card).override_failure_message(msg).is_less(wall - 0.25)
					return
