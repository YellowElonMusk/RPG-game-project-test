## Content-migration story 021 (ADR-0001 Validation Criteria 1; TR-content-011):
## every record migrated by stories 013-018 validates clean. Runs
## `tools/ci/validate-content.gd` against `res://data` as a real child process
## (the pinned subprocess call), so the check is the same one CI runs. The
## registrants are whatever `ContentBootstrap.run()` registers today; stories
## 012 and 020 (the Stats validators) are still blocked, so see this story's
## Completion Notes for the gap.
extends GdUnitTestSuite

const _SCRIPT_PATH: String = "res://tools/ci/validate-content.gd"
const _DATA_ROOT: String = "res://data"
const _EXPECTED_WARNINGS: String = "res://tests/integration/battle/fixtures/expected_migrated_warnings.txt"
## Scratch root for the deliberately broken copy (watch the gate fail).
const _BROKEN_ROOT: String = "user://story_021_broken_data"
const _BROKEN_RECORD: String = "enemies/enemy_clerk.tres"
## The reference the broken copy points at instead of a real move. The
## story's own example (Clerk `max_hp 1000`) is not caught yet: that range
## check is a Stats validator, owned by blocked story 012.
const _MISSING_MOVE_ID: String = "move_story_021_does_not_exist"


func after_test() -> void:
	_remove_tree(_BROKEN_ROOT)


func test_migrated_set_validates_clean() -> void:
	# Act
	var result: Dictionary = _run_validate(_DATA_ROOT)

	# Assert: exit 0, so the report holds no error. Every printed entry line
	# is therefore a warning, and the ones naming a migrated record must
	# equal the expected list exactly.
	assert_int(result["exit_code"]).override_failure_message(
			"validate-content on res://data failed:\n%s" % result["output"]).is_equal(0)
	assert_array(_entry_keys(result["output"])).override_failure_message(
			"warnings naming migrated records differ from %s:\n%s" % [
				_EXPECTED_WARNINGS, result["output"]]) \
			.contains_exactly_in_any_order(_expected_keys())


func test_broken_copy_fails_the_gate() -> void:
	# Arrange: a copy of res://data where the Clerk references a move that
	# does not exist.
	_copy_tree(_DATA_ROOT, _BROKEN_ROOT)
	var clerk_path: String = _BROKEN_ROOT.path_join(_BROKEN_RECORD)
	var text: String = FileAccess.get_file_as_string(clerk_path)
	assert_bool(text.contains("\"move_pen_jab\"")).override_failure_message(
			"the Clerk record no longer references move_pen_jab; update this test's mutation").is_true()
	var file := FileAccess.open(clerk_path, FileAccess.WRITE)
	file.store_string(text.replace("\"move_pen_jab\"", "\"%s\"" % _MISSING_MOVE_ID))
	file.close()

	# Act
	var result: Dictionary = _run_validate(_BROKEN_ROOT)

	# Assert: the gate fails, and names the broken record and field.
	assert_int(result["exit_code"]).override_failure_message(
			"a broken reference did not fail validate-content:\n%s" % result["output"]).is_equal(1)
	assert_str(result["output"] as String).contains("enemy_clerk | move_ids")


## The pinned subprocess call (story 021 Implementation Notes). Output is
## CRLF-normalised: on Windows the child prints CRLF.
func _run_validate(data_root: String) -> Dictionary:
	var output: Array = []
	var exit_code: int = OS.execute(OS.get_executable_path(), [
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"-s", _SCRIPT_PATH, "--", "--data-root=%s" % data_root,
	], output, true)
	return {"exit_code": exit_code, "output": "\n".join(output).replace("\r\n", "\n")}


## "record_id | field" for every report entry line in `output`. Entry lines
## are `record_id | field | file_path: message`
## (`ValidationReportText.build_log_text`); engine noise has no ` | `.
func _entry_keys(output: String) -> Array[String]:
	var keys: Array[String] = []
	for line: String in output.split("\n"):
		var parts: PackedStringArray = line.split(" | ")
		if parts.size() >= 3:
			keys.append(("%s | %s" % [parts[0].strip_edges(), parts[1].strip_edges()]).strip_edges())
	return keys


func _expected_keys() -> Array[String]:
	var keys: Array[String] = []
	for line: String in FileAccess.get_file_as_string(_EXPECTED_WARNINGS).split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		keys.append(trimmed)
	return keys


func _copy_tree(from_dir: String, to_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(to_dir)
	for file_name: String in DirAccess.get_files_at(from_dir):
		DirAccess.copy_absolute(from_dir.path_join(file_name), to_dir.path_join(file_name))
	for sub: String in DirAccess.get_directories_at(from_dir):
		_copy_tree(from_dir.path_join(sub), to_dir.path_join(sub))


func _remove_tree(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for file_name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file_name))
	for sub: String in DirAccess.get_directories_at(dir):
		_remove_tree(dir.path_join(sub))
	DirAccess.remove_absolute(dir)
