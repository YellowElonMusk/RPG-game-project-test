## Story 024, AC-21 (TR-content-008; GDD F4 "Error-screen display count",
## UI Requirements): with 30 errors and the default ERROR_SCREEN_CAP of 20,
## the error-screen text holds exactly the first 20 in report order and the
## log path; the log text holds all 30. Record ids are zero-padded
## (char_err_01..char_err_30), load-bearing per the story's QA notes: an
## unpadded "char_err_1" would be a substring of "char_err_10".
extends GdUnitTestSuite

const LOG_PATH := "user://content_errors.log"


## 30 synthetic error entries, char_err_01..char_err_30, in report order.
func _thirty_errors() -> Array[Dictionary]:
	var report: Array[Dictionary] = []
	for i: int in range(1, 31):
		var record_id: String = "char_err_%02d" % i
		report.append({
			"severity": &"error", "record_id": record_id, "field": "display_name",
			"location": {"file_path": "res://data/characters/%s.tres" % record_id, "record_index": 0},
			"message": "m", "related_locations": [],
		})
	return report


## T1: the screen text holds exactly the first 20 errors (01-20), not 21-30,
## with the log path appearing after the last entry.
func test_error_screen_text_holds_first_cap_errors_and_log_path() -> void:
	var text: String = ValidationReportText.build_error_screen_text(_thirty_errors(), 20, LOG_PATH)
	var lines: PackedStringArray = text.split("\n")

	for i: int in range(1, 21):
		var record_id: String = "char_err_%02d" % i
		var matches: int = 0
		for line: String in lines:
			if line.contains(record_id):
				matches += 1
		assert_int(matches).override_failure_message(
				"%s missing or duplicated in:\n%s" % [record_id, text]).is_equal(1)
	for i: int in range(21, 31):
		var record_id: String = "char_err_%02d" % i
		assert_bool(text.contains(record_id)).override_failure_message(
				"%s should not appear:\n%s" % [record_id, text]).is_false()
	assert_str(lines[lines.size() - 1]).contains(LOG_PATH)


## T2: the log holds all 30, in order.
func test_log_text_holds_all_entries() -> void:
	var text: String = ValidationReportText.build_log_text(_thirty_errors())

	for i: int in range(1, 31):
		assert_bool(text.contains("char_err_%02d" % i)).is_true()
	var last_index: int = text.find("char_err_29")
	var only_index: int = text.find("char_err_30")
	assert_bool(last_index < only_index).override_failure_message(
			"char_err_29 should appear before char_err_30:\n%s" % text).is_true()


## Edge case: with 5 errors and a cap of 20, all 5 are listed.
func test_fewer_errors_than_cap_lists_all_of_them() -> void:
	var report: Array[Dictionary] = _thirty_errors().slice(0, 5)

	var text: String = ValidationReportText.build_error_screen_text(report, 20, LOG_PATH)

	for i: int in range(1, 6):
		assert_bool(text.contains("char_err_%02d" % i)).is_true()


## Edge case: a warning is not counted toward the cap and is not shown on
## the screen.
func test_warning_not_counted_toward_cap_or_shown_on_screen() -> void:
	var report: Array[Dictionary] = _thirty_errors().slice(0, 2)
	report.append({
		"severity": &"warning", "record_id": "char_warn", "field": "x",
		"location": {"file_path": "res://data/characters/char_warn.tres", "record_index": 0},
		"message": "m", "related_locations": [],
	})

	var text: String = ValidationReportText.build_error_screen_text(report, 20, LOG_PATH)

	assert_bool(text.contains("char_warn")).is_false()
	assert_bool(text.contains("char_err_01")).is_true()
	assert_bool(text.contains("char_err_02")).is_true()


## The warning is included in the log text, unlike the screen text.
func test_warning_appears_in_log_text() -> void:
	var report: Array[Dictionary] = [{
		"severity": &"warning", "record_id": "char_warn", "field": "x",
		"location": {"file_path": "res://data/characters/char_warn.tres", "record_index": 0},
		"message": "m", "related_locations": [],
	}]

	var text: String = ValidationReportText.build_log_text(report)

	assert_bool(text.contains("char_warn")).is_true()


## An empty report: the screen text is only the log-path line; the log is empty.
func test_empty_report_gives_log_path_only_and_empty_log() -> void:
	var empty: Array[Dictionary] = []

	assert_str(ValidationReportText.build_error_screen_text(empty, 20, LOG_PATH)).is_equal("Full log: %s" % LOG_PATH)
	assert_str(ValidationReportText.build_log_text(empty)).is_equal("")


## A report of only warnings: the screen shows no entry line, only the log path.
func test_only_warnings_report_shows_log_path_only_on_screen() -> void:
	var report: Array[Dictionary] = [{
		"severity": &"warning", "record_id": "char_warn", "field": "x",
		"location": {"file_path": "res://data/characters/char_warn.tres", "record_index": 0},
		"message": "m", "related_locations": [],
	}]

	assert_str(ValidationReportText.build_error_screen_text(report, 20, LOG_PATH)).is_equal("Full log: %s" % LOG_PATH)


## The 10-50 clamp holds for values loaded from a real .tres file, not only
## for in-memory assignment: the setter runs during deserialisation.
func test_config_cap_out_of_range_in_file_is_clamped_on_load() -> void:
	var root := "res://tests/unit/content_data/fixtures/report_config"

	assert_int(ContentReportConfig.load_or_default(root + "/cap_low.tres").error_screen_cap).is_equal(10)
	assert_int(ContentReportConfig.load_or_default(root + "/cap_high.tres").error_screen_cap).is_equal(50)


## A missing config file falls back to the default cap of 20.
func test_config_missing_file_falls_back_to_default() -> void:
	var config := ContentReportConfig.load_or_default("res://tests/unit/content_data/fixtures/report_config/missing.tres")

	assert_int(config.error_screen_cap).is_equal(20)


## Config default: the project ships with ERROR_SCREEN_CAP = 20.
func test_config_default_error_screen_cap_is_20() -> void:
	assert_int(ContentReportConfig.load_or_default().error_screen_cap).is_equal(20)
