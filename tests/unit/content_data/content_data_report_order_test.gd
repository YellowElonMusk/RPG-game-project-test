## Story 023, AC-20 (TR-content-008; GDD F3 "Report order"): a fixture
## triggering 5 different rules (malformed ID, duplicate ID, missing
## reference, unknown field, faction mismatch) gives exactly 5 errors, in a
## deterministic order that does not depend on discovery order. The report is
## sorted ascending by (file_path, record_index, field, severity), normalised
## to res:// paths. Each test builds a fresh ContentCatalogService (never the
## autoload).
extends GdUnitTestSuite

const ROOT := "res://tests/unit/content_data/fixtures/five_rule_violations"


## The report's error-severity entries, projected to (file_path,
## record_index, field, severity) tuples, in report order.
func _error_projection(catalog: ContentCatalogService) -> Array:
	var out: Array = []
	for entry: Dictionary in catalog.report:
		if entry["severity"] != &"error":
			continue
		var location: Dictionary = entry["location"]
		out.append([location["file_path"], location["record_index"], String(entry["field"]), String(entry["severity"])])
	return out


## T1: five rules give exactly five errors, and the catalog is FAILED.
func test_five_rule_violations_give_five_errors() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())

	var result: Error = catalog.load_all(ROOT)

	assert_int(result).is_equal(FAILED)
	assert_int(catalog.state).is_equal(ContentCatalogService.State.FAILED)
	var errors: Array = _error_projection(catalog)
	assert_int(errors.size()).override_failure_message(
			"report: %s" % [catalog.report]).is_equal(5)


## The F3 sort rules the five-rule fixture cannot reach, on hand-built
## entries run through the catalog's own end-of-Validating sort: an empty
## field sorts first; on the same file and field an error precedes a warning;
## record_id then message break the remaining ties; location and
## related_locations paths are normalised (backslashes, and an absolute path
## localised back to res://).
func test_sort_rules_empty_field_severity_tiebreaks_and_paths() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	var file := "res://data/characters/char_x.tres"
	var absolute := ProjectSettings.globalize_path("res://data/characters/char_y.tres")
	# A Windows-style absolute path: backslashes, outside res:// form.
	var backslashed := ProjectSettings.globalize_path("res://data/characters/char_z.tres").replace("/", "\\")
	var entry := func(severity: StringName, record_id: String, field: StringName,
			path: String, message: String, related: Array = []) -> Dictionary:
		return {"severity": severity, "record_id": record_id, "field": field,
				"location": {"file_path": path, "record_index": 0},
				"message": message, "related_locations": related}
	catalog.report.assign([
		entry.call(&"warning", "char_x", &"name", file, "w"),
		entry.call(&"error", "char_x", &"name", file, "b"),
		entry.call(&"error", "char_x", &"name", file, "a"),
		entry.call(&"error", "char_w", &"name", file, "z"),
		entry.call(&"error", "char_x", &"", file, "whole record"),
		entry.call(&"error", "char_y", &"id", absolute, "abs",
				[{"file_path": backslashed, "record_index": 0}]),
	])

	catalog._sort_report()

	var order: Array[String] = []
	for e: Dictionary in catalog.report:
		order.append("%s|%s|%s|%s" % [e["field"], e["severity"], e["record_id"], e["message"]])
	assert_array(order).is_equal([
		"|error|char_x|whole record",
		"name|error|char_w|z",
		"name|error|char_x|a",
		"name|error|char_x|b",
		"name|warning|char_x|w",
		"id|error|char_y|abs",
	])
	var last: Dictionary = catalog.report[5]
	assert_str((last["location"] as Dictionary)["file_path"]).is_equal("res://data/characters/char_y.tres")
	assert_str(((last["related_locations"] as Array)[0] as Dictionary)["file_path"]) \
			.is_equal("res://data/characters/char_z.tres")


## T2: the same fixture loaded with discovery order reversed gives the same
## error sequence, and that sequence is sorted ascending by the F3 key with
## an empty field first. A third run in the same process repeats it.
func test_error_order_is_identical_across_runs_and_sorted() -> void:
	var catalog_a: ContentCatalogService = auto_free(ContentCatalogService.new())
	catalog_a.load_all(ROOT)
	var sequence_a: Array = _error_projection(catalog_a)

	var catalog_b: ContentCatalogService = auto_free(ContentCatalogService.new())
	catalog_b.discovery_order_transform = func(listing: PackedStringArray) -> PackedStringArray:
		var reversed: PackedStringArray = listing.duplicate()
		reversed.reverse()
		return reversed
	catalog_b.load_all(ROOT)
	var sequence_b: Array = _error_projection(catalog_b)

	var catalog_c: ContentCatalogService = auto_free(ContentCatalogService.new())
	catalog_c.load_all(ROOT)
	var sequence_c: Array = _error_projection(catalog_c)

	assert_array(sequence_b).override_failure_message(
			"a: %s\nb (reversed discovery): %s" % [sequence_a, sequence_b]).is_equal(sequence_a)
	assert_array(sequence_c).is_equal(sequence_a)

	var sorted_copy: Array = sequence_a.duplicate(true)
	sorted_copy.sort()
	assert_array(sequence_a).override_failure_message(
			"not sorted ascending: %s" % [sequence_a]).is_equal(sorted_copy)
