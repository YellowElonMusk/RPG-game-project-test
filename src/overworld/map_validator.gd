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
## Story 075: Town, story-encounter and boss placement
## (`MapStructureValidator`).
##
## TODO(ow-epic): the remaining `tools/ci/validate_maps.gd` checks
## (DioramaStage count, physics-node ban, patrol and leg checks).
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
	for rec: Resource in catalog.all_records(&"map"):
		var rec_map: OverworldMap = maps.get(String(rec.get("id"))) as OverworldMap
		if rec_map != null and rec is MapData:
			errors.append_array(validate_legs(rec as MapData, rec_map))
	for map: OverworldMap in maps.values():
		map.free()
	return errors


## Validates `maps` (`map_id -> OverworldMap`, not necessarily in the tree)
## against each other. Bakes each map's grid for the facing check.
static func validate_maps(maps: Dictionary, cfg: OverworldConfig,
		presentation: PresentationConfig = null) -> PackedStringArray:
	var errors := PackedStringArray()
	errors.append_array(MapStructureValidator.validate(maps, cfg,
			presentation if presentation != null else PresentationConfig.new()))
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
			if target != null and not _has_exit_to(target, map_id):
				errors.append("%s: exit '%s' leads to %s, which has no exit back (story 074)"
						% [map_id, exit.marker_id, exit.target_map_id])
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


## Story 074, AC-30a (GDD rule 0): every `critical_path` leg of `rec` has a
## unique ID, starts at an EntryPoint on `map` and ends at one of its
## MapExits, Static symbols (`symbol_id`) or CampSpots (`marker_id`).
static func validate_legs(rec: MapData, map: OverworldMap) -> PackedStringArray:
	var errors := PackedStringArray()
	var ends: Dictionary = {}
	for exit: MapExit in map.map_exits():
		ends[String(exit.marker_id)] = true
	for camp: CampSpot in map.camp_spots():
		ends[String(camp.marker_id)] = true
	for sym: EncounterSymbol in map.symbol_markers():
		if sym.is_static:
			ends[sym.symbol_id if not sym.symbol_id.is_empty() else sym.encounter_id] = true
	var seen: Dictionary = {}
	for leg: CriticalPathLeg in rec.critical_path:
		if leg == null:
			errors.append("%s: a critical_path entry is empty" % rec.id)
			continue
		if seen.has(leg.id) or leg.id.is_empty():
			errors.append("%s: critical_path leg id '%s' is empty or repeated" % [rec.id, leg.id])
		seen[leg.id] = true
		if map.find_entry_point(leg.from_entry) == null:
			errors.append("%s: leg '%s' starts at unknown EntryPoint '%s'" % [rec.id, leg.id, leg.from_entry])
		if not ends.has(leg.to):
			errors.append("%s: leg '%s' ends at '%s', which is no MapExit, Static symbol or CampSpot on the map"
					% [rec.id, leg.id, leg.to])
	return errors


static func _has_exit_to(map: OverworldMap, target_map_id: String) -> bool:
	for exit: MapExit in map.map_exits():
		if exit.target_map_id == target_map_id:
			return true
	return false
