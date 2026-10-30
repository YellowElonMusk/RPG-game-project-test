## Story 006, AC-4: through a full battle of hit-punches the battle camera's
## position, rotation (pitch 0), `near`, `size` and `keep_aspect`
## (`KEEP_HEIGHT`) never change; only `frustum_offset` does, and on every
## frame it equals the stage's base lens shift plus the punch's lens shift
## (ADR-0005 §6). `size` changes only on a window resize. Expected values are
## recomputed from config through the formula, once with a non-default config.
extends GdUnitTestSuite

const _STAGE_PATH := "res://data/presentation/stages/battle_default.tres"
const _VIEWPORT := Vector2i(1920, 1080)
## float32 storage on Camera3D (real_t) -- the tolerance for read-backs.
const _TOL := 1e-7

## One battle's hit_punch offsets in whole pixels, frame by frame: a normal
## and a big beat each way, decaying with no ringing, with rest frames.
const _PUNCH_FRAMES: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(3, 0), Vector2i(2, 0), Vector2i(1, 0), Vector2i(0, 0),
	Vector2i(0, 7), Vector2i(0, 5), Vector2i(0, 3), Vector2i(0, 1), Vector2i(0, 0),
	Vector2i(-4, 0), Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(0, -14), Vector2i(0, -6),
	Vector2i(0, -1), Vector2i(0, 0),
]


func _config(non_default: bool) -> PresentationConfig:
	var config := PresentationConfig.new()
	if non_default:
		config.battle_fov_degrees = 24.0
		config.battle_camera_near = 0.1
		config.battle_camera_far = 150.0
	return config


func _rig(config: PresentationConfig, viewport_size: Vector2i) -> DioramaStage:
	var stage := DioramaStage.new()
	var cam := Camera3D.new()
	stage.add_child(cam)
	stage.camera = cam
	add_child(stage)
	auto_free(stage)
	stage.configure_battle_camera(load(_STAGE_PATH) as BattleStage, config, viewport_size)
	return stage


func _expected_size(config: PresentationConfig, viewport_size: Vector2i) -> float:
	var aspect: float = float(viewport_size.x) / float(viewport_size.y)
	return 2.0 * config.battle_camera_near * tan(deg_to_rad(config.battle_fov_degrees) / 2.0) \
			* maxf(1.0, (16.0 / 9.0) / aspect)


func _expected_offset(horizon_frac: float, h: float, punch: Vector2i, height: int) -> Vector2:
	return Vector2(float(punch.x) * h / float(height),
			-(0.5 - horizon_frac) * h - float(punch.y) * h / float(height))


func test_battle_camera_setup_is_level_frustum_keep_height(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var config := _config(non_default)
	var cam: Camera3D = _rig(config, _VIEWPORT).camera
	var stage_data := load(_STAGE_PATH) as BattleStage
	assert_int(cam.projection).is_equal(Camera3D.PROJECTION_FRUSTUM)
	assert_int(cam.keep_aspect).is_equal(Camera3D.KEEP_HEIGHT)
	assert_float(cam.rotation.x).is_equal(0.0)
	assert_bool(cam.transform.is_equal_approx(stage_data.camera_transform())).is_true()
	assert_float(cam.near).is_equal_approx(config.battle_camera_near, _TOL)
	assert_float(cam.size).is_equal_approx(_expected_size(config, _VIEWPORT), _TOL)
	assert_float(cam.h_offset).is_equal(0.0)
	assert_float(cam.v_offset).is_equal(0.0)


func test_full_battle_of_punches_changes_only_lens_shift(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var config := _config(non_default)
	var stage := _rig(config, _VIEWPORT)
	var cam: Camera3D = stage.camera
	var stage_data := load(_STAGE_PATH) as BattleStage
	var start_transform: Transform3D = cam.transform
	var start_size: float = cam.size
	var start_near: float = cam.near
	for punch: Vector2i in _PUNCH_FRAMES:
		stage.apply_hit_punch(punch)
		assert_bool(cam.transform == start_transform).is_true()
		assert_float(cam.rotation.x).is_equal(0.0)
		assert_float(cam.size).is_equal(start_size)
		assert_float(cam.near).is_equal(start_near)
		assert_int(cam.keep_aspect).is_equal(Camera3D.KEEP_HEIGHT)
		assert_float(cam.h_offset).is_equal(0.0)
		assert_float(cam.v_offset).is_equal(0.0)
		var expected: Vector2 = _expected_offset(stage_data.horizon_frac,
				_expected_size(config, _VIEWPORT), punch, _VIEWPORT.y)
		assert_vector(cam.frustum_offset).is_equal_approx(expected, Vector2(_TOL, _TOL))


func test_resize_changes_size_and_keeps_running_punch(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var config := _config(non_default)
	var stage := _rig(config, _VIEWPORT)
	var cam: Camera3D = stage.camera
	var start_transform: Transform3D = cam.transform
	var punch := Vector2i(0, 5)
	stage.apply_hit_punch(punch)
	var narrow := Vector2i(1440, 1080)
	stage.on_viewport_resized(narrow)
	var h: float = _expected_size(config, narrow)
	assert_float(cam.size).is_equal_approx(h, _TOL)
	assert_float(cam.size).is_greater(_expected_size(config, _VIEWPORT))
	assert_bool(cam.transform == start_transform).is_true()
	var stage_data := load(_STAGE_PATH) as BattleStage
	assert_vector(cam.frustum_offset).is_equal_approx(
			_expected_offset(stage_data.horizon_frac, h, punch, narrow.y), Vector2(_TOL, _TOL))


func test_camera_state_matrix_is_create_frustum_aspect() -> void:
	var config := _config(false)
	var cam: Camera3D = _rig(config, _VIEWPORT).camera
	var state := SpriteProjection.CameraState.from_camera3d(cam, _VIEWPORT)
	var aspect: float = float(_VIEWPORT.x) / float(_VIEWPORT.y)
	var expected: Projection = Projection.create_frustum_aspect(cam.size, aspect,
			cam.frustum_offset, cam.near, cam.far, false)
	assert_bool(state.projection == expected).is_true()
	assert_int(state.keep_aspect).is_equal(Camera3D.KEEP_HEIGHT)
