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


# --- Story 019, AC-16: squad rim and outline constant; faction color audit ---

const _FACTIONS_DIR := "res://data/factions"
const _SHADER_PATH := "res://src/presentation/shaders/sprite_actor.gdshader"


## Every shipped alien faction's signature color, by faction id.
func _signature_colors() -> Dictionary:
	var colors: Dictionary = {}
	for file_name: String in DirAccess.get_files_at(_FACTIONS_DIR):
		if file_name.get_extension() != "tres":
			continue
		var faction: Resource = ResourceLoader.load(_FACTIONS_DIR.path_join(file_name))
		if faction == null or String(faction.get("signature_color")).is_empty():
			continue
		colors[String(faction.get("id"))] = Color(String(faction.get("signature_color")))
	return colors


func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= 1e-4 and absf(a.g - b.g) <= 1e-4 and absf(a.b - b.b) <= 1e-4


func test_every_preset_rim_color_equals_the_config_squad_rim() -> void:
	var config := PresentationConfig.new()
	for id: String in _profile_ids():
		var errors: PackedStringArray = LightingProfile.squad_look_errors(
				id, _load_profile(id), config)
		assert_array(Array(errors)).override_failure_message(
				"squad rim must be constant: %s" % ", ".join(errors)).is_empty()


func test_squad_rim_stays_constant_through_every_blend() -> void:
	var config := PresentationConfig.new()
	var ids: Array[String] = _profile_ids()
	for from_id: String in ids:
		for to_id: String in ids:
			for p: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
				var blended: LightingProfile = DioramaStage.lighting_blend(
						_load_profile(from_id), _load_profile(to_id), p)
				assert_bool(_close(blended.rim_color, config.squad_rim_color)) \
						.override_failure_message("%s -> %s at p %.2f: rim %s != squad %s" % [
							from_id, to_id, p, blended.rim_color, config.squad_rim_color]) \
						.is_true()


func test_stage_applies_the_squad_rim_in_every_state() -> void:
	var config := PresentationConfig.new()
	for id: String in _profile_ids():
		var stage: DioramaStage = _build_stage()
		stage.apply_profile(_load_profile(id), 0.0)
		assert_bool(_close(stage.current_rim_color, config.squad_rim_color)) \
				.override_failure_message("'%s': stage rim %s" % [id, stage.current_rim_color]).is_true()


## The rendered rim before any Director write is the project's shader-global
## default; it must be the squad rim too.
func test_project_rim_global_default_equals_the_squad_rim() -> void:
	var setting: Variant = ProjectSettings.get_setting("shader_globals/actor_rim_color")
	assert_bool(setting is Dictionary).is_true()
	var value: Color = (setting as Dictionary)["value"]
	assert_bool(_close(value, PresentationConfig.new().squad_rim_color)) \
			.override_failure_message("project actor_rim_color %s" % value).is_true()


## The actor shader's Outline Ink constant is the config's (it never varies by
## preset: no profile has an outline field).
func test_actor_shader_outline_ink_equals_the_config() -> void:
	var source: String = FileAccess.get_file_as_string(_SHADER_PATH)
	var regex := RegEx.create_from_string(
			r"const vec3 OUTLINE_INK = vec3\(([0-9.]+), ([0-9.]+), ([0-9.]+)\) / 255\.0")
	var found: RegExMatch = regex.search(source)
	assert_object(found).override_failure_message("OUTLINE_INK constant not found").is_not_null()
	var ink := Color(float(found.get_string(1)) / 255.0, float(found.get_string(2)) / 255.0,
			float(found.get_string(3)) / 255.0)
	assert_bool(_close(ink, PresentationConfig.new().outline_ink)).is_true()
	for prop: Dictionary in LightingProfile.new().get_property_list():
		assert_bool(String(prop["name"]).contains("outline")).override_failure_message(
				"LightingProfile must not carry an outline field").is_false()


func test_no_neutral_light_or_any_shadow_near_a_faction_signature_color() -> void:
	var config := PresentationConfig.new()
	var signatures: Dictionary = _signature_colors()
	assert_int(signatures.size()).override_failure_message(
			"no faction signature colors shipped").is_greater_equal(1)
	for id: String in _profile_ids():
		var errors: PackedStringArray = LightingProfile.faction_color_errors(
				id, _load_profile(id), signatures, config)
		assert_array(Array(errors)).override_failure_message(", ".join(errors)).is_empty()


## The audit itself bites: a neutral preset lit in a faction's own color, or a
## boss preset with a faction-colored shadow, fails; a boss preset's faction
## light passes.
func test_faction_audit_flags_neutral_faction_light_and_faction_shadow() -> void:
	var config := PresentationConfig.new()
	var signature := Color("#d23a2e")
	var signatures: Dictionary = {"faction_x": signature}
	var tinted := LightingProfile.new()
	tinted.fill_color = signature
	assert_int(LightingProfile.faction_color_errors("battle", tinted, signatures, config).size()) \
			.is_equal(1)
	assert_int(LightingProfile.faction_color_errors("boss_x", tinted, signatures, config).size()) \
			.is_equal(0)
	assert_int(LightingProfile.faction_color_errors("occupied_x", tinted, signatures, config).size()) \
			.is_equal(0)
	var shadowed := LightingProfile.new()
	shadowed.shadow_color = signature
	assert_int(LightingProfile.faction_color_errors("boss_x", shadowed, signatures, config).size()) \
			.is_equal(1)
	var off_rim := LightingProfile.new()
	off_rim.rim_color = Color(0.2, 0.4, 0.9)
	assert_int(LightingProfile.squad_look_errors("camp", off_rim, config).size()).is_equal(1)
