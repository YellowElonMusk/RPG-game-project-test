## Story 051, AC-47 (ADR-0005 §5, §9, §10): the project pins a 3D render
## scale of exactly 1.0 with no upscaler, HDR output off, screen-space AA and
## TAA off (MSAA 3D at 2x), and the Vulkan backend with both fallbacks off --
## set explicitly in `project.godot`, because both fallbacks default to true
## on 4.7.2 (the keys whose engine default is wrong -- MSAA 3D and the two
## fallbacks -- must be explicit in the file; keys equal to the engine default
## are checked by effective value, since the editor drops them on re-save). Every shipped lighting preset has glow bloom 0 and its own glow
## threshold.
extends GdUnitTestSuite

const _PROFILES_DIR := "res://data/presentation/profiles"


## `project.godot` as written (explicit keys only, never engine defaults).
func _project() -> ConfigFile:
	var cfg := ConfigFile.new()
	assert_int(cfg.load("res://project.godot")).is_equal(OK)
	return cfg


func _explicit(cfg: ConfigFile, key: String) -> Variant:
	var section: String = key.get_slice("/", 0)
	var rest: String = key.substr(section.length() + 1)
	assert_bool(cfg.has_section_key(section, rest)).override_failure_message(
			"project.godot must set %s explicitly" % key).is_true()
	return cfg.get_value(section, rest, null)


func test_render_scale_is_exactly_one_with_no_upscaler() -> void:
	assert_float(float(ProjectSettings.get_setting("rendering/scaling_3d/scale"))).is_equal(1.0)
	assert_int(int(ProjectSettings.get_setting("rendering/scaling_3d/mode"))) \
			.is_equal(Viewport.SCALING_3D_MODE_BILINEAR)


func test_hdr_output_is_off() -> void:
	assert_bool(bool(ProjectSettings.get_setting("display/window/hdr/request_hdr_output"))).is_false()


func test_screen_space_aa_and_taa_are_off_and_msaa_3d_is_2x() -> void:
	var cfg := _project()
	assert_int(int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/screen_space_aa"))) \
			.is_equal(Viewport.SCREEN_SPACE_AA_DISABLED)
	assert_bool(bool(ProjectSettings.get_setting("rendering/anti_aliasing/quality/use_taa"))).is_false()
	assert_int(int(_explicit(cfg, "rendering/anti_aliasing/quality/msaa_3d"))) \
			.is_equal(Viewport.MSAA_2X)


func test_backend_is_pinned_to_vulkan_with_both_fallbacks_off() -> void:
	var cfg := _project()
	assert_str(String(ProjectSettings.get_setting("rendering/rendering_device/driver.windows"))).is_equal("vulkan")
	assert_str(String(ProjectSettings.get_setting("rendering/rendering_device/driver.linuxbsd"))).is_equal("vulkan")
	assert_bool(bool(_explicit(cfg, "rendering/rendering_device/fallback_to_d3d12"))).is_false()
	assert_bool(bool(_explicit(cfg, "rendering/rendering_device/fallback_to_opengl3"))).is_false()
	assert_bool(bool(ProjectSettings.get_setting("rendering/rendering_device/fallback_to_d3d12"))).is_false()
	assert_bool(bool(ProjectSettings.get_setting("rendering/rendering_device/fallback_to_opengl3"))).is_false()


func test_every_preset_has_zero_glow_bloom_and_its_own_threshold() -> void:
	var ids: Array[String] = []
	for file_name: String in DirAccess.get_files_at(_PROFILES_DIR):
		if file_name.get_extension() == "tres":
			ids.append(file_name.get_basename())
	assert_array(ids).is_not_empty()
	for id: String in ids:
		var path: String = _PROFILES_DIR.path_join("%s.tres" % id)
		var profile := ResourceLoader.load(path) as LightingProfile
		assert_float(profile.glow_bloom).override_failure_message("%s: glow bloom" % id).is_equal(0.0)
		assert_float(profile.glow_threshold).override_failure_message("%s: glow threshold" % id) \
				.is_greater(0.0)
		# "Its own": authored in the preset file, not inherited from the script default.
		assert_bool(FileAccess.get_file_as_string(path).contains("glow_threshold =")) \
				.override_failure_message("%s: glow_threshold must be authored" % id).is_true()
