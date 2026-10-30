## Story 050, AC-46: at 16:9, 21:9, 16:10 and 4:3 every actor slot's quad
## lies inside the battle camera's view, and the camera keeps the 16:9
## horizontal view below 16:9 and the 16:9 vertical view at and above it.
## The matrix comes from `Projection.create_frustum_aspect` via
## `SpriteProjection.CameraState` -- never `get_camera_projection()`.
extends GdUnitTestSuite

const _ASPECT_16_9: float = 16.0 / 9.0


func _config(non_default: bool) -> PresentationConfig:
	var config := PresentationConfig.new()
	if non_default:
		config.battle_fov_degrees = 18.0
		config.battle_camera_near = 0.1
	return config


func test_every_slot_quad_inside_view_at_every_aspect(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var config := _config(non_default)
	for stage: BattleStage in PresentationValidators.load_battle_stages():
		for vp: Vector2i in BattleFraming.SUPPORTED_VIEWPORTS:
			for rect: Rect2i in BattleFraming.slot_rects(stage, config, vp):
				assert_bool(BattleFraming.rect_in_frame(rect, vp)) \
						.override_failure_message("%s out of %s at %s" % [rect, vp, stage.stage_id]) \
						.is_true()


func test_camera_keeps_16_9_horizontal_below_and_vertical_above(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var config := _config(non_default)
	var stage := PresentationValidators.load_battle_stages()[0]
	var tan_v_ref: float = tan(deg_to_rad(config.battle_fov_degrees) / 2.0)
	var tan_h_ref: float = tan_v_ref * _ASPECT_16_9
	for vp: Vector2i in BattleFraming.SUPPORTED_VIEWPORTS:
		var aspect: float = float(vp.x) / float(vp.y)
		var proj: Projection = BattleFraming.camera_state(stage, config, vp).projection
		var tan_h: float = 1.0 / proj.x.x
		var tan_v: float = 1.0 / proj.y.y
		if aspect < _ASPECT_16_9 - 1e-6:
			assert_float(tan_h).is_equal_approx(tan_h_ref, 1e-5)
			assert_float(tan_v).is_greater(tan_v_ref)
		else:
			assert_float(tan_v).is_equal_approx(tan_v_ref, 1e-5)
			assert_float(tan_h).is_greater_equal(tan_h_ref - 1e-5)
			if aspect > _ASPECT_16_9 + 1e-6:
				assert_float(tan_h).is_greater(tan_h_ref)
