extends SceneTree
## Runs `MapValidator.validate_catalog` over the shipped content and prints
## every error, so a map edit can be checked without the whole suite.
##
## Usage: godot --headless --path . -s res://tools/maps/validate_maps_cli.gd
## Exit 0 when clean, 1 when there are errors.


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var catalog: ContentCatalogService = root.get_node(^"ContentCatalog") as ContentCatalogService
	ContentBootstrap.run(catalog)
	var errors: PackedStringArray = MapValidator.validate_catalog(catalog, OverworldConfig.new())
	for e: String in errors:
		print("MAPERR: ", e)
	print("map errors: %d" % errors.size())
	quit(0 if errors.is_empty() else 1)
