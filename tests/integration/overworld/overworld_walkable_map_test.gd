## Story 136 (AC-136): the assembled `overworld_mode.tscn` -- placeholder
## Town map baked into a `WalkGrid` at load, the leader stepped by
## `GroundMover.step()` against it (stop and slide), followers on the trail,
## the `FollowCamera` clamped to the map, the `overworld` profile applied by
## `PresentationDirector`, and no physics nodes anywhere. Drives the real
## scene through `GameStateFixtures`' machine with a `SyntheticActionSource`
## standing in for `InputResolver` (same `get_move_vector()` contract).
## Frames are stepped by calling `_process()` directly: no `await`, so the
## engine never ticks the scene on its own and every run is deterministic.
extends GdUnitTestSuite

const GameStateFixtures := preload("res://tests/unit/game_state/doubles/game_state_fixtures.gd")
const _SCENE: String = "res://src/overworld/overworld_mode.tscn"
const _PROFILE: String = "res://data/presentation/profiles/overworld.tres"
const _DT: float = 1.0 / 60.0
const _EPSILON: float = 1e-3
## Enough frames to cross the gap from spawn to the nearest wall at any
## tested walk speed (boundary of the test, not a gameplay value).
const _WALK_FRAMES: int = 240
const _SLIDE_FRAMES: int = 10


func _make(cfg: OverworldConfig) -> Dictionary:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var mode: OverworldMode = (load(_SCENE) as PackedScene).instantiate() as OverworldMode
	mode.config = cfg
	mode.setup(machine, null)
	loader.current_mode_node_value = mode
	var source := SyntheticActionSource.new()
	machine.bind_action_source(source)
	add_child(mode)
	auto_free(mode)
	var view: OverworldView = mode.get_node(^"OverworldView") as OverworldView
	return {"env": env, "machine": machine, "mode": mode, "source": source, "view": view}


func _step(ctx: Dictionary, frames: int) -> void:
	for i: int in frames:
		(ctx["mode"] as OverworldMode)._process(_DT)
		(ctx["view"] as OverworldView)._process(_DT)


## First non-walkable cell to the right of `from` on its row.
func _first_wall_right(grid: WalkGrid, from: Vector2i) -> int:
	var x: int = from.x
	while grid.is_walkable(Vector2i(x, from.y)):
		x += 1
	return x


func test_map_bakes_walk_layer_into_grid_at_load() -> void:
	var ctx: Dictionary = _make(OverworldConfig.new())
	var mode: OverworldMode = ctx["mode"]
	var grid: WalkGrid = mode.get_walk_grid()
	var layer: TileMapLayer = mode.get_map().walk_layer
	assert_object(grid).is_not_null()
	assert_that(grid.size).is_equal(layer.get_used_rect().size)
	var origin: Vector2i = layer.get_used_rect().position
	for cell: Vector2i in layer.get_used_cells():
		var walk: bool = bool(layer.get_cell_tile_data(cell).get_custom_data("walk"))
		assert_bool(grid.is_walkable(cell - origin)).is_equal(walk)
	assert_bool(layer.visible).is_false()
	assert_bool(grid.is_walkable(grid.cell_of(mode.get_leader_position()))).is_true()


func test_leader_stops_at_wall_and_slides_along_it() -> void:
	_assert_stop_and_slide(OverworldConfig.new())


func test_leader_stops_at_wall_and_slides_along_it_with_custom_config() -> void:
	var cfg := OverworldConfig.new()
	cfg.walk_speed = 5.0
	cfg.body_radius = 0.4
	_assert_stop_and_slide(cfg)


func _assert_stop_and_slide(cfg: OverworldConfig) -> void:
	var ctx: Dictionary = _make(cfg)
	var mode: OverworldMode = ctx["mode"]
	var source: SyntheticActionSource = ctx["source"]
	var grid: WalkGrid = mode.get_walk_grid()
	var start: Vector2 = mode.get_leader_position()
	var wall_x: int = _first_wall_right(grid, grid.cell_of(start))
	var stop_x: float = wall_x * grid.cell_m - cfg.body_radius

	source.move_vector = Vector2.RIGHT
	_step(ctx, _WALK_FRAMES)
	var at_wall: Vector2 = mode.get_leader_position()
	assert_float(at_wall.x).is_equal_approx(stop_x, _EPSILON)
	assert_float(at_wall.y).is_equal_approx(start.y, _EPSILON)

	# Diagonal into the wall: x holds, y slides at the open axis's share.
	source.move_vector = Vector2(1.0, 1.0)
	_step(ctx, _SLIDE_FRAMES)
	var slid: Vector2 = mode.get_leader_position()
	var expected_dy: float = _SLIDE_FRAMES * _DT * cfg.walk_speed * Vector2(1.0, 1.0).normalized().y
	assert_float(slid.x).is_equal_approx(stop_x, _EPSILON)
	assert_float(slid.y - at_wall.y).is_equal_approx(expected_dy, _EPSILON)


func test_follow_camera_is_clamped_to_map_bounds() -> void:
	var ctx: Dictionary = _make(OverworldConfig.new())
	var mode: OverworldMode = ctx["mode"]
	var view: OverworldView = ctx["view"]
	var camera: FollowCamera = view.get_camera()
	var bounds: Rect2 = OverworldMap.ground_bounds(mode.get_walk_grid())
	var size: Vector2 = Vector2(view.get_viewport().get_visible_rect().size)
	var aspect: float = size.x / size.y
	var fp: FollowCamera.Footprint = FollowCamera.compute_footprint(
			camera.height, camera.pitch_degrees, camera.fov_degrees, aspect)
	var dz: Vector2 = FollowCamera.dead_zone(fp, camera.dead_zone_fraction)
	var far_outside: Vector2 = bounds.position - bounds.size
	camera.snap_to(far_outside)
	view._process(_DT)
	var eased: Vector2 = FollowCamera.ease_step(
			far_outside, mode.get_leader_position(), dz, camera.tau, _DT, camera.dt_max)
	var expected: Vector2 = FollowCamera.clamp_to_map(eased, fp, bounds.position, bounds.end)
	assert_vector(camera.cam_ground).is_equal_approx(expected, Vector2(_EPSILON, _EPSILON))
	# The clamp engaged (the eased point lay outside the allowed range), and
	# the result is a fixed point of the clamp: per axis inside
	# [min + far edge, max - near edge] (map y points toward the camera), or
	# centred on that range when the
	# footprint is larger than the map (`clamp_or_centre`).
	assert_bool(camera.cam_ground.is_equal_approx(eased)).is_false()
	assert_vector(FollowCamera.clamp_to_map(camera.cam_ground, fp, bounds.position, bounds.end)) \
			.is_equal_approx(camera.cam_ground, Vector2(_EPSILON, _EPSILON))


## Regression (2026-10-29): the clamp read map `y` as pointing away from the
## camera, so the focus could never move toward a map's south (+y) edge and
## a leader on the bottom rows walked off screen. A leader one cell from the
## south wall must stay within the footprint's near edge of the focus.
func test_leader_on_the_south_rows_stays_on_screen() -> void:
	var ctx: Dictionary = _make(OverworldConfig.new())
	var mode: OverworldMode = ctx["mode"]
	var view: OverworldView = ctx["view"]
	var camera: FollowCamera = view.get_camera()
	var grid: WalkGrid = mode.get_walk_grid()
	var size: Vector2 = Vector2(view.get_viewport().get_visible_rect().size)
	var fp: FollowCamera.Footprint = FollowCamera.compute_footprint(
			camera.height, camera.pitch_degrees, camera.fov_degrees, size.x / size.y)
	var south := Vector2(grid.size.x * 0.5, (grid.size.y - 1.5) * grid.cell_m)
	mode.teleport_leader(south, Vector2.DOWN)
	camera.snap_to(south)
	for i: int in 120:
		view._process(_DT)
	assert_float(mode.get_leader_position().y - camera.cam_ground.y).is_less_equal(fp.a_near)


func test_followers_render_on_the_trail() -> void:
	var ctx: Dictionary = _make(OverworldConfig.new())
	var mode: OverworldMode = ctx["mode"]
	var view: OverworldView = ctx["view"]
	(ctx["source"] as SyntheticActionSource).move_vector = Vector2.LEFT
	_step(ctx, _WALK_FRAMES)
	assert_vector(view.leader_sprite.position) \
			.is_equal(OverworldView.ground_to_world(mode.get_leader_position()))
	var followers: Array[Vector2] = mode.get_follower_positions()
	assert_int(followers.size()).is_equal(view.follower_count)
	for i: int in view.follower_count:
		var sprite: CharacterSprite = view.follower_sprites[i]
		assert_bool(sprite.visible).is_true()
		assert_vector(sprite.position).is_equal(OverworldView.ground_to_world(followers[i]))
		assert_object(sprite.card_camera).is_same(view.get_camera())
		assert_int(sprite.layers).is_equal(DioramaStage.LAYER_ACTORS)


func test_scene_has_one_stage_one_camera_and_no_physics_nodes() -> void:
	var ctx: Dictionary = _make(OverworldConfig.new())
	var mode: OverworldMode = ctx["mode"]
	var stages: int = 0
	var cameras: int = 0
	var envs: int = 0
	var physics: Array[String] = []
	var stack: Array[Node] = [mode]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is DioramaStage:
			stages += 1
		if node is Camera3D:
			cameras += 1
		if node is WorldEnvironment:
			envs += 1
		if node is CollisionObject3D or node is CollisionObject2D or node is CollisionShape3D:
			physics.append(str(node.get_path()))
	assert_int(stages).is_equal(1)
	assert_int(cameras).is_equal(1)
	assert_int(envs).is_equal(1)
	assert_array(physics).is_empty()
	assert_int(mode.get_map().walk_layer.tile_set.get_physics_layers_count()).is_equal(0)


func test_mode_entry_applies_overworld_profile() -> void:
	var ctx: Dictionary = _make(OverworldConfig.new())
	var machine: GameStateMachine = ctx["machine"]
	var cfg: TransitionConfig = (ctx["env"] as Dictionary)["config"]
	var stage: DioramaStage = (ctx["mode"] as OverworldMode).get_node(^"DioramaStage") as DioramaStage
	var director: PresentationDirector = auto_free(PresentationDirector.new())
	add_child(director)
	director.setup(machine, PresentationConfig.new(), GlobalUniformSink.new())
	var profile: LightingProfile = ResourceLoader.load(
			_PROFILE, "", ResourceLoader.CACHE_MODE_IGNORE) as LightingProfile

	# Battle -> Overworld is outcome-driven; a fresh map entry is the
	# requestable Overworld -> Overworld fade row, which is not same-mode for
	# the director only if from != to -- so drive Overworld -> Camp -> Overworld.
	assert_int(machine.request_transition(GameStateMachine.Mode.CAMP, null)) \
			.is_equal(GameStateMachine.RequestResult.OK)
	machine.tick(cfg.t_out[&"fade"])
	machine.tick(0.0)
	machine.tick(cfg.t_in[&"fade"])
	assert_int(machine.request_transition(GameStateMachine.Mode.OVERWORLD, null)) \
			.is_equal(GameStateMachine.RequestResult.OK)
	machine.tick(cfg.t_out[&"fade"])
	machine.tick(0.0)
	machine.tick(cfg.t_in[&"fade"])

	assert_str(String(stage.profile_id)).is_equal("overworld")
	assert_float(stage.key_light.light_energy).is_equal_approx(profile.key_energy, _EPSILON)
	assert_float(stage.set_light.light_energy).is_equal_approx(profile.set_energy, _EPSILON)
	assert_bool(stage.current_rim_color.is_equal_approx(profile.rim_color)).is_true()
