## Victory-payoff content rules (GDD rule 7a "Rules for payoffs"; story
## 051, AC-21c). Pure static; run by `MapValidator.validate_catalog()`.
## Over every map with a `density_type` (non-Town, non-boss):
##
## - every patrolling symbol's record names a `victory_payoff`;
## - at least one `open` payoff leads to an optional pocket, or (on a map
##   holding the story encounter) a shortcut;
## - at least half the patrolling symbols carry `clue` or `open`;
## - `none` on at most floor(N / 3) symbols, never on a Static symbol, never
##   on the first symbol along the map's first critical-path leg;
## - each payoff's tell lies within `R_vis` of a vertex of the symbol's
##   patrol: its gate for `open`, a `payoff_tell` prop for `clue` / `item`;
## - no `item` payoff meets a critical-path checkpoint's requirement;
## - each pocket (the cells an `open` gate adds to what the map's entries
##   reach) holds a `change` gag and a recruit remark or a clue facet; a
##   gate that adds no cells is a shortcut, which must shorten the walk from
##   a CampSpot to some MapExit.
##
## Region-wide: no two `clue` payoffs share a facet, and none repeats the
## first-encounter poster's facet (a `faction_clue` gag's `rumour_id`, with
## any `rumour_` prefix dropped). Reference resolution is story 078's.
class_name PayoffRules
extends RefCounted


## `maps` is map_id -> OverworldMap, `records` map_id -> MapData; `catalog`
## is duck-typed (`get_record(type, id)`).
static func check(maps: Dictionary, records: Dictionary, catalog: Object, cfg: OverworldConfig,
		presentation: PresentationConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	var radius: float = ChaseVisibility.r_vis(presentation, cfg.walk_speed)
	var facets: Dictionary = {}  # facet -> "map: symbol"
	var poster_facets: Dictionary = {}
	for map: OverworldMap in maps.values():
		for gag: GagInteractable in map.gags():
			if gag.faction_clue and not gag.rumour_id.is_empty():
				poster_facets[gag.rumour_id.trim_prefix("rumour_")] = true
	for map_id: String in maps:
		var rec: MapData = records.get(map_id) as MapData
		var map: OverworldMap = maps[map_id]
		var tag: String = map_id
		if rec == null or rec.density_type.is_empty():
			continue
		var first_symbol: String = ""
		if not rec.critical_path.is_empty() and rec.critical_path[0] != null:
			first_symbol = MapValidator.first_encounter_metrics(map, rec.critical_path[0], cfg)["first_symbol"]
		var n: int = 0
		var clue_or_open: int = 0
		var nones: int = 0
		var good_open: int = 0
		for sym: EncounterSymbol in map.symbol_markers():
			var sid: String = sym.symbol_id if not sym.symbol_id.is_empty() else sym.encounter_id
			var enc: EncounterData = catalog.call(&"get_record", &"encounter", sym.encounter_id) as EncounterData
			if enc == null:
				continue  # story 078 names it
			var p: Dictionary = enc.victory_payoff
			var type: String = String(p.get("type", ""))
			if sym.is_static:
				if type == "none":
					errors.append("%s: Static symbol '%s' has a `none` payoff" % [tag, sid])
				continue
			n += 1
			match type:
				"":
					errors.append("%s: symbol '%s' (%s) names no victory_payoff" % [tag, sid, enc.id])
				"none":
					nones += 1
					if sid == first_symbol:
						errors.append("%s: the first symbol along the critical path, '%s', has a `none` payoff" % [tag, sid])
				"clue":
					clue_or_open += 1
					var facet: String = String(p.get("facet", ""))
					if poster_facets.has(facet):
						errors.append("%s: '%s' clue facet '%s' repeats the first-encounter poster" % [tag, sid, facet])
					if facets.has(facet):
						errors.append("%s: '%s' clue facet '%s' repeats %s" % [tag, sid, facet, facets[facet]])
					facets[facet] = "%s: %s" % [tag, sid]
					_check_prop_tell(map, sym, sid, radius, tag, errors)
				"item":
					_check_prop_tell(map, sym, sid, radius, tag, errors)
					var item_id: String = String(p.get("item_id", ""))
					for cp: CheckpointMarker in _critical_checkpoints(map, rec, cfg):
						if cp.requirement_item_id == item_id:
							errors.append("%s: '%s' item '%s' meets critical-path checkpoint '%s'"
									% [tag, sid, item_id, cp.marker_id])
				"open":
					clue_or_open += 1
					var cp: CheckpointMarker = map.find_checkpoint(StringName(String(p.get("checkpoint", ""))))
					if cp == null:
						continue  # story 078 names it
					if _nearest_vertex(sym, cp.blocked_rect.get_center()) > radius:
						errors.append("%s: '%s' gate '%s' is beyond R_vis %.2f of its patrol" % [tag, sid, cp.marker_id, radius])
					var verdict: String = _pocket_or_shortcut(map, cp, cfg)
					if verdict.is_empty():
						good_open += 1
					else:
						errors.append("%s: '%s' gate '%s' %s" % [tag, sid, cp.marker_id, verdict])
		if n == 0:
			continue
		if good_open == 0:
			errors.append("%s: no `open` payoff leads to an optional pocket or a shortcut" % tag)
		if clue_or_open * 2 < n:
			errors.append("%s: only %d of %d patrolling symbols carry `clue` or `open`" % [tag, clue_or_open, n])
		if nones > n / 3:
			errors.append("%s: %d `none` payoffs (at most %d for %d symbols)" % [tag, nones, n / 3, n])
	return errors


## A `clue` / `item` tell: a gag naming the symbol in `payoff_tell`, within
## `radius` of a patrol vertex.
static func _check_prop_tell(map: OverworldMap, sym: EncounterSymbol, sid: String, radius: float,
		tag: String, errors: PackedStringArray) -> void:
	for gag: GagInteractable in map.gags():
		if gag.payoff_tell == sid and _nearest_vertex(sym, gag.ground_position(map)) <= radius:
			return
	errors.append("%s: '%s' has no payoff tell within R_vis %.2f of its patrol" % [tag, sid, radius])


static func _nearest_vertex(sym: EncounterSymbol, p: Vector2) -> float:
	var best: float = INF
	for v: Vector2 in sym.patrol_path:
		best = minf(best, v.distance_to(p))
	return best


## "" when `cp` opens a valid pocket or shortcut, else why not.
static func _pocket_or_shortcut(map: OverworldMap, cp: CheckpointMarker, cfg: OverworldConfig) -> String:
	var closed: WalkGrid = _grid_with(map, cfg, null)
	var opened: WalkGrid = _grid_with(map, cfg, cp)
	var starts: Array[Vector2i] = []
	for entry: EntryPoint in map.entry_points():
		starts.append(closed.cell_of(entry.ground_position(map)))
	var before: Dictionary = MapStructureValidator.walk_distances(closed, starts)
	var after: Dictionary = MapStructureValidator.walk_distances(opened, starts)
	var pocket: Dictionary = {}
	for c: Vector2i in after:
		if not before.has(c) and not OverworldMode.checkpoint_cells(cp, opened).has(c):
			pocket[c] = true
	if not pocket.is_empty():
		var change: bool = false
		var extra: bool = false
		for gag: GagInteractable in map.gags():
			if not pocket.has(opened.cell_of(gag.ground_position(map))):
				continue
			if gag.response == GagInteractable.Response.CHANGE:
				change = true
				extra = extra or not gag.recruit_remark.is_empty()
			elif gag.response == GagInteractable.Response.CLUE and not gag.rumour_id.is_empty():
				extra = true
		if not change or not extra:
			return "opens a pocket without a `change` gag plus a recruit remark or clue facet"
		return ""
	# No new cells: a shortcut, only with the story encounter, and only if it
	# shortens a camp's walk to an exit.
	var story: bool = false
	for sym: EncounterSymbol in map.symbol_markers():
		story = story or (sym.is_static and sym.start_on == EncounterSymbol.StartOn.CONFIRM)
	if not story:
		return "opens neither a pocket nor (on a dungeon) a shortcut"
	for camp: CampSpot in map.camp_spots():
		var from: Array[Vector2i] = [closed.cell_of(camp.ground_position(map))]
		var d0: Dictionary = MapStructureValidator.walk_distances(closed, from)
		var d1: Dictionary = MapStructureValidator.walk_distances(opened, from)
		for exit: MapExit in map.map_exits():
			var best0: float = INF
			var best1: float = INF
			for c: Vector2i in MapValidator._cells_in(exit.trigger_rect, closed):
				best0 = minf(best0, float(d0.get(c, INF)))
				best1 = minf(best1, float(d1.get(c, INF)))
			if best1 < best0 - 1e-6:
				return ""
	return "is a shortcut that shortens no camp's walk to an exit"


## The baked grid with every checkpoint closed except the story
## encounter's (opened, as after the Counter falls) and `open_cp`.
static func _grid_with(map: OverworldMap, cfg: OverworldConfig, open_cp: CheckpointMarker) -> WalkGrid:
	var grid: WalkGrid = map.bake_walk_grid(cfg)
	var story_cp: StringName = &""
	for sym: EncounterSymbol in map.symbol_markers():
		if sym.is_static and sym.start_on == EncounterSymbol.StartOn.CONFIRM:
			story_cp = sym.checkpoint_id
	for cp: CheckpointMarker in map.checkpoints():
		if cp != open_cp and cp.marker_id != story_cp:
			grid.set_blocked(OverworldMode.checkpoint_cells(cp, grid), true)
	return grid


## Checkpoints whose closing alone cuts one of `rec`'s legs.
static func _critical_checkpoints(map: OverworldMap, rec: MapData, cfg: OverworldConfig) -> Array[CheckpointMarker]:
	var out: Array[CheckpointMarker] = []
	for cp: CheckpointMarker in map.checkpoints():
		for leg: CriticalPathLeg in rec.critical_path:
			var entry: EntryPoint = map.find_entry_point(leg.from_entry) if leg != null else null
			if entry == null:
				continue
			var grid: WalkGrid = map.bake_walk_grid(cfg)
			if CheckpointRules._critical(map, cp, entry, BypassSearch._goal_cells(map, grid, leg.to, cfg), cfg):
				out.append(cp)
				break
	return out
