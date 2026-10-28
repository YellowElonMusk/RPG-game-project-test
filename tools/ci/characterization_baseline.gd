## Story 009 (ADR-0001 Migration Step 5; Validation Criteria 2): the Step 0
## characterization tests are the migration's regression check, and this is
## what makes "unchanged" checkable. `diff()` is pure and testable: given a
## manifest (path -> SHA-256) and a root, it returns every offending path --
## changed, missing, or present on disk but not in the manifest (added) --
## empty when the gated set exactly matches. A missing or unparsable manifest
## parses to no entries, so every currently-gated path shows up as offending:
## this fails closed without special-casing.
##
## The manifest format: one `<path>\t<sha256>` line per gated file, `path`
## relative to `root`, forward-slashed, sorted by path.
##
## The gated set: `tests/unit/battle/*_characterization_test.gd` (direct
## children only), plus `tests/unit/battle/fixtures/characterization_expected.gd`
## and `tests/unit/battle/fixtures/scripted_fight_commands.gd`. The seam
## (`battle_content_seam.gd`) and this story's own gate test
## (`battle_characterization_gate_test.gd`, which does not end in
## `_characterization_test.gd` on purpose) are excluded.
class_name CharacterizationBaseline
extends RefCounted

const _TEST_DIR: String = "tests/unit/battle"
const _TEST_SUFFIX: String = "_characterization_test.gd"
const _NAMED_FIXTURES: Array[String] = [
	"tests/unit/battle/fixtures/characterization_expected.gd",
	"tests/unit/battle/fixtures/scripted_fight_commands.gd",
]


## The gated set's paths, relative to `root`, forward-slashed, sorted.
## Example: [code]CharacterizationBaseline.gated_paths("res://")[/code]
static func gated_paths(root: String) -> PackedStringArray:
	var paths: Array[String] = []
	var dir := DirAccess.open(root.path_join(_TEST_DIR))
	if dir != null:
		dir.list_dir_begin()
		var entry: String = dir.get_next()
		while entry != "":
			if not dir.current_is_dir() and entry.ends_with(_TEST_SUFFIX):
				paths.append(_TEST_DIR.path_join(entry))
			entry = dir.get_next()
		dir.list_dir_end()
	for fixture: String in _NAMED_FIXTURES:
		paths.append(fixture)
	paths.sort()
	return PackedStringArray(paths)


## One `<path>\t<sha256>` line per gated file, sorted by path, trailing
## newline. Used both to generate the checked-in manifest and to build the
## temp manifests this story's own test writes.
## Example: [code]CharacterizationBaseline.build_manifest("res://")[/code]
static func build_manifest(root: String) -> String:
	var lines: Array[String] = []
	for path: String in gated_paths(root):
		lines.append("%s\t%s" % [path, FileAccess.get_sha256(root.path_join(path))])
	return "\n".join(lines) + "\n"


## Parses a `<path>\t<sha256>` manifest into `{path: hash}`. Returns an empty
## Dictionary for a manifest that does not exist, cannot be opened, or has no
## parsable lines -- the caller (`diff()`) treats that as "nothing to compare
## against" and fails closed.
static func _parse_manifest(manifest_path: String) -> Dictionary:
	var parsed: Dictionary = {}
	if not FileAccess.file_exists(manifest_path):
		return parsed
	var file: FileAccess = FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		return parsed
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty():
			continue
		var parts: PackedStringArray = line.split("\t")
		if parts.size() != 2:
			continue
		parsed[parts[0]] = parts[1]
	return parsed


## Every offending path: changed (hash differs), missing (in the manifest,
## absent from the current gated set), or added (in the current gated set,
## not in the manifest). Empty when the gated set exactly matches the
## manifest. Sorted.
## Example: [code]CharacterizationBaseline.diff("res://tools/ci/characterization_baseline.sha256", "res://")[/code]
static func diff(manifest_path: String, root: String) -> PackedStringArray:
	var manifest: Dictionary = _parse_manifest(manifest_path)
	var current: PackedStringArray = gated_paths(root)
	var offending: Array[String] = []
	var current_set: Dictionary = {}

	for path: String in current:
		current_set[path] = true
		if not manifest.has(path):
			offending.append(path)
		elif FileAccess.get_sha256(root.path_join(path)) != manifest[path]:
			offending.append(path)

	for path: String in manifest:
		if not current_set.has(path):
			offending.append(path)

	offending.sort()
	return PackedStringArray(offending)
