## Story 009: headless CI entry point. Exits 0 only if
## `CharacterizationBaseline.diff()` finds the gated set unchanged; exits 1
## and names each offending path otherwise. A missing manifest is reported
## by name and also exits 1 -- `diff()` itself already fails closed on a
## missing or unparsable manifest (an unreadable manifest parses to no
## entries, so every gated path is reported as offending), this just gives a
## clearer first line in the CI log.
## Example: [code]godot --headless -s res://tools/ci/check_characterization_unchanged.gd -- --manifest=res://tools/ci/characterization_baseline.sha256 --root=res://[/code]
extends SceneTree


func _initialize() -> void:
	var manifest_path: String = "res://tools/ci/characterization_baseline.sha256"
	var root: String = "res://"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--manifest="):
			manifest_path = arg.trim_prefix("--manifest=")
		elif arg.begins_with("--root="):
			root = arg.trim_prefix("--root=")

	if not FileAccess.file_exists(manifest_path):
		print("Characterization baseline manifest missing or unreadable: %s" % manifest_path)

	var offending: PackedStringArray = CharacterizationBaseline.diff(manifest_path, root)
	for path: String in offending:
		print("CHANGED: %s" % path)
	if offending.is_empty():
		print("Characterization baseline unchanged (%d files)." % CharacterizationBaseline.gated_paths(root).size())

	quit(mini(offending.size(), 1))
