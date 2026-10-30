## Story 031 (AC-27): the follow camera snaps with zero smoothing frames,
## keeps the ground hits of the view's four corner rays inside the map at
## its edges, and sits on the centre of its clamp bounds on an axis the map
## is narrower than the footprint. Story 044/054's camera-side halves (the
## `held` gate; one `dt_max`-clamped step after a freeze) are here too.
## The corner rays are built independently of `compute_footprint()`, from
## the node's own transform after `apply_transform()`.
extends GdUnitTestSuite

const _DT := 1.0 / 60.0
const _FRAMES := 300
const _TOL := 1e-3
## Fixture map: large enough for the footprint at every tested aspect.
const _MAP_MIN := Vector2(0.0, 0.0)
const _MAP_MAX := Vector2(80.0, 60.0)


func _configs() -> Array[PresentationConfig]:
	var non_default := PresentationConfig.new()
	non_default.follow_camera_pitch_degrees = 36.0
	non_default.follow_camera_fov_degrees = 16.0
	non_default.follow_camera_height = 9.0
	non_default.follow_camera_tau = 0.15
	return [PresentationConfig.new(), non_default]


func _camera(config: PresentationConfig) -> FollowCamera:
	return auto_free(FollowCamera.from_config(config)) as FollowCamera


## Ground hits (x, z) of the four corner rays of `camera` at `aspect`.
func _corner_hits(camera: FollowCamera, aspect: float) -> Array[Vector2]:
	camera.apply_transform(FollowCamera.compute_footprint(
			camera.height, camera.pitch_degrees, camera.fov_degrees, aspect))
	var t: float = tan(deg_to_rad(FollowCamera.effective_vertical_fov_degrees(
			camera.fov_degrees, aspect)) * 0.5)
	var basis: Basis = camera.transform.basis
	var out: Array[Vector2] = []
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var dir: Vector3 = basis * Vector3(sx * t * aspect, sy * t, -1.0)
			var hit: Vector3 = camera.position + dir * (-camera.position.y / dir.y)
			out.append(Vector2(hit.x, hit.z))
	return out


func test_corner_rays_stay_inside_map_at_every_edge_and_aspect() -> void:
	var targets: Array[Vector2] = [Vector2(-20, -20), Vector2(100, -20), Vector2(-20, 80),
			Vector2(100, 80), Vector2(40, -20), Vector2(40, 80), Vector2(-20, 30), Vector2(100, 30)]
	for config: PresentationConfig in _configs():
		for aspect: float in [4.0 / 3.0, 16.0 / 9.0, 21.0 / 9.0]:
			for target: Vector2 in targets:
				var camera: FollowCamera = _camera(config)
				camera.snap_to((_MAP_MIN + _MAP_MAX) * 0.5)
				for frame: int in _FRAMES:
					camera.advance(target, _DT, aspect, _MAP_MIN, _MAP_MAX)
					for hit: Vector2 in _corner_hits(camera, aspect):
						var inside: bool = hit.x >= _MAP_MIN.x - _TOL and hit.x <= _MAP_MAX.x + _TOL \
								and hit.y >= _MAP_MIN.y - _TOL and hit.y <= _MAP_MAX.y + _TOL
						if not inside:
							fail("aspect %.3f target %s frame %d hit %s" % [aspect, target, frame, hit])
							return
				# At the edge the clamp is tight: some corner touches a map edge.
				var touches: bool = false
				for hit: Vector2 in _corner_hits(camera, aspect):
					touches = touches or absf(hit.x - _MAP_MIN.x) < _TOL \
							or absf(hit.x - _MAP_MAX.x) < _TOL or absf(hit.y - _MAP_MIN.y) < _TOL \
							or absf(hit.y - _MAP_MAX.y) < _TOL
				assert_bool(touches).override_failure_message("%s" % target).is_true()


func test_narrow_map_axis_sits_on_clamp_bounds_centre_every_frame() -> void:
	for config: PresentationConfig in _configs():
		var aspect: float = 16.0 / 9.0
		var fp: FollowCamera.Footprint = FollowCamera.compute_footprint(
				config.follow_camera_height, config.follow_camera_pitch_degrees,
				config.follow_camera_fov_degrees, aspect)
		# Narrower than the footprint on both axes.
		var map_max := Vector2(fp.w_far, (fp.a_near + fp.a_far) * 0.5)
		var centre := Vector2((_MAP_MIN.x + map_max.x) * 0.5,
				(_MAP_MIN.y + map_max.y) * 0.5 + (fp.a_far - fp.a_near) * 0.5)
		var camera: FollowCamera = _camera(config)
		for frame: int in _FRAMES:
			var target := Vector2(sin(frame * 0.05) * 30.0, cos(frame * 0.07) * 30.0)
			var cam: Vector2 = camera.advance(target, _DT, aspect, _MAP_MIN, map_max)
			assert_float(cam.x).override_failure_message("x frame %d" % frame) \
					.is_equal_approx(centre.x, 1e-5)
			assert_float(cam.y).override_failure_message("y frame %d" % frame) \
					.is_equal_approx(centre.y, 1e-5)


func test_snap_has_zero_smoothing_frames() -> void:
	for config: PresentationConfig in _configs():
		var aspect: float = 16.0 / 9.0
		var camera: FollowCamera = _camera(config)
		camera.snap_to(Vector2(20.0, 20.0))
		camera.advance(Vector2(20.0, 20.0), _DT, aspect, _MAP_MIN, _MAP_MAX)
		var warp := Vector2(60.0, 40.0)

		camera.snap_to(warp)
		var cam: Vector2 = camera.advance(warp, _DT, aspect, _MAP_MIN, _MAP_MAX)

		var fp: FollowCamera.Footprint = FollowCamera.compute_footprint(
				camera.height, camera.pitch_degrees, camera.fov_degrees, aspect)
		assert_vector(cam).is_equal_approx(FollowCamera.clamp_to_map(warp, fp, _MAP_MIN, _MAP_MAX),
				Vector2(1e-5, 1e-5))


## Story 044: while `held`, the anchor moving leaves the camera byte-identical
## on every frame; on release it resumes from the held position (one formula
## step, never a snap).
func test_held_camera_is_unchanged_then_resumes_from_held_position() -> void:
	for config: PresentationConfig in _configs():
		var aspect: float = 16.0 / 9.0
		var camera: FollowCamera = _camera(config)
		camera.snap_to(Vector2(40.0, 30.0))
		camera.held = true
		var held_at: Vector2 = camera.cam_ground
		for frame: int in 60:
			camera.advance(Vector2(40.0 + frame, 30.0 - frame * 0.5), _DT, aspect, _MAP_MIN, _MAP_MAX)
			assert_bool(camera.cam_ground == held_at).override_failure_message(
					"frame %d" % frame).is_true()
		camera.held = false
		var target := Vector2(70.0, 10.0)
		var fp: FollowCamera.Footprint = FollowCamera.compute_footprint(
				camera.height, camera.pitch_degrees, camera.fov_degrees, aspect)
		var expected: Vector2 = FollowCamera.clamp_to_map(FollowCamera.ease_step(held_at, target,
				FollowCamera.dead_zone(fp, camera.dead_zone_fraction), camera.tau, _DT, camera.dt_max),
				fp, _MAP_MIN, _MAP_MAX)
		assert_vector(camera.advance(target, _DT, aspect, _MAP_MIN, _MAP_MAX)) \
				.is_equal_approx(expected, Vector2(1e-5, 1e-5))


## Story 054: the first step after a long freeze is one formula step with
## `dt` clamped to `dt_max` (from `PresentationConfig`), no catch-up.
func test_first_step_after_freeze_is_one_dt_max_step() -> void:
	for config: PresentationConfig in _configs():
		var aspect: float = 16.0 / 9.0
		var camera: FollowCamera = _camera(config)
		var start := Vector2(40.0, 30.0)
		camera.snap_to(start)
		var target := Vector2(60.0, 20.0)
		var fp: FollowCamera.Footprint = FollowCamera.compute_footprint(
				camera.height, camera.pitch_degrees, camera.fov_degrees, aspect)
		var dz: Vector2 = FollowCamera.dead_zone(fp, camera.dead_zone_fraction)
		var expected: Vector2 = FollowCamera.clamp_to_map(FollowCamera.ease_step(start, target, dz,
				config.follow_camera_tau, config.follow_camera_dt_max, config.follow_camera_dt_max),
				fp, _MAP_MIN, _MAP_MAX)

		var cam: Vector2 = camera.advance(target, 3.0, aspect, _MAP_MIN, _MAP_MAX)

		assert_vector(cam).is_equal_approx(expected, Vector2(1e-5, 1e-5))
		assert_float(camera.dt_max).is_equal(config.follow_camera_dt_max)
