## Story 051, AC-47's world-shader lint (ADR-0005 §7: world shaders read
## `mode_time`, never `TIME`): it fails a shader file, a scene's embedded
## shader code and a visual shader's Time node under a mode-scene path, passes
## a UI shader outside `ModeHost` that reads `TIME`, ignores `TIME` in comments
## and inside longer identifiers, and finds nothing in the shipped project.
extends GdUnitTestSuite

const _FIXTURES := "res://tests/unit/presentation/fixtures/shader_lint"
const _MODE := _FIXTURES + "/mode"
const _UI := _FIXTURES + "/ui"


func _mode_roots() -> PackedStringArray:
	return PackedStringArray([_MODE])


func test_shader_file_reading_time_fails() -> void:
	var path := _MODE + "/time_shader.gdshader"
	assert_array(Array(WorldShaderTimeLint.lint(PackedStringArray([path]), _mode_roots()))) \
			.has_size(1)


func test_scene_with_embedded_shader_reading_time_fails() -> void:
	var path := _MODE + "/embedded_time.tscn"
	assert_array(Array(WorldShaderTimeLint.lint(PackedStringArray([path]), _mode_roots()))) \
			.has_size(1)


func test_visual_shader_with_a_time_node_fails() -> void:
	var path := _MODE + "/visual_time.tres"
	assert_array(Array(WorldShaderTimeLint.lint(PackedStringArray([path]), _mode_roots()))) \
			.has_size(1)


func test_mode_time_shader_with_time_in_comments_passes() -> void:
	var path := _MODE + "/clean_mode_time.gdshader"
	assert_array(Array(WorldShaderTimeLint.lint(PackedStringArray([path]), _mode_roots()))) \
			.is_empty()


func test_ui_shader_outside_mode_host_reading_time_passes() -> void:
	var path := _UI + "/ui_time.gdshader"
	# It does read TIME -- the pass is because of where it lives.
	assert_bool(WorldShaderTimeLint.code_reads_time(FileAccess.get_file_as_string(path))).is_true()
	assert_array(Array(WorldShaderTimeLint.lint(PackedStringArray([path]), _mode_roots()))) \
			.is_empty()


func test_walking_the_fixture_tree_flags_exactly_the_three_mode_fixtures() -> void:
	var files: PackedStringArray = WorldShaderTimeLint.collect_files(_FIXTURES)
	var errors: PackedStringArray = WorldShaderTimeLint.lint(files, _mode_roots())
	assert_array(Array(errors)).has_size(3)
	for name: String in ["time_shader.gdshader", "embedded_time.tscn", "visual_time.tres"]:
		assert_bool(" ".join(errors).contains(name)).override_failure_message(name).is_true()


func test_shipped_project_has_no_world_shader_reading_time() -> void:
	var errors: PackedStringArray = WorldShaderTimeLint.lint_project()
	assert_array(Array(errors)).override_failure_message(", ".join(errors)).is_empty()
	# The production scan does cover the mode scenes and the actor shader.
	var files: PackedStringArray = WorldShaderTimeLint.project_mode_files()
	assert_bool(files.has("res://src/presentation/shaders/sprite_actor.gdshader")).is_true()
	assert_bool(files.has("res://src/battle/battle_mode.tscn")).is_true()
