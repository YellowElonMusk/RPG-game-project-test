## Story 063, AC-58: a foot anchor moving 0.37 screen px per frame for 120
## frames, under the level battle camera and the pitched Overworld camera,
## keeps its quad's bottom-centre on the whole pixel that round-half-away-
## from-zero gives, and its size never changes. The start phase (x.13) puts
## frames 1 and 101 on an exact half pixel, exercising the tie-break.
extends GdUnitTestSuite

const _STEP_PX: float = 0.37
const _FRAMES: int = 120
const _START_PHASE: float = 0.13
const _VIEWPORT := Vector2i(1920, 1080)
## Even and odd pixel widths (odd: `x_left = x_a - floor(w/2)`).
const _FRAME_SIZES: Array = [[Vector2i(48, 64)], [Vector2i(47, 63)]]


func _battle_cam(config: PresentationConfig) -> SpriteProjection.CameraState:
	var stage := load("res://data/presentation/stages/battle_default.tres") as BattleStage
	return BattleFraming.camera_state(stage, config, _VIEWPORT)


func _overworld_cam(config: PresentationConfig) -> SpriteProjection.CameraState:
	var aspect: float = float(_VIEWPORT.x) / float(_VIEWPORT.y)
	var basis := Basis(Vector3.RIGHT, deg_to_rad(-config.follow_camera_pitch_degrees))
	var xf := Transform3D(basis, Vector3(0.0, config.follow_camera_height, 0.0))
	var fov: float = FollowCamera.effective_vertical_fov_degrees(config.follow_camera_fov_degrees, aspect)
	return SpriteProjection.CameraState.from_perspective(xf, fov, aspect,
			config.battle_camera_near, config.battle_camera_far)


## Moves an anchor along world x at a fixed view depth (screen x is linear in
## world x there) by `_STEP_PX` per frame and checks every frame.
func _run(cam: SpriteProjection.CameraState, base: Vector3, frame_size: Vector2i,
		config: PresentationConfig) -> void:
	var p0: float = SpriteProjection.project_to_screen(base, cam, _VIEWPORT).x
	var p1: float = SpriteProjection.project_to_screen(base + Vector3.RIGHT, cam, _VIEWPORT).x
	var px_per_m: float = p1 - p0
	var start: float = floorf(p0) + _START_PHASE
	var t: int = SpriteProjection.texel_scale(_VIEWPORT.y, config.texel_base_lines)
	var size := Vector2i(frame_size.x * t, frame_size.y * t)
	var ties: int = 0
	for k: int in _FRAMES:
		var target: float = start + _STEP_PX * float(k)
		var anchor: Vector3 = base + Vector3.RIGHT * ((target - p0) / px_per_m)
		var unrounded: Vector2 = SpriteProjection.project_to_screen(anchor, cam, _VIEWPORT)
		var rect: Rect2i = SpriteProjection.screen_rect(anchor, cam, frame_size, _VIEWPORT,
				config.texel_base_lines)
		var bottom_centre := Vector2i(rect.position.x + size.x / 2, rect.end.y)
		assert_vector(bottom_centre).is_equal(SpriteProjection.round_pixel(unrounded))
		assert_float(absf(unrounded.x - target)).is_less(1e-3)
		assert_vector(rect.size).is_equal(size)
		if is_equal_approx(fposmod(target, 1.0), 0.5):
			ties += 1
	assert_int(ties).is_greater_equal(2)


func test_battle_camera_snaps_every_frame(frame_size: Vector2i,
		test_parameters := _FRAME_SIZES) -> void:
	var config := PresentationConfig.new()
	_run(_battle_cam(config), Vector3(0.0, 0.0, -9.0), frame_size, config)


func test_pitched_overworld_camera_snaps_every_frame(frame_size: Vector2i,
		test_parameters := _FRAME_SIZES) -> void:
	var config := PresentationConfig.new()
	var ahead: float = config.follow_camera_height / tan(deg_to_rad(config.follow_camera_pitch_degrees))
	_run(_overworld_cam(config), Vector3(0.0, 0.0, -ahead), frame_size, config)


func test_non_default_config_snaps_in_both_modes() -> void:
	var config := PresentationConfig.new()
	config.battle_fov_degrees = 24.0
	config.follow_camera_pitch_degrees = 35.0
	config.texel_base_lines = 270
	_run(_battle_cam(config), Vector3(0.5, 0.0, -11.0), Vector2i(47, 63), config)
	var ahead: float = config.follow_camera_height / tan(deg_to_rad(config.follow_camera_pitch_degrees))
	_run(_overworld_cam(config), Vector3(0.0, 0.0, -ahead), Vector2i(48, 64), config)


func test_half_pixel_tie_rounds_away_from_zero() -> void:
	assert_vector(SpriteProjection.round_pixel(Vector2(10.5, 7.5))).is_equal(Vector2i(11, 8))
	assert_vector(SpriteProjection.round_pixel(Vector2(-10.5, -0.5))).is_equal(Vector2i(-11, -1))
