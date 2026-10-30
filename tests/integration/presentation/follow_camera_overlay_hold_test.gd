## Stories 031, 044 and 054 on the assembled `overworld_mode.tscn`: a
## `party_placed` (warp, map change, retreat) snaps the camera with zero
## smoothing frames; with Dialogue open the camera is unchanged on every
## frame while the anchor moves, then resumes from where it was held; under
## the Menu the camera has no clock of its own (it only moves when the view,
## a descendant of the frozen mode, is processed), and the first frame after
## the Menu closes is one formula step with `dt <= dt_max`. Frames are
## stepped by calling `_process()` directly (no `await`).
extends GdUnitTestSuite

const GameStateFixtures := preload("res://tests/unit/game_state/doubles/game_state_fixtures.gd")
const _SCENE: String = "res://src/overworld/overworld_mode.tscn"
const _DT: float = 1.0 / 60.0


func _make() -> Dictionary:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var mode: OverworldMode = (load(_SCENE) as PackedScene).instantiate() as OverworldMode
	mode.config = OverworldConfig.new()
	mode.setup(machine, null)
	loader.current_mode_node_value = mode
	machine.bind_action_source(SyntheticActionSource.new())
	add_child(mode)
	auto_free(mode)
	var view: OverworldView = mode.get_node(^"OverworldView") as OverworldView
	return {"machine": machine, "mode": mode, "view": view}


func _bounds(mode: OverworldMode) -> Rect2:
	return OverworldMap.ground_bounds(mode.get_walk_grid())


## The default test map is smaller than the shipped camera footprint, so the
## clamp centres the camera on both axes and it can never move. Lower the
## camera (footprint scales with height) until the footprint covers at most
## half the map on each axis, then re-centre it so tracking is observable.
func _fit_camera(view: OverworldView, camera: FollowCamera, bounds: Rect2) -> void:
	var aspect: float = camera.get_viewport().get_visible_rect().size.aspect()
	var fp: FollowCamera.Footprint = FollowCamera.compute_footprint(
			camera.height, camera.pitch_degrees, camera.fov_degrees, aspect)
	while 2.0 * fp.w_far > bounds.size.x * 0.5 or fp.a_near + fp.a_far > bounds.size.y * 0.5:
		camera.height *= 0.5
		fp = FollowCamera.compute_footprint(
				camera.height, camera.pitch_degrees, camera.fov_degrees, aspect)
	camera.snap_to(bounds.get_center())
	view._process(0.0)


func _expected_step(camera: FollowCamera, from: Vector2, target: Vector2, dt: float,
		bounds: Rect2) -> Vector2:
	var aspect: float = camera.get_viewport().get_visible_rect().size.aspect()
	var fp: FollowCamera.Footprint = FollowCamera.compute_footprint(
			camera.height, camera.pitch_degrees, camera.fov_degrees, aspect)
	var eased: Vector2 = FollowCamera.ease_step(from, target,
			FollowCamera.dead_zone(fp, camera.dead_zone_fraction), camera.tau, dt, camera.dt_max)
	return FollowCamera.clamp_to_map(eased, fp, bounds.position, bounds.end)


func test_party_placed_snaps_camera_with_zero_smoothing() -> void:
	var ctx: Dictionary = _make()
	var mode: OverworldMode = ctx["mode"]
	var view: OverworldView = ctx["view"]
	var camera: FollowCamera = view.get_camera()
	var bounds: Rect2 = _bounds(mode)
	_fit_camera(view, camera, bounds)
	var warp: Vector2 = bounds.position + bounds.size * Vector2(0.8, 0.7)
	mode._leader_pos = warp

	mode.party_placed.emit(warp)
	view._process(_DT)

	var aspect: float = camera.get_viewport().get_visible_rect().size.aspect()
	var fp: FollowCamera.Footprint = FollowCamera.compute_footprint(
			camera.height, camera.pitch_degrees, camera.fov_degrees, aspect)
	assert_vector(camera.cam_ground).is_equal_approx(
			FollowCamera.clamp_to_map(warp, fp, bounds.position, bounds.end), Vector2(1e-4, 1e-4))


func test_dialogue_holds_camera_until_it_closes() -> void:
	var ctx: Dictionary = _make()
	var machine: GameStateMachine = ctx["machine"]
	var mode: OverworldMode = ctx["mode"]
	var view: OverworldView = ctx["view"]
	var camera: FollowCamera = view.get_camera()
	var bounds: Rect2 = _bounds(mode)
	_fit_camera(view, camera, bounds)
	machine.open_overlay(GameStateMachine.OverlayKind.DIALOGUE,
			DialogueLinePayload.new("line", "speaker"))
	assert_bool(mode.is_dialogue_open()).is_true()
	var held_at: Vector2 = camera.cam_ground
	var held_pos: Vector3 = camera.position
	var start: Vector2 = bounds.position + bounds.size * 0.2
	var finish: Vector2 = bounds.position + bounds.size * 0.8
	for frame: int in 30:
		mode._leader_pos = start.lerp(finish, (frame + 1) / 30.0)
		view._process(_DT)
		assert_bool(camera.cam_ground == held_at and camera.position == held_pos) \
				.override_failure_message("frame %d" % frame).is_true()

	machine.close_overlay()
	assert_bool(mode.is_dialogue_open()).is_false()
	var expected: Vector2 = _expected_step(camera, held_at, mode.get_leader_position(), _DT, bounds)
	view._process(_DT)

	assert_vector(camera.cam_ground).is_equal_approx(expected, Vector2(1e-4, 1e-4))
	assert_bool(camera.cam_ground.is_equal_approx(held_at)).override_failure_message(
			"tracking must resume (sensitivity)").is_false()


func test_menu_freezes_camera_and_first_frame_after_is_one_dt_max_step() -> void:
	var ctx: Dictionary = _make()
	var mode: OverworldMode = ctx["mode"]
	var view: OverworldView = ctx["view"]
	var camera: FollowCamera = view.get_camera()
	var bounds: Rect2 = _bounds(mode)
	_fit_camera(view, camera, bounds)
	# The camera never steps itself; only the view does, and the view is
	# frozen with the mode (ModeHost disables the mode's subtree under the
	# Menu, ADR-0002 §5).
	assert_bool(camera.is_processing() or camera.is_physics_processing()).is_false()
	assert_bool(mode.is_ancestor_of(view)).is_true()
	assert_int(view.process_mode).is_equal(Node.PROCESS_MODE_INHERIT)
	mode.process_mode = Node.PROCESS_MODE_DISABLED
	assert_bool(view.can_process()).is_false()
	var frozen_at: Vector2 = camera.cam_ground
	mode._leader_pos = _bounds(mode).position + _bounds(mode).size * 0.8
	assert_vector(camera.cam_ground).is_equal(frozen_at)

	mode.process_mode = Node.PROCESS_MODE_INHERIT
	var expected: Vector2 = _expected_step(camera, frozen_at, mode.get_leader_position(),
			camera.dt_max, bounds)
	view._process(5.0)

	assert_vector(camera.cam_ground).is_equal_approx(expected, Vector2(1e-4, 1e-4))
	assert_bool(camera.cam_ground.is_equal_approx(frozen_at)).override_failure_message(
			"tracking must resume (sensitivity)").is_false()
