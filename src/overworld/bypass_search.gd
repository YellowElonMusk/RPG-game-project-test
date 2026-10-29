## Rule 12's bypass-lane **ordered search** (GDD Overworld rule 12; ADR-0012
## §3; story 083, AC-31). For every critical-path leg of a non-boss map, a
## walk-grid route must exist that stays out of every patrol's notice band:
##
## - **Bands.** Every cell whose centre lies within `symbol_chase_m +
##   cell_m / sqrt(2)` of a patrol segment (a loop's closing one included)
##   is blocked, as is every blocked cell (walls, closed checkpoints).
## - **Checkpoints.** A closed checkpoint opens for the search once its
##   requirement's fight-free source is reached earlier on the leg. No
##   fight-free source type (pickup, gag change, NPC line, step flag) exists
##   yet, so every checkpoint stays closed except the story encounter's
##   (TODO(overworld): sources, stories 016/070).
## - **Story encounter.** A leg that needs to cross it splits in two: start
##   to any cell within `interact_reach_m` of it (bands applied), then from
##   the cells just beyond its checkpoint to the leg end, that checkpoint
##   open.
## - **Leg ends.** A MapExit's rectangle cells; a Static symbol's cells
##   within `interact_reach_m`; a CampSpot's safe zone.
##
## Stages: markers carry no `min_stage` yet and no stage system exists, so
## each map has one reachable configuration (TODO(overworld): repeat per
## reachable stage, stories 053-058). Boss maps are skipped (rule 12: there
## `L_bypass = L_crit`).
class_name BypassSearch
extends RefCounted


## Errors for every leg of `rec` on `map` with no bypass lane.
static func check(rec: MapData, map: OverworldMap, cfg: OverworldConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	if MapStructureValidator._holds_boss(map):
		return errors
	var story: EncounterSymbol = null
	for sym: EncounterSymbol in map.symbol_markers():
		if sym.is_static and sym.start_on == EncounterSymbol.StartOn.CONFIRM:
			story = sym
	var story_cp: CheckpointMarker = map.find_checkpoint(story.checkpoint_id) if story != null else null
	for leg: CriticalPathLeg in rec.critical_path:
		var entry: EntryPoint = map.find_entry_point(leg.from_entry)
		if entry == null:
			continue  # reported by MapValidator.validate_legs()
		var grid: WalkGrid = banded_grid(map, cfg)
		var start: Array[Vector2i] = [grid.cell_of(entry.ground_position(map))]
		var goal: Dictionary = _goal_cells(map, grid, leg.to, cfg)
		if goal.is_empty():
			continue
		var reach: Dictionary = MapStructureValidator.walk_distances(grid, start)
		if _hits(reach, goal):
			continue
		if story != null and story_cp != null and leg.to != _sym_key(story):
			# The split: up to the counter, then on from beyond its boom.
			var at_counter: Dictionary = _within(grid, story.patrol_path[0], cfg.interact_reach_m)
			var cp_cells: Array[Vector2i] = OverworldMode.checkpoint_cells(story_cp, grid)
			grid.set_blocked(cp_cells, false)
			var beyond: Array[Vector2i] = []
			for c: Vector2i in cp_cells:
				for n: Vector2i in [c + Vector2i.UP, c + Vector2i.DOWN, c + Vector2i.LEFT, c + Vector2i.RIGHT]:
					if grid.is_walkable(n) and not cp_cells.has(n) and not reach.has(n):
						beyond.append(n)
			var second: Dictionary = MapStructureValidator.walk_distances(grid, beyond)
			if _hits(reach, at_counter) and _hits(second, goal):
				continue
		errors.append("%s: leg '%s' (%s -> %s) has no bypass lane clear of every patrol band"
				% [rec.id, leg.id, leg.from_entry, leg.to])
	return errors


## `map`'s baked grid with every checkpoint closed and every patrol band
## blocked (rule 12 "Bands").
static func banded_grid(map: OverworldMap, cfg: OverworldConfig) -> WalkGrid:
	var grid: WalkGrid = map.bake_walk_grid(cfg)
	for cp: CheckpointMarker in map.checkpoints():
		grid.set_blocked(OverworldMode.checkpoint_cells(cp, grid), true)
	var band: float = cfg.symbol_chase_m + grid.cell_m / sqrt(2.0)
	var cells: Array[Vector2i] = []
	for sym: EncounterSymbol in map.symbol_markers():
		if sym.is_static or sym.patrol_path.is_empty():
			continue
		var path: PackedVector2Array = sym.patrol_path
		var segs: Array = []
		for i in maxi(path.size() - 1, 1):
			segs.append([path[i], path[mini(i + 1, path.size() - 1)]])
		if path.size() > 2 and sym.path_mode == SymbolBrain.PathMode.LOOP:
			segs.append([path[path.size() - 1], path[0]])
		for y in grid.size.y:
			for x in grid.size.x:
				var centre := (Vector2(x, y) + Vector2(0.5, 0.5)) * grid.cell_m
				for s: Array in segs:
					if MapStructureValidator.segment_point_distance(s[0], s[1], centre) <= band:
						cells.append(Vector2i(x, y))
						break
	grid.set_blocked(cells, true)
	return grid


static func _goal_cells(map: OverworldMap, grid: WalkGrid, to: String, cfg: OverworldConfig) -> Dictionary:
	for exit: MapExit in map.map_exits():
		if String(exit.marker_id) == to:
			var out: Dictionary = {}
			var r: Rect2 = exit.trigger_rect
			for y in range(floori(r.position.y / grid.cell_m), ceili(r.end.y / grid.cell_m)):
				for x in range(floori(r.position.x / grid.cell_m), ceili(r.end.x / grid.cell_m)):
					out[Vector2i(x, y)] = true
			return out
	for camp: CampSpot in map.camp_spots():
		if String(camp.marker_id) == to:
			return _within(grid, camp.ground_position(map), cfg.safe_radius_m)
	for sym: EncounterSymbol in map.symbol_markers():
		if sym.is_static and _sym_key(sym) == to:
			return _within(grid, sym.patrol_path[0], cfg.interact_reach_m)
	return {}


## Walkable cells whose centre lies within `radius` of `point`.
static func _within(grid: WalkGrid, point: Vector2, radius: float) -> Dictionary:
	var out: Dictionary = {}
	for y in grid.size.y:
		for x in grid.size.x:
			var c := Vector2i(x, y)
			if ((Vector2(c) + Vector2(0.5, 0.5)) * grid.cell_m).distance_to(point) <= radius:
				out[c] = true
	return out


static func _hits(reach: Dictionary, goal: Dictionary) -> bool:
	for c: Vector2i in goal:
		if reach.has(c):
			return true
	return false


static func _sym_key(sym: EncounterSymbol) -> String:
	return sym.symbol_id if not sym.symbol_id.is_empty() else sym.encounter_id
