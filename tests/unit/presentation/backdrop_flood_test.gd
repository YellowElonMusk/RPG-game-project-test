## Story 038 (GDD AC-34 "the flooded sky"): the battle backdrop is a 2D
## painting, so the boss takeover's dusk never reached the screen. The stage
## now writes the blended sky to the backdrop's flood shader; only the
## `boss_<faction>` profiles flood it.
extends GdUnitTestSuite

const PROFILES_DIR: String = "res://data/presentation/profiles/"


func _profile(id: String) -> LightingProfile:
	return load(PROFILES_DIR + id + ".tres") as LightingProfile


func test_only_boss_profiles_flood_the_sky() -> void:
	for id: String in PipelineWarmup.profile_ids(PROFILES_DIR):
		var flood: float = _profile(id).sky_flood
		if id.begins_with("boss_"):
			assert_float(flood).override_failure_message("%s does not flood the sky" % id).is_greater(0.0)
		else:
			assert_float(flood).override_failure_message("%s floods the painting" % id).is_equal(0.0)


func test_stage_writes_the_blended_sky_to_the_backdrop() -> void:
	var stage: DioramaStage = auto_free(DioramaStage.new())
	var backdrop: TextureRect = auto_free(TextureRect.new())
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/presentation/shaders/backdrop_flood.gdshader")
	backdrop.material = mat
	stage.backdrop = backdrop
	var boss: LightingProfile = _profile("boss_bureaucratia")
	stage.apply_profile(boss, 0.0)
	assert_float(float(mat.get_shader_parameter(&"flood"))).is_equal_approx(boss.sky_flood, 0.0001)
	assert_that(mat.get_shader_parameter(&"sky_horizon")).is_equal(boss.sky_horizon)
	stage.apply_profile(_profile("battle"), 0.0)
	assert_float(float(mat.get_shader_parameter(&"flood"))).is_equal(0.0)


func test_battle_scene_backdrop_carries_the_flood_material() -> void:
	var mode: Node = auto_free((load("res://src/battle/battle_mode.tscn") as PackedScene).instantiate())
	var stage: DioramaStage = mode.get_node(^"%DioramaStage")
	assert_object(stage.backdrop).is_not_null()
	assert_object(stage.backdrop.material as ShaderMaterial).override_failure_message(
			"the battle backdrop has no flood material").is_not_null()
