## Content-migration story 022 (ADR-0001 Implementation Guidelines;
## TR-content-005): no migrated record names a file path. Every cross-reference
## is a record ID and every asset field an asset ID, a record's only external
## resource is its own script under `res://src/data/records/`, and no record
## embeds a `[sub_resource` unless its script is allowlisted.
##
## Source-tree (CI) check only: it reads `.tres` text with `FileAccess`. In an
## exported build the records are binary, so this scan is not valid there.
## It complements content-catalog story 015 (Resource-typed exports rejected at
## load): that one catches a schema that allows a link, this one a path stored
## inside an allowed `String` field.
extends GdUnitTestSuite

## The migrated record directories (story 019 landed, so `characters/` too).
const _MIGRATED_DIRS: Array[String] = [
	"res://data/factions", "res://data/enemies", "res://data/moves",
	"res://data/faction_rules", "res://data/characters",
]
const _FIXTURES: String = "res://tests/unit/battle/fixtures/no_paths/"
## The one directory a record's Script `ext_resource` may point into.
const _RECORD_SCRIPT_DIR: String = "res://src/data/records/"
## Record scripts allowed to embed a `[sub_resource` section. Empty: no
## migrated record script embeds one. An entry needs a reason comment.
const _SUB_RESOURCE_ALLOWLIST: Array[String] = []

## Pinned (RC-7): a URI scheme anywhere in a quoted value.
var _scheme_regex: RegEx = RegEx.create_from_string("(?i)(res|user|uid)://")
## Pinned (RC-7): a file extension inside a quoted value. Only quoted values
## are checked, so `low_hp_threshold = 0.5` and sentence-final periods pass.
var _extension_regex: RegEx = RegEx.create_from_string(
		"(?i)\\.(tres|res|tscn|scn|gd|gdshader|png|jpe?g|webp|svg|ogg|wav|mp3|json|ttf|otf)\\b")
var _quoted_regex: RegEx = RegEx.create_from_string(r'"((?:[^"\\]|\\.)*)"')
var _script_path_regex: RegEx = RegEx.create_from_string(r'path="([^"]*)"')


func test_migrated_records_hold_no_paths() -> void:
	var files: PackedStringArray = PackedStringArray()
	for dir: String in _MIGRATED_DIRS:
		for file_name: String in DirAccess.get_files_at(dir):
			if file_name.ends_with(".tres"):
				files.append(dir.path_join(file_name))
	assert_int(files.size()).override_failure_message("no migrated records found").is_greater(0)
	var all_violations: PackedStringArray = PackedStringArray()
	for path: String in files:
		all_violations.append_array(_violations(path))
	assert_array(Array(all_violations)).is_empty()


func test_scheme_path_in_string_field_fails() -> void:
	_assert_flags("bad_scheme_path.tres", "path-like value")


func test_file_extension_in_string_field_fails() -> void:
	_assert_flags("bad_file_extension.tres", "path-like value")


func test_second_ext_resource_fails() -> void:
	_assert_flags("bad_second_ext_resource.tres", "ext_resource")


func test_sub_resource_outside_allowlist_fails() -> void:
	_assert_flags("bad_sub_resource.tres", "sub_resource")


func test_script_outside_record_dir_fails() -> void:
	_assert_flags("bad_script_outside_records.tres", "script ext_resource")


func test_decimal_and_sentence_period_pass() -> void:
	assert_array(Array(_violations(_FIXTURES + "good_decimal.tres"))).is_empty()


func _assert_flags(fixture: String, fragment: String) -> void:
	var violations: PackedStringArray = _violations(_FIXTURES + fixture)
	assert_int(violations.size()).override_failure_message(
			"%s should fail the scan" % fixture).is_greater(0)
	assert_str("\n".join(violations)).contains(fragment)


## Every rule breach in the `.tres` text at `path`, one line each.
func _violations(path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		out.append("%s: unreadable or empty" % path)
		return out
	var ext_lines: PackedStringArray = PackedStringArray()
	var has_sub_resource: bool = false
	for line: String in text.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("[ext_resource"):
			ext_lines.append(stripped)
			continue
		if stripped.begins_with("[sub_resource"):
			has_sub_resource = true
			continue
		if stripped.begins_with("[") or stripped.is_empty():
			continue
		for quoted: RegExMatch in _quoted_regex.search_all(stripped):
			var value: String = quoted.get_string(1)
			if _scheme_regex.search(value) != null or _extension_regex.search(value) != null:
				out.append("%s: path-like value \"%s\"" % [path, value])
	if ext_lines.size() != 1:
		out.append("%s: %d ext_resource lines, expected exactly 1" % [path, ext_lines.size()])
	var script_path: String = ""
	if ext_lines.size() >= 1:
		var first: String = ext_lines[0]
		var path_match: RegExMatch = _script_path_regex.search(first)
		script_path = path_match.get_string(1) if path_match != null else ""
		if not first.contains("type=\"Script\"") or not script_path.begins_with(_RECORD_SCRIPT_DIR):
			out.append("%s: script ext_resource must be a Script under %s (got %s)" % [
					path, _RECORD_SCRIPT_DIR, first])
	if has_sub_resource and not _SUB_RESOURCE_ALLOWLIST.has(script_path):
		out.append("%s: sub_resource section in a record whose script is not allowlisted" % path)
	return out
