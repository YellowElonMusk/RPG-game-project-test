extends SceneTree
## Headless map validation (ADR-0012 §3 `validate_maps`; GDD rule 11; story
## 080). Boots the content catalog the same way `validate-content.gd` does
## (`ContentBootstrap.run()`, never `load_all()` directly), then runs
## `MapValidator.validate_catalog()` over every `map_` record and its scene:
## scene and `map_id` match, unique marker IDs, exit targets, and every
## EntryPoint at least `body_radius + entry_clearance_m` outside every
## MapExit rectangle, facing into the map (AC-30f).
##
## Usage, from the project root, after `godot --headless --path . --import`:
##
##   godot --headless --path . -s res://tools/ci/validate_maps.gd
##   godot --headless --path . -s res://tools/ci/validate_maps.gd -- --data-root=res://data
##
## Prints one line per error, each naming the map and the offending
## marker(s), then a summary. Exit 0 = clean; 1 = any map error, any content
## error (the catalog the maps are read from is incomplete), or a missing
## --data-root.
##
## TODO(ow-epic): the remaining ADR-0012 §3 checks (DioramaStage count,
## physics-node ban, story-encounter and boss placement, story 075).


func _initialize() -> void:
	var data_root := "res://data"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--data-root="):
			data_root = arg.trim_prefix("--data-root=")

	if not DirAccess.dir_exists_absolute(data_root):
		printerr("validate_maps: --data-root does not exist: ", data_root)
		quit(1)
		return

	var catalog: ContentCatalogService = root.get_node(^"ContentCatalog")
	ContentBootstrap.run(catalog, data_root)

	var content_errors: int = 0
	for entry: Dictionary in catalog.report:
		if entry["severity"] == &"error":
			content_errors += 1
	if content_errors > 0:
		printerr("validate_maps: content catalog has %d error(s); run validate-content.gd" % content_errors)
		quit(1)
		return

	var cfg := OverworldConfig.new()
	var errors: PackedStringArray = MapValidator.validate_catalog(catalog, cfg)
	# Story 098: the config invariants I1-I13, I15-I18 (I13 over the stage records).
	errors.append_array(cfg.validate(OverworldConfig.DT_MAX_DEFAULT, catalog.all_records(&"occupation_stage")))
	# Story 099: I14, the shipped camera and both overworld lighting profiles.
	for profile_id: String in ["overworld", "overworld_liberated"]:
		var profile: LightingProfile = load("%s/%s.tres" % [MapValidator.LIGHTING_PROFILE_DIR, profile_id]) as LightingProfile
		errors.append_array(ChaseVisibility.validate(cfg, PresentationConfig.new(), profile))
	for err: String in errors:
		printerr("validate_maps: ", err)
	print("validate_maps: %d map(s), %d error(s)" % [catalog.all_records(&"map").size(), errors.size()])
	quit(min(errors.size(), 1))
