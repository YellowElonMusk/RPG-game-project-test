## Story 047, AC-43 [L] (GDD `battle_framing`, "Visible share"; ADR-0005 §2,
## §3): every shipped battle stage, with every slot filled, keeps every
## slot's `visible_share >= actor_visible_min` at the default battle camera.
## A slot's share counts nearer actors' quads AND the projected bounds of set
## geometry tagged as an occluder in front of it; geometry behind a slot,
## and blob shadows (never tagged), never count. The threshold is read from
## the shipped config, never written here.
extends GdUnitTestSuite

const _BATTLE_SCENE := "res://src/battle/battle_mode.tscn"
## Fixture slot depth (m) and an occluder slab in front of / behind it.
const _SLOT_Z: float = 9.0
const _NEAR_SLAB := Vector2(5.0, 5.5)
const _FAR_SLAB := Vector2(20.0, 20.5)


func _config() -> PresentationConfig:
	return PresentationValidators.load_config()


func _has_rule(errors: PackedStringArray, rule: String) -> bool:
	for e: String in errors:
		if e.begins_with(rule):
			return true
	return false


## One slot at x = 0 (the screen's centre column), depth `_SLOT_Z`.
func _one_slot() -> BattleStage:
	var stage := BattleStage.new()
	stage.stage_id = &"fixture_one_slot"
	stage.slot_depth_step = 0.0
	stage.actor_frame_size = Vector2i(64, 64)
	stage.slots = [Vector2(0.0, _SLOT_Z)] as Array[Vector2]
	stage.background_blur_begin = 100.0
	return stage


## A box from `x0` to `x1` (m), floor to 10 m high, between view depths
## `depths.x` and `depths.y`.
func _box(x0: float, x1: float, depths: Vector2) -> AABB:
	return AABB(Vector3(x0, 0.0, -depths.y), Vector3(x1 - x0, 10.0, depths.y - depths.x))


func test_shipped_stages_every_slot_filled_pass_actor_visible_min() -> void:
	var config := _config()
	var stages: Array[BattleStage] = PresentationValidators.load_battle_stages()
	assert_int(stages.size()).is_greater_equal(2)
	for stage: BattleStage in stages:
		var shares: PackedFloat64Array = BattleFraming.visible_shares(stage, config)
		assert_int(shares.size()).is_equal(stage.slots.size())
		for i: int in shares.size():
			assert_float(shares[i]).override_failure_message("%s slot %d share %.4f < %.2f"
					% [stage.stage_id, i, shares[i], config.actor_visible_min]) \
					.is_greater_equal(config.actor_visible_min - BattleFraming.EPSILON)
		assert_bool(_has_rule(BattleFraming.validate(stage, config), BattleFraming.RULE_VISIBLE)).is_false()


func test_occluder_in_front_hiding_whole_quad_fails_at_load() -> void:
	var stage := _one_slot()
	stage.occluders = [_box(-5.0, 5.0, _NEAR_SLAB)] as Array[AABB]
	assert_float(BattleFraming.visible_shares(stage, _config())[0]).is_equal(0.0)
	assert_bool(_has_rule(BattleFraming.validate(stage, _config()), BattleFraming.RULE_VISIBLE)).is_true()


func test_occluder_in_front_of_right_half_leaves_half_visible() -> void:
	var stage := _one_slot()
	stage.occluders = [_box(0.0, 5.0, _NEAR_SLAB)] as Array[AABB]
	var q_w: int = stage.actor_frame_size.x * SpriteProjection.texel_scale(1080, _config().texel_base_lines)
	assert_float(BattleFraming.visible_shares(stage, _config())[0]).is_equal_approx(0.5, 1.0 / float(q_w))


func test_occluder_behind_slot_hides_nothing() -> void:
	var stage := _one_slot()
	stage.occluders = [_box(-5.0, 5.0, _FAR_SLAB)] as Array[AABB]
	assert_float(BattleFraming.visible_shares(stage, _config())[0]).is_equal(1.0)
	assert_array(Array(BattleFraming.validate(stage, _config()))).is_empty()


func test_occluder_share_exactly_at_min_passes_and_below_fails() -> void:
	var stage := _one_slot()
	stage.occluders = [_box(0.1, 5.0, _NEAR_SLAB)] as Array[AABB]
	var config := _config()
	var share: float = BattleFraming.visible_shares(stage, config)[0]
	assert_float(share).is_greater(0.0)
	assert_float(share).is_less(1.0)
	config.actor_visible_min = share
	assert_bool(_has_rule(BattleFraming.validate(stage, config), BattleFraming.RULE_VISIBLE)).is_false()
	config.actor_visible_min = share + 0.01
	assert_bool(_has_rule(BattleFraming.validate(stage, config), BattleFraming.RULE_VISIBLE)).is_true()


func test_stage_passing_only_with_a_slot_empty_fails() -> void:
	# A back slot directly behind a front slot, too close: hidden. Without
	# it the formation passes, but the check always fills every slot.
	var stage := _one_slot()
	stage.slots = [Vector2(0.0, _SLOT_Z), Vector2(1.5, _SLOT_Z + 0.5), Vector2(0.0, _SLOT_Z + 0.4)] as Array[Vector2]
	assert_bool(_has_rule(BattleFraming.validate(stage, _config()), BattleFraming.RULE_VISIBLE)).is_true()
	stage.slots.remove_at(2)
	assert_bool(_has_rule(BattleFraming.validate(stage, _config()), BattleFraming.RULE_VISIBLE)).is_false()


func test_screen_bounds_encloses_every_projected_corner() -> void:
	var stage := _one_slot()
	var vp := BattleFraming.DEFAULT_VIEWPORT
	var cam := BattleFraming.camera_state(stage, _config(), vp)
	var box := _box(-1.0, 2.0, _NEAR_SLAB)
	var rect: Rect2i = SpriteProjection.screen_bounds(box, cam, vp)
	assert_int(rect.get_area()).is_greater(0)
	for c: int in 8:
		var p: Vector2 = SpriteProjection.project_to_screen(box.get_endpoint(c), cam, vp)
		assert_bool(Rect2(rect).grow(0.001).has_point(p)).override_failure_message(
				"corner %s outside %s" % [p, rect]).is_true()


func test_occluder_bounds_counts_tagged_mesh_not_blob_shadow() -> void:
	var stage: DioramaStage = auto_free(DioramaStage.new())
	stage.add_child(stage.make_blob_shadow())
	var holder := Node3D.new()
	holder.position = Vector3(1.0, 0.0, -6.0)
	stage.add_child(holder)
	var pillar := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 2.0, 0.5)
	pillar.mesh = box
	pillar.position = Vector3(0.0, 1.0, 0.0)
	pillar.set_meta(&"capture_id", String(DioramaStage.OCCLUDER_TAG))
	holder.add_child(pillar)
	var bounds: Array[AABB] = stage.occluder_bounds()
	assert_int(bounds.size()).is_equal(1)
	assert_bool(bounds[0].is_equal_approx(AABB(Vector3(0.75, 0.0, -6.25), Vector3(0.5, 2.0, 0.5)))) \
			.override_failure_message("got %s" % bounds[0]).is_true()


func test_battle_scene_occluders_are_declared_in_every_shipped_stage() -> void:
	var mode: Node = auto_free((load(_BATTLE_SCENE) as PackedScene).instantiate())
	var stage := mode.get_node(^"%DioramaStage") as DioramaStage
	assert_object(stage).is_not_null()
	var scene_bounds: Array[AABB] = stage.occluder_bounds()
	for battle_stage: BattleStage in PresentationValidators.load_battle_stages():
		for b: AABB in scene_bounds:
			var declared: bool = false
			for d: AABB in battle_stage.occluders:
				declared = declared or d.grow(0.001).encloses(b)
			assert_bool(declared).override_failure_message("%s: scene occluder %s not in stage data"
					% [battle_stage.stage_id, b]).is_true()
