## The Overworld's perspective follow camera (ADR-0005 §6, GDD
## `follow_camera`). Moves position only, at a fixed yaw and pitch;
## `keep_aspect` is always `KEEP_HEIGHT` and `fov` widens below 16:9 by the
## same `F_v_eff` rule the battle camera will use, so both cameras share one
## aspect-widening formula (`effective_vertical_fov_degrees`, below).
##
## The dead zone, `tau`-based ease, `dt_max` clamp and the ground-footprint
## clamp are pure static functions of a ground-plane `Vector2` target and
## `dt` -- no scene-tree dependency, fully headless-testable (Implementation
## Notes). The Overworld ADR (ADR-0012, no epic yet) decides what this
## follows; this story takes the target as an injected `Vector2`, never a
## direct reference to party or map state (Out of Scope).
class_name FollowCamera
extends Camera3D

## One footprint computation's result (GDD `follow_camera`): the ground
## trapezoid's near/far depths and the far edge's half-width, plus the
## effective fields of view used to compute them. A pure value object
## returned by `compute_footprint()`; holds no state of its own.
class Footprint:
	extends RefCounted

	## Effective vertical field of view at the queried aspect, in degrees.
	var f_v_eff_degrees: float
	## Effective horizontal field of view at the queried aspect, in degrees.
	var f_h_degrees: float
	## Ground distance from directly below the camera to the view's near edge.
	var d_near: float
	## Ground distance from directly below the camera to the focus point.
	var d_focus: float
	## Ground distance from directly below the camera to the view's far edge.
	var d_far: float
	## Distance from the focus point to the footprint's near edge, in meters.
	var a_near: float
	## Distance from the focus point to the footprint's far edge, in meters.
	var a_far: float
	## Half-width of the footprint's far edge (its widest part), in meters.
	var w_far: float

	func _init(p_f_v_eff_degrees: float, p_f_h_degrees: float, p_d_near: float,
			p_d_focus: float, p_d_far: float, p_a_near: float, p_a_far: float,
			p_w_far: float) -> void:
		f_v_eff_degrees = p_f_v_eff_degrees
		f_h_degrees = p_f_h_degrees
		d_near = p_d_near
		d_focus = p_d_focus
		d_far = p_d_far
		a_near = p_a_near
		a_far = p_a_far
		w_far = p_w_far


## Camera height above the ground plane, in meters (GDD `follow_camera` `h`).
@export var height: float = 10.0
## Fixed pitch below the horizon, in degrees (`pitch`).
@export var pitch_degrees: float = 30.0
## Fixed yaw, in degrees; `cam_ground`'s `y` axis points along this facing
## at `apply_transform()` time (0 = world -Z).
@export var yaw_degrees: float = 0.0
## Vertical field of view at 16:9, in degrees, before `F_v_eff` widening (`F_v`).
@export var fov_degrees: float = 20.0
## Dead-zone half-size as a fraction of the footprint's half-extent per axis
## (`dz`; Tuning Knobs: 8-12%, default 10%).
@export_range(0.08, 0.12, 0.01) var dead_zone_fraction: float = 0.10
## Time to cover 63% of the remaining excess, in seconds (`tau`).
@export_range(0.15, 0.18, 0.01) var tau: float = 0.17
## Largest frame step used by the ease, in seconds (`dt_max`).
@export_range(0.05, 0.10, 0.01) var dt_max: float = 0.10
## How far below the horizon the footprint's far edge must stay at 4:3, in
## degrees (`horizon_margin`).
@export_range(3.0, 10.0, 0.5) var horizon_margin_degrees: float = 5.0

## The camera's current ground-plane focus point (GDD `follow_camera`
## `cam`). Set via `snap_to()` to teleport with no smoothing (Edge Cases:
## map change, warp, retreat to camp).
var cam_ground: Vector2 = Vector2.ZERO


func _ready() -> void:
	keep_aspect = Camera3D.KEEP_HEIGHT
	projection = Camera3D.PROJECTION_PERSPECTIVE
	var viewport: Viewport = get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_resized):
		viewport.size_changed.connect(_on_viewport_resized)


## The narrowest supported aspect (GDD Edge Cases: `chase_visibility` is
## checked at 4:3, 16:9 and 21:9; narrower is unsupported).
const MIN_SUPPORTED_ASPECT: float = 4.0 / 3.0
## Narrow-aspect warnings logged (story 132: one per resize event into an
## unsupported aspect, never one per frame).
var narrow_aspect_warnings: int = 0


func _on_viewport_resized() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	if size.y > 0.0:
		note_resize(size.x / size.y)


## Story 132 (GDD Edge Cases "window resized"): a resize to an aspect
## narrower than 4:3 logs exactly one warning; the game keeps running (the
## footprint is recomputed every frame from the current aspect anyway).
## Returns whether a warning was logged.
func note_resize(aspect: float) -> bool:
	if aspect >= MIN_SUPPORTED_ASPECT - 1e-4:
		return false
	narrow_aspect_warnings += 1
	push_warning("FollowCamera: aspect %.3f is narrower than 4:3 and unsupported; chase_visibility is not guaranteed" % aspect)
	return true


## Builds a camera from `PresentationConfig`'s `follow_camera_*` fields and
## validates the horizon guard immediately (GDD Edge Cases: a camera config
## that fails this is "a content bug, not a play case").
static func from_config(config: PresentationConfig) -> FollowCamera:
	var camera := FollowCamera.new()
	camera.height = config.follow_camera_height
	camera.pitch_degrees = config.follow_camera_pitch_degrees
	camera.fov_degrees = config.follow_camera_fov_degrees
	camera.dead_zone_fraction = config.follow_camera_dead_zone_fraction
	camera.tau = config.follow_camera_tau
	camera.dt_max = config.follow_camera_dt_max
	camera.horizon_margin_degrees = config.follow_camera_horizon_margin_degrees
	if not validate_horizon(camera.height, camera.pitch_degrees, camera.fov_degrees,
			camera.horizon_margin_degrees):
		push_error("FollowCamera: pitch - F_v_eff(4:3)/2 < horizon_margin -- " +
				"content bug (GDD follow_camera Edge Cases).")
	return camera


## `F_v_eff` (GDD `follow_camera`): the vertical field of view actually
## shown. Fixed at `fov_degrees` at 16:9 and wider; below 16:9 the camera
## keeps the 16:9 horizontal view, so the vertical view grows. Shared by the
## battle camera's framing formula (ADR-0005 §6) -- both read this function.
static func effective_vertical_fov_degrees(p_fov_degrees: float, aspect: float) -> float:
	var widen: float = maxf(1.0, (16.0 / 9.0) / aspect)
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(p_fov_degrees) * 0.5) * widen))


## `F_h` (GDD `follow_camera`): the horizontal field of view at `aspect`,
## derived from the already-widened `f_v_eff_degrees`.
static func horizontal_fov_degrees(f_v_eff_degrees: float, aspect: float) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(f_v_eff_degrees) * 0.5) * aspect))


## The ground footprint's near/far depths and far-edge half-width at
## `aspect` (GDD `follow_camera`). A pure function of the camera's own fixed
## fields -- recomputed at load and on every window resize; never cached
## across frames by the caller.
static func compute_footprint(p_height: float, p_pitch_degrees: float, p_fov_degrees: float,
		aspect: float) -> Footprint:
	var f_v_eff: float = effective_vertical_fov_degrees(p_fov_degrees, aspect)
	var f_h: float = horizontal_fov_degrees(f_v_eff, aspect)
	var pitch_rad: float = deg_to_rad(p_pitch_degrees)
	var half_v_rad: float = deg_to_rad(f_v_eff) * 0.5
	var half_h_rad: float = deg_to_rad(f_h) * 0.5
	var d_near: float = p_height / tan(pitch_rad + half_v_rad)
	var d_focus: float = p_height / tan(pitch_rad)
	var d_far: float = p_height / tan(pitch_rad - half_v_rad)
	var a_near: float = d_focus - d_near
	var a_far: float = d_far - d_focus
	var w_far: float = p_height * cos(half_v_rad) * tan(half_h_rad) / sin(pitch_rad - half_v_rad)
	return Footprint.new(f_v_eff, f_h, d_near, d_focus, d_far, a_near, a_far, w_far)


## The horizon load-time guard (GDD `follow_camera` Edge Cases): the
## overworld camera must keep `pitch - F_v_eff(4:3)/2 >= horizon_margin` at
## the narrowest supported aspect, 4:3, where `F_v_eff` is largest.
static func validate_horizon(p_height: float, p_pitch_degrees: float, p_fov_degrees: float,
		p_horizon_margin_degrees: float) -> bool:
	var footprint: Footprint = compute_footprint(p_height, p_pitch_degrees, p_fov_degrees, 4.0 / 3.0)
	return p_pitch_degrees - footprint.f_v_eff_degrees * 0.5 >= p_horizon_margin_degrees


## `clamp_or_centre` (GDD `follow_camera`): clamps `value` into `[lo, hi]`,
## or centres on the inverted range when the map is smaller than the
## footprint on this axis (Edge Cases: "the camera is centred on the map on
## that axis and doesn't follow along it").
static func clamp_or_centre(value: float, lo: float, hi: float) -> float:
	if lo <= hi:
		return clampf(value, lo, hi)
	return (lo + hi) * 0.5


## The dead zone's half-size per axis (GDD `follow_camera` `dz`; Tuning
## Knobs: 8-12% of the footprint's half-extent per axis, default 10%). `x`'s
## half-extent is the far edge's half-width (`w_far`, the footprint's
## widest point); `y`'s is half the footprint's total depth span (`a_near +
## a_far`), since the depth footprint isn't centred on the focus point the
## way the width is.
static func dead_zone(footprint: Footprint, p_dead_zone_fraction: float) -> Vector2:
	return Vector2(
			footprint.w_far * p_dead_zone_fraction,
			(footprint.a_near + footprint.a_far) * 0.5 * p_dead_zone_fraction)


## One frame of the dead-zone/tau ease (GDD `follow_camera`), per axis:
## `offset = target - cam; excess = offset - clamp(offset, -dz, dz); cam +=
## excess * (1 - exp(-min(dt, dt_max) / tau))`. A pure function of its
## arguments -- no footprint clamp here (see `clamp_to_footprint`).
static func ease_step(cam: Vector2, target: Vector2, dz: Vector2, p_tau: float, dt: float,
		p_dt_max: float) -> Vector2:
	var offset: Vector2 = target - cam
	var clamped: Vector2 = Vector2(
			clampf(offset.x, -dz.x, dz.x),
			clampf(offset.y, -dz.y, dz.y))
	var excess: Vector2 = offset - clamped
	var factor: float = 1.0 - exp(-minf(dt, p_dt_max) / p_tau)
	return cam + excess * factor


## The ground-footprint clamp (GDD `follow_camera`): keeps the view's ground
## footprint inside `[map_min, map_max]`, centring on an axis the footprint
## doesn't fit (`clamp_or_centre`).
static func clamp_to_footprint(cam: Vector2, footprint: Footprint, map_min: Vector2,
		map_max: Vector2) -> Vector2:
	return Vector2(
			clamp_or_centre(cam.x, map_min.x + footprint.w_far, map_max.x - footprint.w_far),
			clamp_or_centre(cam.y, map_min.y + footprint.a_near, map_max.y - footprint.a_far))


## `clamp_to_footprint()` for a focus and bounds in map ground coordinates
## (`x`, world `z`). The GDD's ground `y` points away from the camera, but
## map `y` is world `z`, which at yaw 0 (the camera looks along -Z, sitting
## on the +Z side of its focus, `apply_transform()`) points toward it. So the
## clamp runs in the camera's frame: flip `y`, clamp, flip back. The near
## edge then bounds the map's +y (south) side and the far edge its -y side,
## and the bottom rows of a map stay reachable on screen. Only yaw 0 ships
## (TODO(presentation): rotate the bounds for another yaw).
static func clamp_to_map(cam: Vector2, footprint: Footprint, map_min: Vector2,
		map_max: Vector2) -> Vector2:
	var flip := Vector2(1.0, -1.0)
	return clamp_to_footprint(cam * flip, footprint, Vector2(map_min.x, -map_max.y),
			Vector2(map_max.x, -map_min.y)) * flip


## One full frame: eases `cam_ground` toward `target`, then clamps the
## result to the ground footprint at `aspect` (GDD `follow_camera`). The
## caller passes a stable `aspect` across a run of frames and a changed one
## only on resize (Edge Cases: "the follow camera's footprint and dead zone
## are recalculated from the new size").
func advance(target: Vector2, dt: float, aspect: float, map_min: Vector2, map_max: Vector2) -> Vector2:
	var footprint: Footprint = compute_footprint(height, pitch_degrees, fov_degrees, aspect)
	var dz: Vector2 = dead_zone(footprint, dead_zone_fraction)
	var eased: Vector2 = ease_step(cam_ground, target, dz, tau, dt, dt_max)
	cam_ground = clamp_to_map(eased, footprint, map_min, map_max)
	return cam_ground


## Snaps `cam_ground` directly to `ground_position`, with no smoothing (GDD
## Edge Cases: "If the overworld party teleports (map change, warp, retreat
## to camp): the camera snaps to the new position... with no smoothing").
func snap_to(ground_position: Vector2) -> void:
	cam_ground = ground_position


## Sets the live `Camera3D.fov` to `F_v_eff` at `aspect` (ADR-0005 §6): with
## `keep_aspect = KEEP_HEIGHT`, the engine then derives the horizontal field
## of view from `fov` and `aspect`, which is exactly the GDD's `F_h`
## formula. Call on load and on every window resize (Edge Cases).
func apply_fov(aspect: float) -> void:
	fov = effective_vertical_fov_degrees(fov_degrees, aspect)


## Applies `cam_ground` to the node's actual `position` and fixed
## `rotation_degrees` (GDD `follow_camera`: "moves position only"). `x` is
## sideways on screen; `y` points away from the camera along the ground,
## which at `yaw_degrees = 0` is world -Z. The camera sits `height` above
## the ground, set back from the focus point by `footprint.d_focus` along
## its own forward ground direction, so the view ray at `pitch_degrees`
## below the horizon lands exactly on `cam_ground`.
func apply_transform(footprint: Footprint) -> void:
	var yaw_rad: float = deg_to_rad(yaw_degrees)
	var forward_ground: Vector2 = Vector2(sin(yaw_rad), -cos(yaw_rad))
	var below_camera: Vector2 = cam_ground - forward_ground * footprint.d_focus
	position = Vector3(below_camera.x, height, below_camera.y)
	rotation_degrees = Vector3(-pitch_degrees, yaw_degrees, 0.0)
