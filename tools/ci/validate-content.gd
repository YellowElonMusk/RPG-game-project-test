extends SceneTree
## Headless content validation (ADR-0001 "Standalone headless validation",
## amendment 2026-10-23; ADR-0004 §5). Runs `ContentBootstrap.run()` -- never
## `ContentCatalogService.load_all()` directly -- so CI validates with every
## vocabulary and validator registered, the same as a real boot. Mirrors
## `.claude/scripts/godot-parse-check.gd`'s `_initialize()` timing: the
## autoload does not exist in `_init()`, and its own `_ready()` runs only
## after `_initialize()` returns (verified on 4.7.2).
##
## Usage, from the project root, after `godot --headless --path . --import`
## (which builds the class cache the autoload needs):
##
##   godot --headless --path . -s res://tools/ci/validate-content.gd
##   godot --headless --path . -s res://tools/ci/validate-content.gd -- --data-root=res://tests/integration/content_data/fixtures/two_errors
##
## Prints the full report (story 024's ValidationReportText.build_log_text),
## one entry per line. Exit `min(error_count, 1)`: 0 = valid (warnings
## allowed), 1 = any error. A missing or unreadable --data-root also exits 1,
## naming the path, without running the catalog at all.


func _initialize() -> void:
	var data_root := "res://data"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--data-root="):
			data_root = arg.trim_prefix("--data-root=")

	if not DirAccess.dir_exists_absolute(data_root):
		printerr("validate-content: --data-root does not exist: ", data_root)
		quit(1)
		return

	var catalog: ContentCatalogService = root.get_node(^"ContentCatalog")
	ContentBootstrap.run(catalog, data_root)

	print(ValidationReportText.build_log_text(catalog.report))

	var error_count: int = 0
	for entry: Dictionary in catalog.report:
		if entry["severity"] == &"error":
			error_count += 1
	quit(min(error_count, 1))
