## Story 027, AC-24 (TR-content-003; ADR-0001 "Standalone headless
## validation", amendment 2026-10-23; ADR-0004 §5): the headless validation
## check (`tools/ci/validate-content.gd`) exits 0 on valid data with warnings
## allowed, and 1 with the full report on any error. Runs the script as a
## real child process (the settled harness, per the story's Implementation
## Notes) so the test exercises the actual `godot --headless -s` entry point,
## not just its logic in-process.
extends GdUnitTestSuite

const SCRIPT_PATH := "res://tools/ci/validate-content.gd"
const PROJECT_PATH := "res://"


## Runs validate-content.gd with `--data-root=<fixture_root>` as a child
## process. Returns {exit_code, output} (output joined with newlines).
func _run_validate(fixture_root: String) -> Dictionary:
	var output: Array = []
	var exit_code: int = OS.execute(OS.get_executable_path(), [
		"--headless", "--path", ProjectSettings.globalize_path(PROJECT_PATH),
		"-s", SCRIPT_PATH, "--", "--data-root=%s" % fixture_root,
	], output, true)
	return {"exit_code": exit_code, "output": "\n".join(output)}


## T1: valid data with a warning exits 0, and the warning's record_id reaches stdout.
func test_warnings_only_data_exits_zero_and_prints_the_warning() -> void:
	var result: Dictionary = _run_validate("res://tests/integration/content_data/fixtures/warnings_only")

	assert_int(result["exit_code"]).override_failure_message(
			"output:\n%s" % result["output"]).is_equal(0)
	assert_str(result["output"] as String).contains("quirk_orphan_ci")


## T2: two independent errors exits 1 (not 2), and both record_ids reach stdout.
func test_two_errors_exits_one_and_prints_both_entries() -> void:
	var result: Dictionary = _run_validate("res://tests/integration/content_data/fixtures/two_errors")

	assert_int(result["exit_code"]).override_failure_message(
			"output:\n%s" % result["output"]).is_equal(1)
	var output: String = result["output"]
	assert_str(output).contains("Char_Bad_CI")
	assert_str(output).contains("char_unknown_ci")


## Edge case: a missing --data-root exits 1 with a line naming the path.
func test_missing_data_root_exits_one_naming_the_path() -> void:
	var result: Dictionary = _run_validate("res://does/not/exist")

	assert_int(result["exit_code"]).is_equal(1)
	assert_str(result["output"] as String).contains("res://does/not/exist")


## Edge case: a clean, fully valid data set exits 0 with no error reported.
func test_clean_data_set_exits_zero() -> void:
	var result: Dictionary = _run_validate("res://tests/unit/content_data/fixtures/valid_one_of_each")

	assert_int(result["exit_code"]).override_failure_message(
			"output:\n%s" % result["output"]).is_equal(0)
