## Story 009 (ADR-0001 Migration Step 5; Validation Criteria 2): proves
## `CharacterizationBaseline.diff()` passes only on an exactly-unchanged
## gated set, and fails closed on a missing or unparsable manifest. Named
## `battle_characterization_gate_test.gd`, not `*_characterization_test.gd`,
## so it sits outside its own gated set (deliberate, per this story's own
## Implementation Notes). Its fixtures are temp copies under `user://`,
## created in `before_test()` and removed in `after_test()` -- never the
## real `tests/unit/battle/` tree, so this test can edit/add/delete "gated"
## files freely without touching anything else.
extends GdUnitTestSuite

var _temp_root: String
var _manifest_path: String


## One fixed sandbox path, cleared before and after every test, so a test that
## dies before `after_test()` leaves nothing behind for long: the next run's
## `before_test()` removes it first.
const _SANDBOX: String = "user://characterization_gate_test"


func before_test() -> void:
	_temp_root = _SANDBOX
	_remove_recursive(_temp_root)
	DirAccess.make_dir_recursive_absolute(_temp_root.path_join("tests/unit/battle/fixtures"))
	_write("tests/unit/battle/fixtures/characterization_expected.gd", "const A = 1\n")
	_write("tests/unit/battle/fixtures/scripted_fight_commands.gd", "const B = 2\n")
	_write("tests/unit/battle/example_characterization_test.gd", "extends GdUnitTestSuite\n")
	_manifest_path = _temp_root.path_join("baseline.sha256")


func after_test() -> void:
	_remove_recursive(_temp_root)


func _write(rel_path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(_temp_root.path_join(rel_path), FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _write_manifest_for_current_state() -> void:
	var file: FileAccess = FileAccess.open(_manifest_path, FileAccess.WRITE)
	file.store_string(CharacterizationBaseline.build_manifest(_temp_root))
	file.close()


func _remove_recursive(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = path.path_join(entry)
		if dir.current_is_dir():
			_remove_recursive(full)
		else:
			DirAccess.remove_absolute(full)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


# --- Test: unchanged passes ---

func test_unchanged_passes() -> void:
	_write_manifest_for_current_state()

	var offending: PackedStringArray = CharacterizationBaseline.diff(_manifest_path, _temp_root)

	assert_int(offending.size()).override_failure_message("offending: %s" % [offending]).is_equal(0)


# --- Test: one byte changed fails ---

func test_one_byte_changed_fails() -> void:
	_write_manifest_for_current_state()
	_write("tests/unit/battle/fixtures/characterization_expected.gd", "const A = 2\n")

	var offending: PackedStringArray = CharacterizationBaseline.diff(_manifest_path, _temp_root)

	assert_bool(offending.has("tests/unit/battle/fixtures/characterization_expected.gd")).override_failure_message(
			"offending: %s" % [offending]).is_true()


# --- Test: added or deleted file fails ---

func test_added_file_fails() -> void:
	_write_manifest_for_current_state()
	_write("tests/unit/battle/new_characterization_test.gd", "extends GdUnitTestSuite\n")

	var offending: PackedStringArray = CharacterizationBaseline.diff(_manifest_path, _temp_root)

	assert_bool(offending.has("tests/unit/battle/new_characterization_test.gd")).override_failure_message(
			"offending: %s" % [offending]).is_true()


func test_deleted_file_fails() -> void:
	_write_manifest_for_current_state()
	DirAccess.remove_absolute(_temp_root.path_join("tests/unit/battle/example_characterization_test.gd"))

	var offending: PackedStringArray = CharacterizationBaseline.diff(_manifest_path, _temp_root)

	assert_bool(offending.has("tests/unit/battle/example_characterization_test.gd")).override_failure_message(
			"offending: %s" % [offending]).is_true()


# --- Test: missing manifest fails closed ---

func test_missing_manifest_fails_closed() -> void:
	var offending: PackedStringArray = CharacterizationBaseline.diff(
			_temp_root.path_join("does_not_exist.sha256"), _temp_root)

	assert_int(offending.size()).override_failure_message("a missing manifest must fail closed").is_greater(0)


func test_unparsable_manifest_fails_closed() -> void:
	var file: FileAccess = FileAccess.open(_manifest_path, FileAccess.WRITE)
	file.store_string("not a valid manifest\n")
	file.close()

	var offending: PackedStringArray = CharacterizationBaseline.diff(_manifest_path, _temp_root)

	assert_int(offending.size()).override_failure_message("an unparsable manifest must fail closed").is_greater(0)


# --- Edge case: line-ending normalisation ---

func test_gitattributes_pins_lf_for_the_gated_paths() -> void:
	var content: String = FileAccess.get_file_as_string("res://.gitattributes")
	assert_str(content).contains("tests/unit/battle/*_characterization_test.gd text eol=lf")
	assert_str(content).contains("tests/unit/battle/fixtures/characterization_expected.gd text eol=lf")
	assert_str(content).contains("tests/unit/battle/fixtures/scripted_fight_commands.gd text eol=lf")


# --- The stated exclusions ---

## The seam lives in `helpers/` (a subdirectory, never scanned) and the gate
## test's own name ends in `_gate_test.gd`, not `_characterization_test.gd`:
## both stay out of the gated set even when present in the scanned tree.
func test_seam_and_gate_test_are_excluded_from_the_gated_set() -> void:
	DirAccess.make_dir_recursive_absolute(_temp_root.path_join("tests/unit/battle/helpers"))
	_write("tests/unit/battle/helpers/battle_content_seam.gd", "class_name X\n")
	_write("tests/unit/battle/battle_characterization_gate_test.gd", "extends GdUnitTestSuite\n")

	var gated: PackedStringArray = CharacterizationBaseline.gated_paths(_temp_root)

	assert_bool(gated.has("tests/unit/battle/helpers/battle_content_seam.gd")).override_failure_message(
			"gated: %s" % [gated]).is_false()
	assert_bool(gated.has("tests/unit/battle/battle_characterization_gate_test.gd")).override_failure_message(
			"gated: %s" % [gated]).is_false()
	assert_int(gated.size()).override_failure_message("gated: %s" % [gated]).is_equal(3)


# --- The checker's own exit code, as a child process ---

## Runs the real headless checker against `manifest`/`root` (absolute paths,
## so the child process resolves the same files) and returns
## `{"exit": int, "output": String}`.
func _run_checker(manifest: String, root: String) -> Dictionary:
	var output: Array = []
	var exit_code: int = OS.execute(OS.get_executable_path(), [
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"-s", "res://tools/ci/check_characterization_unchanged.gd", "--",
		"--manifest=%s" % ProjectSettings.globalize_path(manifest),
		"--root=%s" % ProjectSettings.globalize_path(root),
	], output, true)
	return {"exit": exit_code, "output": "\n".join(output)}


func test_checker_exits_one_and_names_the_file_on_drift() -> void:
	_write_manifest_for_current_state()
	_write("tests/unit/battle/fixtures/characterization_expected.gd", "const A = 2\n")

	var result: Dictionary = _run_checker(_manifest_path, _temp_root)

	assert_int(result["exit"]).override_failure_message("output: %s" % result["output"]).is_equal(1)
	assert_str(result["output"]).contains("tests/unit/battle/fixtures/characterization_expected.gd")


func test_checker_exits_one_on_a_missing_manifest() -> void:
	var result: Dictionary = _run_checker(_temp_root.path_join("does_not_exist.sha256"), _temp_root)

	assert_int(result["exit"]).override_failure_message("output: %s" % result["output"]).is_equal(1)


func test_checker_exits_one_on_an_unparsable_manifest() -> void:
	var file: FileAccess = FileAccess.open(_manifest_path, FileAccess.WRITE)
	file.store_string("not a valid manifest\n")
	file.close()

	var result: Dictionary = _run_checker(_manifest_path, _temp_root)

	assert_int(result["exit"]).override_failure_message("output: %s" % result["output"]).is_equal(1)


func test_checker_exits_zero_on_an_unchanged_sandbox() -> void:
	_write_manifest_for_current_state()

	var result: Dictionary = _run_checker(_manifest_path, _temp_root)

	assert_int(result["exit"]).override_failure_message("output: %s" % result["output"]).is_equal(0)


# --- Integration: the real checker, as a child process, against the real repo ---

## Runs the actual headless checker against the real, checked-in manifest and
## the real `tests/unit/battle/` tree -- the same command CI runs. Exercises
## the SceneTree wrapper's own argument parsing and exit code, not just
## `CharacterizationBaseline.diff()` directly.
func test_checker_exits_zero_against_the_real_checked_in_manifest() -> void:
	var output: Array = []
	var exit_code: int = OS.execute(OS.get_executable_path(), [
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"-s", "res://tools/ci/check_characterization_unchanged.gd",
	], output, true)

	assert_int(exit_code).override_failure_message("output: %s" % [output]).is_equal(0)
