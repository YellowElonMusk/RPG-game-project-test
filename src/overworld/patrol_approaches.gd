## A patrol's **approaches** (GDD rule 12 "Visibility"; story 087, the
## level-review half of story 135): every walk-grid entry into the `see_m`
## disc around a patrolling symbol's patrol, reachable on foot from one of
## the map's EntryPoints, deduplicated by 45-degree sector around the patrol
## point nearest it. Each approach names where the walk-in capture freezes
## the symbol (that nearest patrol point) and where it places the leader
## (`see_m + 0.1 m` from it along the approach direction).
class_name PatrolApproaches
extends RefCounted

## One approach: `sector` 0-7 (45 degrees each, 0 = east, counter-clockwise
## in ground x/y), the entry cell, the frozen symbol point and the leader
## point.
class Approach:
	var sector: int
	var entry_cell: Vector2i
	var symbol_at: Vector2
	var leader_at: Vector2

	func _init(p_sector: int, p_cell: Vector2i, p_symbol: Vector2, p_leader: Vector2) -> void:
		sector = p_sector
		entry_cell = p_cell
		symbol_at = p_symbol
		leader_at = p_leader


## The approaches to `sym` on `map` (empty for a Static symbol), in sector
## order. Checkpoints count as closed, as the leader first meets them.
static func of(map: OverworldMap, sym: EncounterSymbol, cfg: OverworldConfig) -> Array[Approach]:
	var out: Array[Approach] = []
	if sym.is_static or sym.patrol_path.is_empty():
		return out
	var grid: WalkGrid = map.bake_walk_grid(cfg)
	for cp: CheckpointMarker in map.checkpoints():
		grid.set_blocked(OverworldMode.checkpoint_cells(cp, grid), true)
	var starts: Array[Vector2i] = []
	for entry: EntryPoint in map.entry_points():
		starts.append(grid.cell_of(entry.ground_position(map)))
	var reach: Dictionary = MapStructureValidator.walk_distances(grid, starts)
	var see: float = cfg.see_m()
	# The disc is measured along the walk grid from the patrol (a wall puts a
	# cell outside it, as it does for the notice test's path cap).
	var from_patrol: Dictionary = MapStructureValidator.walk_distances(grid, _patrol_cells(sym, grid))
	var by_sector: Dictionary = {}
	for cell: Vector2i in reach:
		if float(from_patrol.get(cell, INF)) <= see:
			continue
		var enters: bool = false
		for n: Vector2i in [cell + Vector2i.UP, cell + Vector2i.DOWN, cell + Vector2i.LEFT, cell + Vector2i.RIGHT]:
			if reach.has(n) and float(from_patrol.get(n, INF)) <= see:
				enters = true
		if not enters:
			continue
		var centre: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * grid.cell_m
		var near: Vector2 = nearest_patrol_point(sym, centre)
		var dir: Vector2 = (centre - near).normalized()
		var sector: int = posmod(roundi(atan2(-dir.y, dir.x) / (PI / 4.0)), 8)
		var dist: float = float(reach[cell])
		if not by_sector.has(sector) or dist < float(by_sector[sector][0]):
			by_sector[sector] = [dist, Approach.new(sector, cell, near, near + dir * (see + 0.1))]
	var sectors: Array = by_sector.keys()
	sectors.sort()
	for s: int in sectors:
		out.append(by_sector[s][1])
	return out


## The point of `sym`'s patrol polyline (a loop's closing segment included)
## nearest `p`.
static func nearest_patrol_point(sym: EncounterSymbol, p: Vector2) -> Vector2:
	var path: PackedVector2Array = sym.patrol_path
	if path.size() == 1:
		return path[0]
	var best: Vector2 = path[0]
	var segs: Array = []
	for i in path.size() - 1:
		segs.append([path[i], path[i + 1]])
	if path.size() > 2 and sym.path_mode == SymbolBrain.PathMode.LOOP:
		segs.append([path[path.size() - 1], path[0]])
	for s: Array in segs:
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, s[0], s[1])
		if q.distance_to(p) < best.distance_to(p):
			best = q
	return best


## The walkable cells the patrol polyline passes through (sampled every
## quarter cell), the sources of the walk-grid `see_m` disc.
static func _patrol_cells(sym: EncounterSymbol, grid: WalkGrid) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var path: PackedVector2Array = sym.patrol_path
	var pts: Array[Vector2] = [path[0]]
	for i in path.size() - 1:
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var steps: int = maxi(1, ceili(a.distance_to(b) / (grid.cell_m * 0.25)))
		for k in steps + 1:
			pts.append(a.lerp(b, float(k) / float(steps)))
	for p: Vector2 in pts:
		var c: Vector2i = grid.cell_of(p)
		if grid.is_walkable(c) and not out.has(c):
			out.append(c)
	return out
