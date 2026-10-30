extends SceneTree
## Prints the first-encounter measurements (stories 086, 119) for the
## Paris segment's first leg, plus the validate_maps result, for level
## review. Usage: godot --headless --path . -s res://tools/level_review/first_encounter_report.gd


func _initialize() -> void:
	var cfg := OverworldConfig.new()
	var rec: MapData = load("res://data/maps/map_paris_segment_placeholder.tres")
	var map: OverworldMap = (load("res://data/maps/paris_segment_placeholder.tscn") as PackedScene).instantiate()
	var m: Dictionary = MapValidator.first_encounter_metrics(map, rec.critical_path[0], cfg)
	print("first_encounter: ", m)
	print("need: first_patrol >= %.1f, clue < first_notice, teach < first_notice, section_ratio <= %.2f"
			% [cfg.safe_radius_m + cfg.symbol_chase_m + cfg.first_patrol_clearance_m, cfg.first_bypass_ratio_max])
	map.free()
	quit()
