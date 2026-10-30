## Rule 19's junction coverage and leg-end beacons (GDD Overworld rule 19
## "Diegetic beacon chain" and "Junctions"; ADR-0012 §3 `validate_maps`;
## story 110, AC-45f). Pure static.
##
## For every leg, at every **reachable configuration** of its map (derived
## from the ChapterFlow step list, never hand-listed: the flags set by each
## step naming the leg, plus the map's `region_liberation_flag` from
## `last_act_from` on, give its occupation stage and which flag-closed exits
## are taped), the leg's junction nodes (its start EntryPoint plus its
## authored `JunctionNode`s) must include:
##
## - **Rooms.** One node in every room the leg's path crosses. A room is a
##   walk-grid component with every checkpoint closed.
## - **Branch cells.** For every other end on the map (each open MapExit,
##   CampSpot and Static symbol other than the leg's own end) reachable from
##   the start, the branch cell: the path cell of greatest arc that also lies
##   on a shortest route from the start to that end. A node must lie within
##   `junction_cover_m` of it. A branch at the start is the EntryPoint's;
##   an end only reached through the leg's own end is no branch.
##
## The path is `L_crit`'s: every cell on some shortest start-to-end route,
## with every checkpoint closed, else the story encounter's open, else all
## open (the leg crosses them). Every leg must also end in a beacon: its
## chain's last `WaypointBeacon` within `junction_cover_m` of the leg's end
## cells. I18 is `OverworldConfig.validate()`'s (run by `validate_maps.gd`).
##
## TODO(overworld): `L_bypass` paths join the check once bypass lanes are
## per stage (BypassSearch has one configuration per map today).
##
## Usage example:
## [codeblock]
## var out: Dictionary = BeaconJunctions.check(steps, records, maps, cfg)
## for err: String in out["errors"]:
##     push_error(err)
## [/codeblock]
class_name BeaconJunctions
extends RefCounted


## `{"errors": PackedStringArray, "assessed": Array[String]}`. `assessed`
## lists each `map:leg@stage` configuration checked (the O-04 denominator).
## `records` is map_id -> MapData, `maps` map_id -> OverworldMap.
static func check(steps: ChapterSteps, records: Dictionary, maps: Dictionary,
		cfg: OverworldConfig) -> Dictionary:
	var errors := PackedStringArray()
	var assessed: Array[String] = []
	var configs: Dictionary = reachable_configs(steps, records)
	for key: String in configs:
		var parts: PackedStringArray = key.split(":")
		var rec: MapData = records.get(parts[0]) as MapData
		var map: OverworldMap = maps.get(parts[0]) as OverworldMap
		var leg: CriticalPathLeg = _leg(rec, parts[1])
		if map == null or leg == null:
			continue  # reported by MapValidator.validate_steps()
		var seen: Dictionary = {}
		for flags: Array in configs[key]:
			var stage: int = int(OccupationStage.compute(rec, func(f: String) -> bool: return flags.has(f), 0)[0])
			for err: String in check_leg(rec, map, leg, flags, stage, cfg):
				if not seen.has(err):
					seen[err] = true
					errors.append(err)
			assessed.append("%s@%d" % [key, stage])
		errors.append_array(check_end_beacon(rec, map, leg, cfg))
	for rec_id: String in maps:
		var rec: MapData = records.get(rec_id) as MapData
		if rec != null:
			errors.append_array(check_marker_legs(rec, maps[rec_id]))
	return {"errors": errors, "assessed": assessed}


## `"map_id:leg_id" -> Array` of flag sets (each an Array of flag names), one
## per step naming the leg: every `flags_on_enter` up to and including that
## step, plus the map's `region_liberation_flag` from `last_act_from` on.
static func reachable_configs(steps: ChapterSteps, records: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var flags: Array = []
	var last_act: bool = false
	for step: ChapterStep in steps.steps:
		if step == null:
			continue
		for f: String in step.flags_on_enter:
			if not flags.has(f):
				flags.append(f)
		last_act = last_act or (not steps.last_act_from.is_empty() and step.id == steps.last_act_from)
		var on: Array = flags.duplicate()
		var rec: MapData = records.get(step.map_id) as MapData
		if last_act and rec != null and not rec.region_liberation_flag.is_empty():
			on.append(rec.region_liberation_flag)
		var key: String = "%s:%s" % [step.map_id, step.leg_id]
		if not out.has(key):
			out[key] = []
		out[key].append(on)
	return out


## Junction-coverage errors for `leg` with `flags` set (its configuration at
## `stage`). Each names the map, leg, stage and cell.
static func check_leg(rec: MapData, map: OverworldMap, leg: CriticalPathLeg, flags: Array,
		stage: int, cfg: OverworldConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	var entry: EntryPoint = map.find_entry_point(leg.from_entry)
	if entry == null:
		return errors  # reported by MapValidator.validate_legs()
	var tag: String = "%s: leg '%s' (stage %d)" % [rec.id, leg.id, stage]
	var closed_exits: Dictionary = {}
	for exit: MapExit in map.map_exits():
		if not exit.closed_when_flag.is_empty() and flags.has(exit.closed_when_flag):
			closed_exits[exit.marker_id] = true
	var rooms_grid: WalkGrid = _grid(map, cfg, closed_exits, null, true)
	var grid: WalkGrid = rooms_grid
	var start: Array[Vector2i] = [grid.cell_of(entry.ground_position(map))]
	var goal: Dictionary = BypassSearch._goal_cells(map, grid, leg.to, cfg)
	var ds: Dictionary = MapStructureValidator.walk_distances(grid, start)
	if not BypassSearch._hits(ds, goal):
		grid = _grid(map, cfg, closed_exits, _story_checkpoint(map), true)
		ds = MapStructureValidator.walk_distances(grid, start)
	if not BypassSearch._hits(ds, goal):
		grid = _grid(map, cfg, closed_exits, null, false)
		ds = MapStructureValidator.walk_distances(grid, start)
	var path: Dictionary = _path(grid, ds, goal)
	if path.is_empty():
		errors.append("%s: no walk-grid route from '%s' to '%s'" % [tag, leg.from_entry, leg.to])
		return errors
	var nodes: Array[Vector2i] = [start[0]]
	for jn: JunctionNode in map.junction_nodes(leg.id):
		nodes.append(grid.cell_of(jn.ground_position(map)))
	# Rooms: one node per room the path crosses.
	var room_of: Dictionary = _rooms(rooms_grid)
	var node_rooms: Dictionary = {}
	for n: Vector2i in nodes:
		if room_of.has(n):
			node_rooms[room_of[n]] = true
	var reported: Dictionary = {}
	for c: Vector2i in _sorted(path.keys()):
		if room_of.has(c) and not node_rooms.has(room_of[c]) and not reported.has(room_of[c]):
			reported[room_of[c]] = true
			errors.append("%s: room at cell %s has no junction node" % [tag, c])
	# Branch cells toward every other end.
	for end: String in other_ends(map, leg.to, closed_exits):
		var cell: Vector2i = branch_cell(map, grid, ds, path, goal, end, cfg)
		if cell != NO_BRANCH and not _covered(grid, nodes, cell, cfg.junction_cover_m):
			errors.append("%s: branch cell %s toward '%s' has no junction node within %.1f m"
					% [tag, cell, end, cfg.junction_cover_m])
	return errors


## No branch cell (the end is unreachable, branches at the start, or lies
## beyond the leg's own end).
const NO_BRANCH: Vector2i = Vector2i(-1, -1)


## The branch cell of `path` toward `end` (see the class doc), or
## `NO_BRANCH`. `ds` holds walk distances from the leg's start on `grid`.
static func branch_cell(map: OverworldMap, grid: WalkGrid, ds: Dictionary, path: Dictionary,
		goal: Dictionary, end: String, cfg: OverworldConfig) -> Vector2i:
	var end_cells: Dictionary = BypassSearch._goal_cells(map, grid, end, cfg)
	var l_end: float = INF
	var targets: Array[Vector2i] = []
	for c: Vector2i in end_cells:
		l_end = minf(l_end, float(ds.get(c, INF)))
		targets.append(c)
	if l_end == INF:
		return NO_BRANCH
	var de: Dictionary = MapStructureValidator.walk_distances(grid, targets)
	var best: Vector2i = NO_BRANCH
	for c: Vector2i in _sorted(path.keys()):
		if de.has(c) and absf(float(ds[c]) + float(de[c]) - l_end) < 1e-3:
			if best == NO_BRANCH or float(ds[c]) > float(ds[best]) + 1e-6:
				best = c
	if best == NO_BRANCH or float(ds[best]) < 1e-6 or goal.has(best):
		return NO_BRANCH
	return best


## Every end on `map` other than `own` and the `closed` exits: MapExit and
## CampSpot `marker_id`s, Static symbol IDs.
static func other_ends(map: OverworldMap, own: String, closed: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for exit: MapExit in map.map_exits():
		if not closed.has(exit.marker_id):
			out.append(String(exit.marker_id))
	for camp: CampSpot in map.camp_spots():
		out.append(String(camp.marker_id))
	for sym: EncounterSymbol in map.symbol_markers():
		if sym.is_static:
			out.append(BypassSearch._sym_key(sym))
	out.erase(own)
	return out


## Errors when `leg` has no beacon, or its chain's last beacon is not within
## `junction_cover_m` of the leg's end cells.
static func check_end_beacon(rec: MapData, map: OverworldMap, leg: CriticalPathLeg,
		cfg: OverworldConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	var chain: Array[WaypointBeacon] = map.beacons(leg.id)
	if chain.is_empty():
		errors.append("%s: leg '%s' has no beacon (rule 19: every leg ends in one)" % [rec.id, leg.id])
		return errors
	var grid: WalkGrid = map.bake_walk_grid(cfg)
	var last: WaypointBeacon = chain[chain.size() - 1]
	var at: Vector2i = grid.cell_of(last.ground_position(map))
	var goal: Dictionary = BypassSearch._goal_cells(map, grid, leg.to, cfg)
	var goal_cells: Array[Vector2i] = []
	for c: Vector2i in goal:
		goal_cells.append(c)
	if not _covered(grid, goal_cells, at, cfg.junction_cover_m):
		errors.append("%s: leg '%s' last beacon '%s' at cell %s is not on its end '%s'"
				% [rec.id, leg.id, last.marker_id, at, leg.to])
	var orders: Dictionary = {}
	for b: WaypointBeacon in chain:
		if orders.has(b.order):
			errors.append("%s: leg '%s' beacon order %d is repeated ('%s')" % [rec.id, leg.id, b.order, b.marker_id])
		orders[b.order] = true
	return errors


## Errors for junction nodes and beacons naming no leg of `rec`.
static func check_marker_legs(rec: MapData, map: OverworldMap) -> PackedStringArray:
	var errors := PackedStringArray()
	var legs: Dictionary = {}
	for leg: CriticalPathLeg in rec.critical_path:
		if leg != null:
			legs[leg.id] = true
	for jn: JunctionNode in map.junction_nodes():
		if not legs.has(jn.leg_id):
			errors.append("%s: junction node '%s' names unknown leg '%s'" % [rec.id, jn.marker_id, jn.leg_id])
	for b: WaypointBeacon in map.beacons():
		if not legs.has(b.leg_id):
			errors.append("%s: beacon '%s' names unknown leg '%s'" % [rec.id, b.marker_id, b.leg_id])
	return errors


static func _leg(rec: MapData, leg_id: String) -> CriticalPathLeg:
	if rec == null:
		return null
	for leg: CriticalPathLeg in rec.critical_path:
		if leg != null and leg.id == leg_id:
			return leg
	return null


static func _story_checkpoint(map: OverworldMap) -> CheckpointMarker:
	for sym: EncounterSymbol in map.symbol_markers():
		if sym.is_static and sym.start_on == EncounterSymbol.StartOn.CONFIRM:
			return map.find_checkpoint(sym.checkpoint_id)
	return null


## The baked grid with the taped exits blocked and, when `close`, every
## checkpoint but `open_cp` closed.
static func _grid(map: OverworldMap, cfg: OverworldConfig, closed_exits: Dictionary,
		open_cp: CheckpointMarker, close: bool) -> WalkGrid:
	var grid: WalkGrid = map.bake_walk_grid(cfg)
	for exit: MapExit in map.map_exits():
		if closed_exits.has(exit.marker_id) and exit.closed_rect.size != Vector2.ZERO:
			grid.set_blocked(MapValidator._cells_in(exit.closed_rect, grid), true)
	if close:
		for cp: CheckpointMarker in map.checkpoints():
			if cp != open_cp:
				grid.set_blocked(OverworldMode.checkpoint_cells(cp, grid), true)
	return grid


## `L_crit`'s path set: cells on some shortest route from the start to `goal`.
static func _path(grid: WalkGrid, ds: Dictionary, goal: Dictionary) -> Dictionary:
	var l_crit: float = INF
	var goal_cells: Array[Vector2i] = []
	for c: Vector2i in goal:
		l_crit = minf(l_crit, float(ds.get(c, INF)))
		goal_cells.append(c)
	var out: Dictionary = {}
	if l_crit == INF:
		return out
	var dg: Dictionary = MapStructureValidator.walk_distances(grid, goal_cells)
	for c: Vector2i in ds:
		if dg.has(c) and absf(float(ds[c]) + float(dg[c]) - l_crit) < 1e-3:
			out[c] = true
	return out


## Cell -> room index (walk-grid components of `grid`).
static func _rooms(grid: WalkGrid) -> Dictionary:
	var out: Dictionary = {}
	var room: int = 0
	for y in grid.size.y:
		for x in grid.size.x:
			var c := Vector2i(x, y)
			if not grid.is_walkable(c) or out.has(c):
				continue
			var from: Array[Vector2i] = [c]
			for r: Vector2i in MapStructureValidator.walk_distances(grid, from):
				out[r] = room
			room += 1
	return out


static func _covered(grid: WalkGrid, nodes: Array[Vector2i], cell: Vector2i, radius: float) -> bool:
	for n: Vector2i in nodes:
		if grid.cell_center(n).distance_to(grid.cell_center(cell)) <= radius + 1e-6:
			return true
	return false


## Cells sorted by row then column (deterministic reports).
static func _sorted(cells: Array) -> Array:
	var out: Array = cells.duplicate()
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out
