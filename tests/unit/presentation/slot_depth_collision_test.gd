## Story 046, AC-42: in every shipped battle formation no two actor slots
## share a view depth, and the staggered stage still passes `battle_framing`.
## Fixtures prove the check catches a real collision (unstaggered row, and a
## stagger that itself lands two slots on one depth).
extends GdUnitTestSuite

const _STAGE_PATH := "res://data/presentation/stages/battle_default.tres"


func _has_rule(errors: PackedStringArray, rule: String) -> bool:
	for e: String in errors:
		if e.begins_with(rule):
			return true
	return false


func test_every_shipped_stage_has_unique_depths_and_passes_framing() -> void:
	var stages: Array[BattleStage] = PresentationValidators.load_battle_stages()
	assert_int(stages.size()).is_greater_equal(1)
	for stage: BattleStage in stages:
		assert_array(BattleFraming.depth_collisions(stage)).is_empty()
		assert_array(Array(BattleFraming.validate(stage, PresentationConfig.new()))).is_empty()
	assert_array(Array(PresentationValidators.validate_battle_stages(stages,
			PresentationConfig.new()))).is_empty()


func test_unstaggered_row_collides_and_names_the_stage() -> void:
	var stage := load(_STAGE_PATH).duplicate() as BattleStage
	stage.slot_depth_step = 0.0
	assert_array(BattleFraming.depth_collisions(stage)).is_not_empty()
	var errors := BattleFraming.validate(stage, PresentationConfig.new())
	assert_bool(_has_rule(errors, BattleFraming.RULE_UNIQUE_DEPTH)).is_true()
	assert_bool("\n".join(errors).contains(String(stage.stage_id))).is_true()


func test_stagger_that_lands_on_a_neighbour_depth_collides() -> void:
	var stage := BattleStage.new()
	stage.stage_id = &"fixture_stagger_collision"
	stage.slot_depth_step = 0.05
	stage.slots = [Vector2(-0.8, 9.05), Vector2(0.8, 9.0)] as Array[Vector2]
	stage.background_blur_begin = 100.0
	assert_array(BattleFraming.depth_collisions(stage)).contains_exactly([Vector2i(0, 1)])
	stage.slots = [Vector2(-0.8, 9.0), Vector2(0.8, 9.0)] as Array[Vector2]
	assert_array(BattleFraming.depth_collisions(stage)).is_empty()
	assert_bool(_has_rule(BattleFraming.validate(stage, PresentationConfig.new()),
			BattleFraming.RULE_UNIQUE_DEPTH)).is_false()
