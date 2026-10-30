## Story 007, AC-5: in Camp (pitched) and Title (level), when a hit resolves
## or the party moves, the stage's fixed camera keeps its transform and lens
## shift -- the punch and resize paths are battle-only (ADR-0005 §6).
extends GdUnitTestSuite

## (pitch_degrees, position) per mode: Camp pitched, Title level.
const _MODES: Array = [
	[-25.0, Vector3(0.0, 4.0, 8.0)],
	[0.0, Vector3(0.0, 1.6, 6.0)],
]


func _fixed_stage(pitch_degrees: float, position: Vector3) -> DioramaStage:
	var stage := DioramaStage.new()
	var cam := Camera3D.new()
	cam.position = position
	cam.rotation_degrees = Vector3(pitch_degrees, 0.0, 0.0)
	stage.add_child(cam)
	stage.camera = cam
	var party := Node3D.new()
	party.name = &"Party"
	stage.add_child(party)
	add_child(stage)
	auto_free(stage)
	return stage


func test_hit_and_party_move_leave_fixed_camera_unchanged(pitch_degrees: float,
		position: Vector3, test_parameters := _MODES) -> void:
	var stage := _fixed_stage(pitch_degrees, position)
	var cam: Camera3D = stage.camera
	var start_transform: Transform3D = cam.global_transform
	var start_offset: Vector2 = cam.frustum_offset
	var party: Node3D = stage.get_node(^"Party")
	assert_bool(stage.is_battle_camera()).is_false()
	for frame: int in 60:
		party.position += Vector3(0.1, 0.0, -0.05)
		if frame % 10 == 0:
			stage.apply_hit_punch(Vector2i(7, -3))
		stage._process(1.0 / 60.0)
		assert_bool(cam.global_transform == start_transform).is_true()
		assert_vector(cam.frustum_offset).is_equal(start_offset)
	stage.apply_hit_punch(Vector2i.ZERO)
	stage.on_viewport_resized(Vector2i(1440, 1080))
	assert_bool(cam.global_transform == start_transform).is_true()
	assert_vector(cam.frustum_offset).is_equal(start_offset)


func test_stage_camera_is_current_and_pitch_kept(pitch_degrees: float,
		position: Vector3, test_parameters := _MODES) -> void:
	var cam: Camera3D = _fixed_stage(pitch_degrees, position).camera
	assert_bool(cam.current).is_true()
	assert_float(cam.rotation_degrees.x).is_equal_approx(pitch_degrees, 1e-4)
