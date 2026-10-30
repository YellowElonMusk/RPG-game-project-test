## Story 022, AC-19: `battle_framing` (GDD Formulas). Foot rows on
## `y_foot(z)` within 0.5 px; the `visible_share` boundary; in-line slots
## pass exactly when `row_gap >= actor_visible_min * q`; the `z_near`,
## 1-px-out-of-frame, DOF and boss-sky failures; the worked example.
extends GdUnitTestSuite

const _STAGE_PATH := "res://data/presentation/stages/battle_default.tres"


func _config(non_default: bool) -> PresentationConfig:
	var config := PresentationConfig.new()
	if non_default:
		config.battle_fov_degrees = 24.0
		config.actor_visible_min = 0.86
		config.dof_margin = 1.5
		config.sky_share_min = 0.25
	return config


## Two slots, the far one directly behind the near one.
func _in_line(z_near: float, z_far: float) -> BattleStage:
	var stage := BattleStage.new()
	stage.stage_id = &"fixture_in_line"
	stage.slot_depth_step = 0.0
	stage.actor_frame_size = Vector2i(64, 64)
	stage.slots = [Vector2(0.0, z_near), Vector2(0.0, z_far)] as Array[Vector2]
	stage.background_blur_begin = 100.0
	return stage


func _has_rule(errors: PackedStringArray, rule: String) -> bool:
	for e: String in errors:
		if e.begins_with(rule):
			return true
	return false


func _aspect(vp: Vector2i) -> float:
	return float(vp.x) / float(vp.y)


func test_foot_rows_match_y_foot_within_half_pixel(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var config := _config(non_default)
	var stage := load(_STAGE_PATH) as BattleStage
	for vp: Vector2i in BattleFraming.SUPPORTED_VIEWPORTS:
		var f: float = BattleFraming.f_px(config.battle_fov_degrees, _aspect(vp), vp.y)
		var rects: Array[Rect2i] = BattleFraming.slot_rects(stage, config, vp)
		for i: int in rects.size():
			var expected: float = BattleFraming.y_foot(stage.slot_depth(i), stage.h_cam,
					stage.horizon_frac, f, vp.y)
			assert_float(absf(float(rects[i].end.y) - expected)).is_less_equal(0.5)


func test_lens_shift_puts_horizon_at_horizon_frac(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var config := _config(non_default)
	var stage := load(_STAGE_PATH) as BattleStage
	for vp: Vector2i in BattleFraming.SUPPORTED_VIEWPORTS:
		var cam := BattleFraming.camera_state(stage, config, vp)
		var far_eye := Vector3(0.0, stage.h_cam, -config.battle_camera_far * 0.9)
		var y: float = SpriteProjection.project_to_screen(far_eye, cam, vp).y
		assert_float(y).is_equal_approx(stage.horizon_frac * float(vp.y), 0.5)


func test_formula_worked_example_is_reproduced() -> void:
	var f: float = BattleFraming.f_px(20.0, 16.0 / 9.0, 1080)
	assert_float(f).is_equal_approx(3062.5, 0.1)
	var y9: float = BattleFraming.y_foot(9.0, 1.6, 0.30, f, 1080)
	var y15: float = BattleFraming.y_foot(15.0, 1.6, 0.30, f, 1080)
	var y12: float = BattleFraming.y_foot(12.0, 1.6, 0.30, f, 1080)
	assert_float(y9).is_equal_approx(868.4, 0.05)
	assert_float(y15).is_equal_approx(650.7, 0.05)
	assert_float(y9 - y15).is_equal_approx(217.8, 0.05)
	assert_float(y12).is_equal_approx(732.3, 0.05)
	assert_float(y9 - y12).is_equal_approx(136.1, 0.05)
	var q: int = 64 * SpriteProjection.texel_scale(1080, 360)
	assert_int(q).is_equal(192)
	assert_float(0.90 * float(q)).is_equal_approx(172.8, 1e-6)
	assert_float((y9 - y12) / float(q)).is_equal_approx(0.71, 0.005)
	var config := _config(false)
	var shares := BattleFraming.visible_shares(_in_line(9.0, 15.0), config)
	assert_float(shares[1]).is_equal(1.0)


func test_visible_share_exactly_at_min_passes_and_below_fails(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var config := _config(non_default)
	var stage := _in_line(9.0, 13.2)
	var share: float = BattleFraming.visible_shares(stage, config)[1]
	config.actor_visible_min = share
	assert_bool(_has_rule(BattleFraming.validate(stage, config),
			BattleFraming.RULE_VISIBLE)).is_false()
	config.actor_visible_min = share + 0.01
	assert_bool(_has_rule(BattleFraming.validate(stage, config),
			BattleFraming.RULE_VISIBLE)).is_true()


func test_in_line_slots_pass_exactly_when_row_gap_covers_min_q(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var config := _config(non_default)
	var saw_pass := false
	var saw_fail := false
	for k: int in 41:
		var stage := _in_line(9.0, 11.0 + 0.125 * float(k))
		var rects: Array[Rect2i] = BattleFraming.slot_rects(stage, config, BattleFraming.DEFAULT_VIEWPORT)
		var row_gap: int = rects[0].end.y - rects[1].end.y
		var q: int = rects[1].size.y
		var expect_pass: bool = float(row_gap) >= config.actor_visible_min * float(q) - BattleFraming.EPSILON
		var passed: bool = not _has_rule(BattleFraming.validate(stage, config), BattleFraming.RULE_VISIBLE)
		assert_bool(passed).is_equal(expect_pass)
		saw_pass = saw_pass or passed
		saw_fail = saw_fail or not passed
	assert_bool(saw_pass and saw_fail).is_true()


func test_z_near_not_positive_fails() -> void:
	for z: float in [0.0, -1.0]:
		var errors := BattleFraming.validate(_in_line(z, 15.0), _config(false))
		assert_bool(_has_rule(errors, BattleFraming.RULE_Z_NEAR)).is_true()


func test_rect_in_frame_rejects_one_pixel_out() -> void:
	var vp := Vector2i(1920, 1080)
	assert_bool(BattleFraming.rect_in_frame(Rect2i(0, 0, 144, 192), vp)).is_true()
	assert_bool(BattleFraming.rect_in_frame(Rect2i(-1, 0, 144, 192), vp)).is_false()
	assert_bool(BattleFraming.rect_in_frame(Rect2i(1776, 888, 144, 192), vp)).is_true()
	assert_bool(BattleFraming.rect_in_frame(Rect2i(1777, 888, 144, 192), vp)).is_false()
	assert_bool(BattleFraming.rect_in_frame(Rect2i(1776, 889, 144, 192), vp)).is_false()


## Walks a single slot left until its quad first leaves the 4:3 frame: that
## stage fails naming 4:3 with the quad exactly 1 px out; the step before passes.
func test_quad_one_pixel_left_of_frame_at_4_3_fails() -> void:
	var config := _config(false)
	var narrow := Vector2i(1440, 1080)
	var prev_x: float = 0.0
	for k: int in 4000:
		var stage := _in_line(9.0, 9.5)
		stage.slots = [Vector2(-0.001 * float(k), 9.0)] as Array[Vector2]
		var left: int = BattleFraming.slot_rects(stage, config, narrow)[0].position.x
		if left < 0:
			assert_int(left).is_equal(-1)
			var errors := BattleFraming.validate(stage, config)
			assert_bool(_has_rule(errors, BattleFraming.RULE_IN_FRAME)).is_true()
			assert_bool(errors[0].contains("1440x1080")).is_true()
			stage.slots = [Vector2(prev_x, 9.0)] as Array[Vector2]
			assert_bool(_has_rule(BattleFraming.validate(stage, config),
					BattleFraming.RULE_IN_FRAME)).is_false()
			return
		prev_x = -0.001 * float(k)
	fail("slot never left the 4:3 frame")


## Walks a single slot nearer until its foot row first passes the bottom edge:
## exactly 1 px out, the stage fails at 16:9 and 21:9.
func test_quad_one_pixel_below_frame_at_16_9_and_21_9_fails() -> void:
	var config := _config(false)
	for k: int in 4000:
		var stage := _in_line(9.0, 9.5)
		var z: float = 8.0 - 0.001 * float(k)
		stage.slots = [Vector2(0.0, z)] as Array[Vector2]
		var bottom: int = BattleFraming.slot_rects(stage, config, Vector2i(1920, 1080))[0].end.y
		if bottom > 1080:
			assert_int(bottom).is_equal(1081)
			var errors := BattleFraming.validate(stage, config)
			var joined: String = "\n".join(errors)
			assert_bool(joined.contains("1920x1080")).is_true()
			assert_bool(joined.contains("2520x1080")).is_true()
			return
	fail("slot never left the bottom of the frame")


func test_blur_before_z_far_plus_margin_fails(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var config := _config(non_default)
	var stage := load(_STAGE_PATH).duplicate() as BattleStage
	var z_far: float = 0.0
	for i: int in stage.slots.size():
		z_far = maxf(z_far, stage.slot_depth(i))
	stage.background_blur_begin = z_far + config.dof_margin
	assert_bool(_has_rule(BattleFraming.validate(stage, config), BattleFraming.RULE_DOF)).is_false()
	stage.background_blur_begin = z_far + config.dof_margin - 0.01
	assert_bool(_has_rule(BattleFraming.validate(stage, config), BattleFraming.RULE_DOF)).is_true()


func test_boss_horizon_below_sky_share_min_fails(non_default: bool,
		test_parameters := [[false], [true]]) -> void:
	var config := _config(non_default)
	var stage := load(_STAGE_PATH).duplicate() as BattleStage
	stage.is_boss = true
	stage.horizon_frac = config.sky_share_min
	assert_bool(_has_rule(BattleFraming.validate(stage, config), BattleFraming.RULE_SKY)).is_false()
	stage.horizon_frac = config.sky_share_min - 0.01
	assert_bool(_has_rule(BattleFraming.validate(stage, config), BattleFraming.RULE_SKY)).is_true()
	stage.is_boss = false
	assert_bool(_has_rule(BattleFraming.validate(stage, config), BattleFraming.RULE_SKY)).is_false()


func test_union_area_counts_overlap_once() -> void:
	var rects: Array[Rect2i] = [Rect2i(0, 0, 10, 10), Rect2i(5, 5, 10, 10)]
	assert_int(BattleFraming.union_area(rects)).is_equal(175)
