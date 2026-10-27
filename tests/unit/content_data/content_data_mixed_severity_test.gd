## Story 020, AC-19 (TR-content-003; ADR-0001 F3 "validation_outcome"): two
## errors and two warnings coexist in one report, with neither suppressing nor
## duplicating the other, and the catalog is FAILED because of the errors,
## never because of the warnings. Every record in the fixture is a root type
## or is referenced, so the report holds exactly these four entries. Builds a
## fresh ContentCatalogService (never the autoload).
extends GdUnitTestSuite

const ROOT := "res://tests/unit/content_data/fixtures/mixed_severity"

var _catalog: ContentCatalogService


func before_test() -> void:
	_catalog = auto_free(ContentCatalogService.new())


## The report's (severity, record_id, field) tuples, as Strings, for order-free comparison.
func _tuples() -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in _catalog.report:
		out.append("%s|%s|%s" % [entry["severity"], entry["record_id"], entry["field"]])
	return out


## Two errors and two warnings: FAILED, exactly 4 entries, 2 errors, 2
## warnings, and the four exact tuples the story specifies.
func test_two_errors_and_two_warnings_coexist_in_one_report() -> void:
	var result: Error = _catalog.load_all(ROOT)

	assert_int(result).is_equal(FAILED)
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.FAILED)
	assert_int(_catalog.report.size()).override_failure_message(
			"report: %s" % [_catalog.report]).is_equal(4)

	var error_count := 0
	var warning_count := 0
	for entry: Dictionary in _catalog.report:
		if entry["severity"] == &"error":
			error_count += 1
		elif entry["severity"] == &"warning":
			warning_count += 1
	assert_int(error_count).is_equal(2)
	assert_int(warning_count).is_equal(2)

	var tuples: Array[String] = _tuples()
	assert_array(tuples).contains([
		"error|bad_no_prefix|id",
		"error|char_typo|stat_blok",
		"warning|faction_alien_a|signature_color",
		"warning|char_sig|signature_move_id",
	])


## Edge case: with the two error records removed, the same two warnings load
## READY — warnings alone never fail the catalog.
func test_warnings_alone_load_ready() -> void:
	var result: Error = _catalog.load_all(ROOT.path_join("warnings_only"))

	assert_int(result).is_equal(OK)
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.READY)
	assert_int(_catalog.report.size()).override_failure_message(
			"report: %s" % [_catalog.report]).is_equal(2)
	for entry: Dictionary in _catalog.report:
		assert_str(String(entry["severity"])).is_equal("warning")
