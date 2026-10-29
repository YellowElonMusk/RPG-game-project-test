## Story 003, AC-1: across every shipped lighting preset, `DioramaStage`'s
## key light culls to actors only (no shadow), its set and fill lights cull
## to the set only (set light the only shadow caster), the stage's ambient
## stays at 0, and the profile's own rim strength is above 0. Every
## `boss_<faction>` preset's actor key and rim colors equal `battle`'s
## (ADR-0005 Decision §3, §5). Presets are discovered with
## `DirAccess.get_files_at()`, not a hardcoded list, so a new shipped `.tres`
## is covered with no test change (the story's Files list: "the test
## iterates every shipped preset file").
extends GdUnitTestSuite

const DioramaStage := preload("res://src/presentation/diorama_stage.gd")
const LightingProfile := preload("res://src/presentation/lighting_profile.gd")

const _PROFILES_DIR := "res://data/presentation/profiles"
const _BATTLE_ID := "battle"


## Every shipped preset's base ID (file name without the `.tres` extension),
## read straight off disk.
func _profile_ids() -> Array[String]:
	var ids: Array[String] = []
	for file_name: String in DirAccess.get_files_at(_PROFILES_DIR):
		if file_name.get_extension() == "tres":
			ids.append(file_name.get_basename())
	return ids


func _load_profile(id: String) -> LightingProfile:
	var path: String = _PROFILES_DIR.path_join("%s.tres" % id)
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as LightingProfile


## A `DioramaStage` with its light rig wired up, matching how a mode scene
## authors it (ADR-0005 §3): `_ready()` runs the fixed cull-mask/shadow/
## ambient setup, same as it would after the stage scene is instanced.
func _build_stage() -> DioramaStage:
	var stage: DioramaStage = auto_free(DioramaStage.new())
	stage.key_light = DirectionalLight3D.new()
	stage.set_light = DirectionalLight3D.new()
	stage.fill_light = DirectionalLight3D.new()
	stage.world_environment = WorldEnvironment.new()
	stage.world_environment.environment = Environment.new()
	stage.add_child(stage.key_light)
	stage.add_child(stage.set_light)
	stage.add_child(stage.fill_light)
	stage.add_child(stage.world_environment)
	stage._ready()
	return stage


func test_every_shipped_preset_lights_actors_and_set_separately_with_no_ambient() -> void:
	var ids: Array[String] = _profile_ids()
	assert_array(ids).override_failure_message(
			"data/presentation/profiles must ship at least one preset").is_not_empty()

	for id: String in ids:
		var stage: DioramaStage = _build_stage()
		var profile: LightingProfile = _load_profile(id)
		assert_object(profile).override_failure_message(
				"failed to load preset '%s'" % id).is_not_null()

		stage.bind_profiles(func(_lookup_id: StringName) -> LightingProfile: return profile)
		stage.request_profile(StringName(id), 0.0)

		assert_int(stage.key_light.light_cull_mask).override_failure_message(
				"'%s': key light must cull to ACTORS only" % id).is_equal(DioramaStage.LAYER_ACTORS)
		assert_bool(stage.key_light.shadow_enabled).override_failure_message(
				"'%s': key light must not cast shadows" % id).is_false()

		assert_int(stage.set_light.light_cull_mask).override_failure_message(
				"'%s': set light must cull to SET only" % id).is_equal(DioramaStage.LAYER_SET)
		assert_bool(stage.set_light.shadow_enabled).override_failure_message(
				"'%s': set light must be the scene's shadow caster" % id).is_true()

		assert_int(stage.fill_light.light_cull_mask).override_failure_message(
				"'%s': fill light must cull to SET only" % id).is_equal(DioramaStage.LAYER_SET)
		assert_bool(stage.fill_light.shadow_enabled).override_failure_message(
				"'%s': fill light must not cast shadows" % id).is_false()

		assert_float(stage.world_environment.environment.ambient_light_energy).override_failure_message(
				"'%s': stage ambient must stay at 0 -- actors take no ambient" % id).is_equal(0.0)

		assert_float(profile.rim_strength).override_failure_message(
				"'%s': rim strength must be above 0" % id).is_greater(0.0)


func test_every_boss_preset_actor_key_and_rim_equal_battle() -> void:
	var battle: LightingProfile = _load_profile(_BATTLE_ID)
	assert_object(battle).override_failure_message("failed to load 'battle'").is_not_null()

	var boss_ids: Array[String] = _profile_ids().filter(
			func(id: String) -> bool: return id.begins_with("boss_"))
	assert_array(boss_ids).override_failure_message(
			"no boss_<faction> preset shipped").is_not_empty()

	for id: String in boss_ids:
		var profile: LightingProfile = _load_profile(id)

		assert_bool(profile.key_color.is_equal_approx(battle.key_color)).override_failure_message(
				"'%s': actor key color must equal battle's" % id).is_true()
		assert_bool(profile.rim_color.is_equal_approx(battle.rim_color)).override_failure_message(
				"'%s': actor rim color must equal battle's" % id).is_true()
