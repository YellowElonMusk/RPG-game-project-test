## Map-structure checks for Town, the story encounter and the boss (ADR-0012
## §3 `validate_maps`; GDD rules 11, 13 and 13a; story 075, AC-30b). Pure
## static; run by `MapValidator.validate_maps()`, so both the boot check and
## `tools/ci/validate_maps.gd` apply it. Each error names the map and the
## marker.
##
## Roles are read from the markers, not from map IDs:
## - the **region default camp** is the one CampSpot with
##   `is_region_default`; its map (Town) holds no symbols;
## - a **story encounter** is a Static symbol with `start_on = confirm`;
## - a **boss** is a Static symbol with `start_on = contact_or_confirm`.
##
## Story encounter (rule 13a): its map holds a CampSpot, both reachable from
## the camp's return EntryPoint with every checkpoint closed (the first
## room). It stands on a walkable cell beside the closed `encounter`-outcome
## checkpoint its Victory opens (exempt from the symbol-legal rule). Its
## walk-grid distance from the nearest CampSpot's safe-zone edge is at most
## `story_sight_m`, and the camera's visibility edge in its direction from
## that edge (`ChaseVisibility.edge_reach()`) is at least that distance. Its
## return marker lies between `return_safe_radius_m + body_radius` and
## `interact_reach_m * 3` from it, on the camp side.
##
## Boss (rule 13): a symbol-legal cell (walkable, not `SAFE`), at least
## `safe_radius_m + 2 * body_radius + cell_m` from every safe-zone source on
## its map.
class_name MapStructureValidator
extends RefCounted


## Validates `maps` (`map_id -> OverworldMap`). `presentation` supplies the
## follow camera for the telegraph check.
static func validate(maps: Dictionary, cfg: OverworldConfig,
		presentation: PresentationConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	var defaults: Array[String] = []
	for map_id: String in maps:
		var map: OverworldMap = maps[map_id]
		for camp: CampSpot in map.camp_spots():
			if camp.is_region_default:
				defaults.append("%s/%s" % [map_id, camp.marker_id])
				if not map.symbol_markers().is_empty():
					errors.append("%s: holds the region default camp '%s' but has %d symbol(s)"
							% [map_id, camp.marker_id, map.symbol_markers().size()])
	if defaults.size() != 1:
		errors.append("region default camp: expected exactly 1 CampSpot with is_region_default, found %d %s"
				% [defaults.size(), defaults])
	for map_id: String in maps:
		_check_patrol_clearance(maps[map_id], cfg, errors)
		_check_patrol_legality(maps[map_id], cfg, errors)
	for map_id: String in maps:
		var map: OverworldMap = maps[map_id]
		var grid: WalkGrid = null
		for sym: EncounterSymbol in map.symbol_markers():
			if not sym.is_static or sym.patrol_path.is_empty():
				continue
			if grid == null:
				grid = map.bake_walk_grid(cfg)
				for cp: CheckpointMarker in map.checkpoints():
					grid.set_blocked(OverworldMode.checkpoint_cells(cp, grid), true)
			if sym.start_on == EncounterSymbol.StartOn.CONFIRM:
				_check_story_encounter(map, grid, sym, cfg, presentation, errors)
				_check_not_routable_around(maps, map, sym, cfg, errors)
			else:
				_check_boss(map, grid, sym, cfg, errors)
	return errors


static func _check_story_encounter(map: OverworldMap, grid: WalkGrid, sym: EncounterSymbol,
		cfg: OverworldConfig, presentation: PresentationConfig, errors: PackedStringArray) -> void:
	var tag: String = "%s: story encounter '%s'" % [map.map_id, _sym_id(sym)]
	var pos: Vector2 = sym.patrol_path[0]
	var cell: Vector2i = grid.cell_of(pos)
	if not grid.is_walkable(cell):
		errors.append("%s stands on a non-walkable cell %s" % [tag, cell])
	var cp: CheckpointMarker = map.find_checkpoint(sym.checkpoint_id)
	if cp == null:
		errors.append("%s names no checkpoint '%s'" % [tag, sym.checkpoint_id])
	else:
		if cp.failure_outcome != CheckpointMarker.FailureOutcome.ENCOUNTER \
				or cp.linked_encounter_id != sym.encounter_id:
			errors.append("%s: checkpoint '%s' must have the encounter outcome linked to '%s'"
					% [tag, cp.marker_id, sym.encounter_id])
		var beside: bool = false
		for c: Vector2i in OverworldMode.checkpoint_cells(cp, grid):
			if absi(c.x - cell.x) + absi(c.y - cell.y) == 1:
				beside = true
		if not beside:
			errors.append("%s is not on a cell in front of checkpoint '%s'" % [tag, cp.marker_id])
	var camps: Array[CampSpot] = map.camp_spots()
	if camps.is_empty():
		errors.append("%s: its map holds no CampSpot" % tag)
		return
	var camp: CampSpot = camps[0]
	for c: CampSpot in camps:
		if c.ground_position(map).distance_to(pos) < camp.ground_position(map).distance_to(pos):
			camp = c
	var camp_pos: Vector2 = camp.ground_position(map)
	var entry: EntryPoint = map.find_entry_point(camp.return_entry_id)
	if entry == null:
		errors.append("%s: camp '%s' names no EntryPoint '%s'" % [tag, camp.marker_id, camp.return_entry_id])
	else:
		var from_entry: Dictionary = walk_distances(grid, [grid.cell_of(entry.ground_position(map))])
		if not from_entry.has(grid.cell_of(camp_pos)) or not from_entry.has(cell):
			errors.append("%s: camp '%s' and the encounter are not both in the first room (reachable from '%s' with every checkpoint closed)"
					% [tag, camp.marker_id, entry.marker_id])
	var edge_cells: Array[Vector2i] = []
	for y in grid.size.y:
		for x in grid.size.x:
			var c := Vector2i(x, y)
			if grid.is_walkable(c) and ((Vector2(c) + Vector2(0.5, 0.5)) * grid.cell_m).distance_to(camp_pos) <= cfg.safe_radius_m:
				edge_cells.append(c)
	var walk: Dictionary = walk_distances(grid, edge_cells)
	var walk_m: float = float(walk.get(cell, INF))
	if walk_m > cfg.story_sight_m:
		errors.append("%s is %.2f m along the walk grid from camp '%s''s safe-zone edge (> story_sight_m %.2f)"
				% [tag, walk_m, camp.marker_id, cfg.story_sight_m])
	var edge_dist: float = maxf(0.0, camp_pos.distance_to(pos) - cfg.safe_radius_m)
	var reach: float = ChaseVisibility.edge_reach(pos - camp_pos, presentation, cfg.walk_speed)
	if reach < edge_dist:
		errors.append("%s: the camera shows %.2f m toward it from camp '%s''s safe-zone edge, but it is %.2f m away"
				% [tag, reach, camp.marker_id, edge_dist])
	if sym.return_marker == Vector2.ZERO:
		errors.append("%s has no return marker" % tag)
	else:
		var r: float = sym.return_marker.distance_to(pos)
		var lo: float = cfg.return_safe_radius_m + cfg.body_radius
		var hi: float = cfg.interact_reach_m * 3.0
		if r < lo or r > hi:
			errors.append("%s: return marker is %.2f m away (expected %.2f to %.2f)" % [tag, r, lo, hi])
		if (sym.return_marker - pos).dot(camp_pos - pos) <= 0.0:
			errors.append("%s: return marker is not on the camp side" % tag)


static func _check_boss(map: OverworldMap, grid: WalkGrid, sym: EncounterSymbol,
		cfg: OverworldConfig, errors: PackedStringArray) -> void:
	var tag: String = "%s: boss '%s'" % [map.map_id, _sym_id(sym)]
	var pos: Vector2 = sym.patrol_path[0]
	if not grid.is_symbol_legal(grid.cell_of(pos)):
		errors.append("%s stands on a cell that is blocked or SAFE" % tag)
	var min_d: float = cfg.safe_radius_m + 2.0 * cfg.body_radius + grid.cell_m
	for source: Dictionary in map.safe_sources(cfg):
		var d: float = WalkGrid.rect_distance(Rect2(pos, Vector2.ZERO), source["rect"])
		if d < min_d:
			errors.append("%s is %.2f m from a safe-zone source at %s (< %.2f)"
					% [tag, d, (source["rect"] as Rect2).position, min_d])


## Story 077, AC-30c (GDD rule 12 "Safe zones"): no spawn point or patrol
## segment of a patrolling symbol (a `loop` path's closing segment
## included) comes within `safe_radius_m` of an EntryPoint or CampSpot
## (segment to point) or a MapExit rectangle (segment to rectangle), or
## within `symbol_chase_m + body_radius` of a return marker. Static symbols
## are placed by rules 13 and 13a instead.
static func _check_patrol_clearance(map: OverworldMap, cfg: OverworldConfig,
		errors: PackedStringArray) -> void:
	var points: Array = []  # [label, point, margin]
	var rects: Array = []   # [label, rect, margin]
	for entry: EntryPoint in map.entry_points():
		points.append(["EntryPoint '%s'" % entry.marker_id, entry.ground_position(map), cfg.safe_radius_m])
	for camp: CampSpot in map.camp_spots():
		points.append(["CampSpot '%s'" % camp.marker_id, camp.ground_position(map), cfg.safe_radius_m])
	for exit: MapExit in map.map_exits():
		rects.append(["MapExit '%s'" % exit.marker_id, exit.trigger_rect, cfg.safe_radius_m])
	var return_margin: float = cfg.symbol_chase_m + cfg.body_radius
	for cp: CheckpointMarker in map.checkpoints():
		points.append(["return marker of '%s'" % cp.marker_id, cp.return_marker, return_margin])
	for sym: EncounterSymbol in map.symbol_markers():
		if sym.is_static and sym.return_marker != Vector2.ZERO:
			points.append(["return marker of '%s'" % _sym_id(sym), sym.return_marker, return_margin])
	for sym: EncounterSymbol in map.symbol_markers():
		if sym.is_static or sym.patrol_path.is_empty():
			continue
		var path: PackedVector2Array = sym.patrol_path
		var segments: Array = []
		if path.size() == 1:
			segments.append([path[0], path[0], "spawn point"])
		for i in path.size() - 1:
			segments.append([path[i], path[i + 1], "segment %d" % i])
		if path.size() > 2 and sym.path_mode == SymbolBrain.PathMode.LOOP:
			segments.append([path[path.size() - 1], path[0], "closing segment"])
		for seg: Array in segments:
			for p: Array in points:
				var d: float = segment_point_distance(seg[0], seg[1], p[1])
				if d < float(p[2]):
					errors.append("%s: symbol '%s' %s is %.2f m from %s (< %.2f)"
							% [map.map_id, _sym_id(sym), seg[2], d, p[0], p[2]])
			for r: Array in rects:
				var d: float = segment_rect_distance(seg[0], seg[1], r[1])
				if d < float(r[2]):
					errors.append("%s: symbol '%s' %s is %.2f m from %s (< %.2f)"
							% [map.map_id, _sym_id(sym), seg[2], d, r[0], r[2]])


## Distance from point `p` to segment `a`-`b`.
static func segment_point_distance(a: Vector2, b: Vector2, p: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


## Distance from segment `a`-`b` to `rect` (0 when they touch or cross).
static func segment_rect_distance(a: Vector2, b: Vector2, rect: Rect2) -> float:
	if rect.has_point(a) or rect.has_point(b):
		return 0.0
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y),
			rect.end, Vector2(rect.position.x, rect.end.y)]
	var best: float = INF
	for i in 4:
		var c: Vector2 = corners[i]
		var n: Vector2 = corners[(i + 1) % 4]
		if Geometry2D.segment_intersects_segment(a, b, c, n) != null:
			return 0.0
		best = minf(best, segment_point_distance(a, b, c))
	best = minf(best, WalkGrid.rect_distance(Rect2(a, Vector2.ZERO), rect))
	best = minf(best, WalkGrid.rect_distance(Rect2(b, Vector2.ZERO), rect))
	return best


## Walk-grid distances in metres from `starts` (each at 0) to every
## reachable walkable cell: 8-connected, diagonals `sqrt(2) * cell_m` and
## never cutting a blocked corner. Keyed by cell.
static func walk_distances(grid: WalkGrid, starts: Array[Vector2i]) -> Dictionary:
	var dist: Dictionary = {}
	var open: Array[Vector2i] = []
	for s: Vector2i in starts:
		if grid.is_walkable(s):
			dist[s] = 0.0
			open.append(s)
	while not open.is_empty():
		var best_i: int = 0
		for i in open.size():
			if float(dist[open[i]]) < float(dist[open[best_i]]):
				best_i = i
		var c: Vector2i = open[best_i]
		open.remove_at(best_i)
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var n := Vector2i(c.x + dx, c.y + dy)
				if not grid.is_walkable(n):
					continue
				if dx != 0 and dy != 0 and (not grid.is_walkable(Vector2i(c.x + dx, c.y)) \
						or not grid.is_walkable(Vector2i(c.x, c.y + dy))):
					continue
				var step: float = grid.cell_m * (1.41421356 if dx != 0 and dy != 0 else 1.0)
				var nd: float = float(dist[c]) + step
				if nd < float(dist.get(n, INF)) - 1e-9:
					if not dist.has(n):
						open.append(n)
					dist[n] = nd
	return dist


static func _sym_id(sym: EncounterSymbol) -> String:
	return sym.symbol_id if not sym.symbol_id.is_empty() else sym.encounter_id


## Story 084, AC-31d (GDD rule 12 "The story encounter cannot be routed
## round"): with every other checkpoint open (the most generous case; bands
## are not applied, this is topology), and only the story encounter's own
## checkpoint closed, no walk-grid route from the camp's EntryPoint reaches
## an exit to a map holding the boss. The payoff half of the AC (symbols
## whose `open` payoff opens the dungeon shortcut lie beyond the checkpoint)
## has nothing to check until `victory_payoff` exists (story 050); it is
## recorded here so that story extends this function.
static func _check_not_routable_around(maps: Dictionary, map: OverworldMap,
		sym: EncounterSymbol, cfg: OverworldConfig, errors: PackedStringArray) -> void:
	var cp: CheckpointMarker = map.find_checkpoint(sym.checkpoint_id)
	if cp == null or map.camp_spots().is_empty():
		return
	var entry: EntryPoint = map.find_entry_point(map.camp_spots()[0].return_entry_id)
	if entry == null:
		return
	var grid: WalkGrid = map.bake_walk_grid(cfg)
	grid.set_blocked(OverworldMode.checkpoint_cells(cp, grid), true)
	var reach: Dictionary = walk_distances(grid, [grid.cell_of(entry.ground_position(map))])
	for exit: MapExit in map.map_exits():
		if not _holds_boss(maps.get(exit.target_map_id) as OverworldMap):
			continue
		var r: Rect2 = exit.trigger_rect
		for y in range(floori(r.position.y / grid.cell_m), ceili(r.end.y / grid.cell_m)):
			for x in range(floori(r.position.x / grid.cell_m), ceili(r.end.x / grid.cell_m)):
				if reach.has(Vector2i(x, y)):
					errors.append("%s: exit '%s' to the boss is reachable from '%s' without crossing checkpoint '%s'"
							% [map.map_id, exit.marker_id, entry.marker_id, cp.marker_id])
					return


static func _holds_boss(map: OverworldMap) -> bool:
	if map == null:
		return false
	for s: EncounterSymbol in map.symbol_markers():
		if s.is_static and s.start_on == EncounterSymbol.StartOn.CONTACT_OR_CONFIRM:
			return true
	return false


## Story 082, AC-30h (GDD rule 5 "Patrol legality"): every cell a patrolling
## symbol's segments sweep within `body_radius` (a loop's closing segment
## included), and its origin cell, is symbol-legal: walkable, not `SAFE`,
## not under a closed checkpoint. Reports the first offending cell per
## symbol. Static symbols are placed by rules 13 and 13a instead. Stages:
## one configuration per map until markers carry `min_stage`
## (TODO(overworld): repeat per reachable stage, stories 053-058).
static func _check_patrol_legality(map: OverworldMap, cfg: OverworldConfig,
		errors: PackedStringArray) -> void:
	var grid: WalkGrid = null
	for sym: EncounterSymbol in map.symbol_markers():
		if sym.is_static or sym.patrol_path.is_empty():
			continue
		if grid == null:
			grid = map.bake_walk_grid(cfg)
			for cp: CheckpointMarker in map.checkpoints():
				grid.set_blocked(OverworldMode.checkpoint_cells(cp, grid), true)
		var bad: Vector2i = swept_illegal_cell(grid, sym, cfg.body_radius)
		if bad != Vector2i(-1, -1):
			errors.append("%s: symbol '%s' patrol sweeps cell %s, which is not symbol-legal (%s)"
					% [map.map_id, _sym_id(sym), bad,
					"SAFE" if grid.is_walkable(bad) else "blocked"])


## The first cell `sym`'s patrol sweeps within `radius` (or its origin
## cell) that is not symbol-legal on `grid`, or (-1, -1) when all are.
static func swept_illegal_cell(grid: WalkGrid, sym: EncounterSymbol, radius: float) -> Vector2i:
	var path: PackedVector2Array = sym.patrol_path
	var origin: Vector2i = grid.cell_of(path[0])
	if not grid.is_symbol_legal(origin):
		return origin
	var segs: Array = []
	for i in maxi(path.size() - 1, 1):
		segs.append([path[i], path[mini(i + 1, path.size() - 1)]])
	if path.size() > 2 and sym.path_mode == SymbolBrain.PathMode.LOOP:
		segs.append([path[path.size() - 1], path[0]])
	for s: Array in segs:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var lo := Vector2i(floori((minf(a.x, b.x) - radius) / grid.cell_m), floori((minf(a.y, b.y) - radius) / grid.cell_m))
		var hi := Vector2i(floori((maxf(a.x, b.x) + radius) / grid.cell_m), floori((maxf(a.y, b.y) + radius) / grid.cell_m))
		for y in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1):
				var cell := Vector2i(x, y)
				var rect := Rect2(Vector2(cell) * grid.cell_m, Vector2.ONE * grid.cell_m)
				# Strictly inside the swept body, so a body exactly touching a
				# neighbouring cell's edge does not count that cell.
				if segment_rect_distance(a, b, rect) < radius and not grid.is_symbol_legal(cell):
					return cell
	return Vector2i(-1, -1)
