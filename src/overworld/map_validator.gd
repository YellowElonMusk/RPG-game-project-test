## Load-time validator for `map_` records and their scenes (ADR-0012 §3
## `validate_maps` subset; GDD rule 11; stories 080 and 138). Pure static:
## each error string names the map and the offending marker(s).
##
## Checks: every `map_` record has a scene at its conventional path whose
## root is an `OverworldMap` with a matching `map_id`; marker IDs are unique
## per map; every `MapExit` names an existing map and an existing EntryPoint
## on it; every EntryPoint lies at least `body_radius + entry_clearance_m`
## outside every MapExit rectangle on its map (AC-30f) and faces into the
## map (the cell one `cell_m` ahead along its facing is walkable).
##
## TODO(ow-epic): the remaining `tools/ci/validate_maps.gd` checks
## (DioramaStage count, physics-node ban, placement and leg checks).
##
## Usage example:
## [codeblock]
## for err: String in MapValidator.validate_catalog(catalog, OverworldConfig.new()):
##     push_error(err)
## [/codeblock]
class_name MapValidator
extends RefCounted


## Validates every `map` record in `catalog` against its scene in
## `cfg.map_scene_dir`. Instantiated scenes are freed before returning.
static func validate_catalog(catalog: ContentCatalogService, cfg: OverworldConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	var maps: Dictionary = {}  # map_id -> OverworldMap
	for rec: Resource in catalog.all_records(&"map"):
		var map_id: String = String(rec.get("id"))
		var path: String = OverworldMap.scene_path(map_id, cfg.map_scene_dir)
		var scene: PackedScene = null
		if ResourceLoader.exists(path):
			scene = ResourceLoader.load(path) as PackedScene
		if scene == null:
			errors.append("%s: no map scene at %s" % [map_id, path])
			continue
		var map: OverworldMap = scene.instantiate() as OverworldMap
		if map == null:
			errors.append("%s: scene %s root is not an OverworldMap" % [map_id, path])
			continue
		if map.map_id != map_id:
			errors.append("%s: scene map_id is '%s'" % [map_id, map.map_id])
		maps[map_id] = map
	errors.append_array(validate_maps(maps, cfg))
	for map: OverworldMap in maps.values():
		map.free()
	return errors


## Validates `maps` (`map_id -> OverworldMap`, not necessarily in the tree)
## against each other. Bakes each map's grid for the facing check.
static func validate_maps(maps: Dictionary, cfg: OverworldConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	var clearance: float = cfg.body_radius + cfg.entry_clearance_m
	for map_id: String in maps:
		var map: OverworldMap = maps[map_id]
		var ids: Dictionary = {}
		for id: StringName in map.marker_ids():
			if ids.has(id):
				errors.append("%s: duplicate marker_id '%s'" % [map_id, id])
			ids[id] = true
		var exits: Array[MapExit] = map.map_exits()
		for exit: MapExit in exits:
			var target: OverworldMap = maps.get(exit.target_map_id) as OverworldMap
			if target == null:
				errors.append("%s: exit '%s' names unknown map '%s'"
						% [map_id, exit.marker_id, exit.target_map_id])
			elif target.find_entry_point(exit.target_entry_id) == null:
				errors.append("%s: exit '%s' names unknown EntryPoint '%s' on %s"
						% [map_id, exit.marker_id, exit.target_entry_id, exit.target_map_id])
		var grid: WalkGrid = map.bake_walk_grid(cfg)
		for entry: EntryPoint in map.entry_points():
			var pos: Vector2 = entry.ground_position(map)
			for exit: MapExit in exits:
				var dist: float = distance_to_rect(pos, exit.trigger_rect)
				if dist < clearance:
					errors.append("%s: EntryPoint '%s' is %.2f m from exit '%s' (< %.2f)"
							% [map_id, entry.marker_id, dist, exit.marker_id, clearance])
			if entry.facing.is_zero_approx() or not grid.is_walkable(
					grid.cell_of(pos + entry.facing.normalized() * grid.cell_m)):
				errors.append("%s: EntryPoint '%s' does not face into the map"
						% [map_id, entry.marker_id])
	return errors


## Distance from `p` to `rect` (0 inside or on the edge).
static func distance_to_rect(p: Vector2, rect: Rect2) -> float:
	var nearest := Vector2(clampf(p.x, rect.position.x, rect.end.x),
			clampf(p.y, rect.position.y, rect.end.y))
	return p.distance_to(nearest)
