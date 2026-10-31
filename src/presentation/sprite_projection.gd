## Pure, static, headless-testable projection math for every sprite's
## on-screen quad (ADR-0005 Decision §2, GDD `texel_scale`). Computes the
## whole-pixel texel scale `T`, the bottom-centre-anchored pixel rectangle,
## and the upright card's world-space normal for any camera and frame size.
## Holds no state and touches no node -- every call is a pure function of
## its arguments. `CharacterSprite` (`character_sprite.gd`) is the only
## caller that touches a live `Camera3D`/`Viewport`; this file never does.
class_name SpriteProjection
extends RefCounted


## A value copy of a camera's transform, projection matrix and raw frustum
## parameters (ADR-0005 §6), decoupled from any live `Camera3D` so
## `SpriteProjection` stays pure and headless-testable. Built once per frame
## by the caller (never cached across frames: `frustum_offset` and
## `transform` change every frame under a hit-punch or camera move).
class CameraState:
	extends RefCounted

	## The camera's global transform (world <- view).
	var transform: Transform3D
	## The camera's projection matrix, built with `Projection.create_frustum_aspect`
	## or `Projection.create_perspective` -- never `Camera3D.get_camera_projection()`
	## (ADR-0005 §6: the two disagree under `PROJECTION_FRUSTUM` on 4.7.2).
	var projection: Projection
	## `Camera3D.size` (`PROJECTION_FRUSTUM`) or 0.0 for a perspective camera.
	var size: float
	## `Camera3D.near`.
	var near: float
	## Always `Camera3D.KEEP_HEIGHT` in this project (ADR-0005 §6).
	var keep_aspect: int
	## `Camera3D.frustum_offset` (lens shift + hit-punch; zero for a perspective camera).
	var frustum_offset: Vector2

	func _init(p_transform: Transform3D, p_projection: Projection, p_size: float,
			p_near: float, p_keep_aspect: int, p_frustum_offset: Vector2) -> void:
		transform = p_transform
		projection = p_projection
		size = p_size
		near = p_near
		keep_aspect = p_keep_aspect
		frustum_offset = p_frustum_offset


	## Builds a CameraState for a level, shift-lens `PROJECTION_FRUSTUM`
	## battle camera (ADR-0005 §6): `keep_aspect` is always `KEEP_HEIGHT`,
	## and the matrix is built with `Projection.create_frustum_aspect`.
	static func from_frustum(transform: Transform3D, size: float, aspect: float,
			frustum_offset: Vector2, near: float, far: float) -> CameraState:
		var proj: Projection = Projection.create_frustum_aspect(
				size, aspect, frustum_offset, near, far, false)
		return CameraState.new(transform, proj, size, near, Camera3D.KEEP_HEIGHT, frustum_offset)


	## Builds a CameraState for a perspective follow camera (the Overworld,
	## ADR-0005 §6): `keep_aspect` is always `KEEP_HEIGHT`.
	static func from_perspective(transform: Transform3D, fov: float, aspect: float,
			near: float, far: float) -> CameraState:
		var proj: Projection = Projection.create_perspective(fov, aspect, near, far, false)
		return CameraState.new(transform, proj, 0.0, near, Camera3D.KEEP_HEIGHT, Vector2.ZERO)


	## Builds a CameraState from a live `Camera3D` and the current viewport
	## size (ADR-0005 §6). Branches only on `camera.projection`; `keep_aspect`
	## is always treated as `KEEP_HEIGHT` per the project rule.
	static func from_camera3d(camera: Camera3D, viewport_size: Vector2i) -> CameraState:
		var aspect: float = float(viewport_size.x) / float(viewport_size.y)
		if camera.projection == Camera3D.PROJECTION_FRUSTUM:
			return from_frustum(camera.global_transform, camera.size, aspect,
					camera.frustum_offset, camera.near, camera.far)
		return from_perspective(camera.global_transform, camera.fov, aspect, camera.near, camera.far)


## T = max(1, floor(viewport_height / base_lines)) (GDD `texel_scale`).
static func texel_scale(viewport_height: int, base_lines: int) -> int:
	return maxi(1, floori(float(viewport_height) / float(base_lines)))


## The whole-pixel rectangle for a `frame_size.x` x `frame_size.y` texel
## frame at `T` screen pixels per texel, bottom-centred on `anchor_world`'s
## screen projection rounded half away from zero (GDD `texel_scale`):
## `x_left = x_a - floor(frame_w*T / 2)`, `y_bottom = y_a`, so an odd pixel
## width never starts on a half pixel.
static func screen_rect(anchor_world: Vector3, cam: CameraState, frame_size: Vector2i,
		viewport_size: Vector2i, base_lines: int) -> Rect2i:
	var t: int = texel_scale(viewport_size.y, base_lines)
	var anchor_px: Vector2i = _project_to_pixel(anchor_world, cam, viewport_size)
	var width_px: int = frame_size.x * t
	var height_px: int = frame_size.y * t
	var x_left: int = anchor_px.x - (width_px / 2)
	var y_top: int = anchor_px.y - height_px
	return Rect2i(x_left, y_top, width_px, height_px)


## The upright card's normal: the camera's forward direction, projected
## onto the ground plane (y = 0) and normalized (ADR-0005 §2). Falls back
## to -Z only when the camera looks straight up or down, which no shipped
## camera does -- a shipped camera never hits this branch.
static func card_normal(cam: CameraState) -> Vector3:
	var forward: Vector3 = -cam.transform.basis.z.normalized()
	var flat: Vector3 = Vector3(forward.x, 0.0, forward.z)
	if flat.length_squared() < 0.0000001:
		return Vector3(0.0, 0.0, -1.0)
	return flat.normalized()


## The view depth (positive distance along the camera's forward axis) at
## which the camera ray through `ndc` meets the upright card through
## `anchor_world` -- mirrors the shader's `vertex()` ray/plane intersection
## (for tests, AC-68). For a sprite, `anchor_world` is its
## `card_plane_point()` (story 039), the point the shader's card passes
## through; any point on the plane gives the same depth.
## `ndc.x`/`ndc.y` use the same [-1, 1] convention as
## `cam.projection`'s own output. Valid only for a true pinhole projection
## (`PROJECTION_PERSPECTIVE` or `PROJECTION_FRUSTUM`): every camera ray
## passes through the view-space origin, which is what this relies on.
static func card_depth(ndc: Vector2, anchor_world: Vector3, cam: CameraState) -> float:
	var inv_proj: Projection = cam.projection.inverse()
	var clip: Vector4 = inv_proj * Vector4(ndc.x, ndc.y, 0.5, 1.0)
	var view_point: Vector3 = Vector3(clip.x, clip.y, clip.z) / clip.w
	var ray_origin: Vector3 = cam.transform.origin
	var ray_dir: Vector3 = (cam.transform.basis * view_point).normalized()
	var normal: Vector3 = card_normal(cam)
	var denom: float = ray_dir.dot(normal)
	if is_zero_approx(denom):
		return 0.0
	var hit_t: float = (anchor_world - ray_origin).dot(normal) / denom
	var hit_world: Vector3 = ray_origin + ray_dir * hit_t
	var forward: Vector3 = -cam.transform.basis.z.normalized()
	return (hit_world - ray_origin).dot(forward)


## The point the sprite's upright card plane passes through (ADR-0005 §2;
## sprite-camera story 039): where the camera ray through the middle of
## `rect`'s ROUNDED bottom edge meets the ground plane at the foot anchor's
## height (`y = anchor_world.y`), not the foot anchor itself. The card then
## meets the ground exactly on the bottom pixel edge, so no depth sample
## inside the rectangle (MSAA's included) lies below the foot line, where
## the floor would be nearer than the card. Moves the card by at most half
## a pixel of ground from the anchor. Falls back to `anchor_world` when that
## ray never reaches the ground (at or above the horizon). The shader's
## `vertex()` makes the same construction; pass this to `card_depth()`.
static func card_plane_point(rect: Rect2i, anchor_world: Vector3, cam: CameraState,
		viewport_size: Vector2i) -> Vector3:
	var px := Vector2(float(rect.position.x) + float(rect.size.x) * 0.5, float(rect.end.y))
	var ndc := Vector2(px.x / float(viewport_size.x) * 2.0 - 1.0,
			1.0 - px.y / float(viewport_size.y) * 2.0)
	var clip: Vector4 = cam.projection.inverse() * Vector4(ndc.x, ndc.y, 0.5, 1.0)
	var dir: Vector3 = cam.transform.basis * (Vector3(clip.x, clip.y, clip.z) / clip.w)
	var origin: Vector3 = cam.transform.origin
	if dir.y > -1e-7:
		return anchor_world
	var t: float = (anchor_world.y - origin.y) / dir.y
	if t <= 0.0:
		return anchor_world
	return origin + dir * t


## Projects `world_point` through `cam` to an unrounded screen position in
## pixels (NDC y is up, screen y is down). `screen_rect` rounds this; tests
## use it to check the rounding (story 063).
static func project_to_screen(world_point: Vector3, cam: CameraState,
		viewport_size: Vector2i) -> Vector2:
	var view_point: Vector3 = cam.transform.affine_inverse() * world_point
	var clip: Vector4 = cam.projection * Vector4(view_point.x, view_point.y, view_point.z, 1.0)
	var ndc: Vector3 = Vector3(clip.x, clip.y, clip.z) / clip.w
	return Vector2((ndc.x * 0.5 + 0.5) * float(viewport_size.x),
			(1.0 - (ndc.y * 0.5 + 0.5)) * float(viewport_size.y))


## The whole-pixel screen rectangle enclosing `box`'s projection through
## `cam` (GDD `battle_framing`, "the projected bounds of set geometry tagged
## as an occluder"; story 047): the 8 corners' bounds, floored at the
## top-left and ceiled at the bottom-right, so it never under-covers. A box
## reaching the near plane or behind the camera returns the whole frame
## (conservative: it may hide anything).
static func screen_bounds(box: AABB, cam: CameraState, viewport_size: Vector2i) -> Rect2i:
	var view_from_world: Transform3D = cam.transform.affine_inverse()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c: int in 8:
		var corner: Vector3 = box.get_endpoint(c)
		if -(view_from_world * corner).z <= cam.near:
			return Rect2i(Vector2i.ZERO, viewport_size)
		var p: Vector2 = project_to_screen(corner, cam, viewport_size)
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var top_left := Vector2i(floori(lo.x), floori(lo.y))
	return Rect2i(top_left, Vector2i(ceili(hi.x), ceili(hi.y)) - top_left)


## Whether `box` lies wholly inside `cam`'s view at `viewport_size`: every
## corner in front of the near plane and `screen_bounds()` enclosed by the
## frame (story 041, AC-37: the faction shape's bounds in the battle
## camera's view). The same projection every sprite quad uses.
static func box_in_view(box: AABB, cam: CameraState, viewport_size: Vector2i) -> bool:
	var view_from_world: Transform3D = cam.transform.affine_inverse()
	for c: int in 8:
		if -(view_from_world * box.get_endpoint(c)).z <= cam.near:
			return false
	return Rect2i(Vector2i.ZERO, viewport_size).encloses(screen_bounds(box, cam, viewport_size))


## Round half away from zero on both axes (GDD `texel_scale`), public so the
## pixel-snap tests share the exact rule.
static func round_pixel(screen: Vector2) -> Vector2i:
	return Vector2i(_round_half_away_from_zero(screen.x), _round_half_away_from_zero(screen.y))


## Projects `world_point` through `cam` to a rounded screen pixel
## (round half away from zero on both axes; NDC y is up, screen y is down).
static func _project_to_pixel(world_point: Vector3, cam: CameraState, viewport_size: Vector2i) -> Vector2i:
	return round_pixel(project_to_screen(world_point, cam, viewport_size))


## Round-half-away-from-zero to the nearest int (GDD `texel_scale`'s
## rounding rule for the foot anchor's projection): written out explicitly
## rather than relying on the engine's `round()` so the rule stays exact
## and self-documenting under test.
static func _round_half_away_from_zero(value: float) -> int:
	if value >= 0.0:
		return int(floor(value + 0.5))
	return -int(floor(-value + 0.5))
