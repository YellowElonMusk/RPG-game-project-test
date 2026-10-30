## Checkpoint content rules (GDD rule 10 "No grind blocks" / "On the
## critical path", rule 0 "Requirement source"; story 073, AC-29). Pure
## static; run by `MapValidator.validate_catalog()`. Each error names the
## map and the checkpoint.
##
## - Every checkpoint has exactly one requirement: an item or a flag (the
##   marker has no XP, level or currency field to name).
## - Its `obtained_at` resolves: a gag (`change` response) or NPC marker on
##   a map, a chapter step's ID, or an `encounter` record.
## - On every critical-path leg, a fixed-point search from the leg's start
##   reaches its end, opening a closed checkpoint only once its fight-free
##   source has been reached earlier on the leg: its gag or NPC within
##   `interact_reach_m` of a reached cell, or a chapter step at or before
##   the leg's step that names it. An `encounter` source (a Victory) never
##   counts, with one exception: the region's story encounter's own
##   checkpoint opens once its symbol is reached (rule 13a, the one fight the
##   chapter requires). Every clutter blocker counts as standing (a superset
##   of every reachable stage).
## - No critical-path checkpoint has the `encounter` outcome except the
##   story encounter's.
## - Every return marker lies in a walkable `SAFE` cell and outside every
##   MapExit.
class_name CheckpointRules
extends RefCounted


## `maps` is map_id -> OverworldMap, `records` map_id -> MapData. `catalog`
## is duck-typed (`get_record(type, id)`).
static func check(maps: Dictionary, records: Dictionary, steps: ChapterSteps, catalog: Object,
		cfg: OverworldConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	var sources: Dictionary = _source_ids(maps, steps)
	for map_id: String in maps:
		var map: OverworldMap = maps[map_id]
		var grid: WalkGrid = map.bake_walk_grid(cfg)
		for cp: CheckpointMarker in map.checkpoints():
			var tag: String = "%s: checkpoint '%s'" % [map_id, cp.marker_id]
			if cp.requirement_item_id.is_empty() == cp.requirement_flag.is_empty():
				errors.append("%s needs exactly one requirement (an item or a flag)" % tag)
			if cp.obtained_at.is_empty() or (not sources.has(cp.obtained_at)
					and catalog.call(&"get_record", &"encounter", cp.obtained_at) == null):
				errors.append("%s obtained_at '%s' does not resolve" % [tag, cp.obtained_at])
			var at: Vector2i = grid.cell_of(cp.return_marker)
			if not grid.is_walkable(at) or not grid.is_safe(at):
				errors.append("%s return marker %s is not in a walkable SAFE cell" % [tag, cp.return_marker])
			for exit: MapExit in map.map_exits():
				if exit.trigger_rect.has_point(cp.return_marker):
					errors.append("%s return marker lies inside exit '%s'" % [tag, exit.marker_id])
		var rec: MapData = records.get(map_id) as MapData
		if rec == null:
			continue
		for leg: CriticalPathLeg in rec.critical_path:
			if leg != null:
				errors.append_array(_check_leg(map, rec, leg, steps, cfg))
	return errors


## Marker IDs that can be a fight-free source, plus every step ID.
static func _source_ids(maps: Dictionary, steps: ChapterSteps) -> Dictionary:
	var out: Dictionary = {}
	for map: OverworldMap in maps.values():
		for gag: GagInteractable in map.gags():
			if gag.response == GagInteractable.Response.CHANGE:
				out[String(gag.marker_id)] = true
		for npc: NpcSpawn in map.npc_spawns():
			out[String(npc.marker_id)] = true
	if steps != null:
		for step: ChapterStep in steps.steps:
			out[step.id] = true
	return out


static func _check_leg(map: OverworldMap, rec: MapData, leg: CriticalPathLeg, steps: ChapterSteps,
		cfg: OverworldConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	var tag: String = "%s: leg '%s'" % [rec.id, leg.id]
	var grid: WalkGrid = map.bake_walk_grid(cfg)
	var entry: EntryPoint = map.find_entry_point(leg.from_entry)
	if entry == null:
		return errors  # MapValidator.validate_legs names it
	var goal: Dictionary = BypassSearch._goal_cells(map, grid, leg.to, cfg)
	for gag: GagInteractable in map.gags():
		if gag.blocked_rect.size != Vector2.ZERO:
			grid.set_blocked(MapValidator._cells_in(gag.blocked_rect, grid), true)
	var closed: Array[CheckpointMarker] = []
	for cp: CheckpointMarker in map.checkpoints():
		closed.append(cp)
		grid.set_blocked(OverworldMode.checkpoint_cells(cp, grid), true)
	var step_flags: Dictionary = _flags_by_leg_step(steps, rec.id, leg.id)
	var story: EncounterSymbol = _story_encounter(map)
	var start: Array[Vector2i] = [grid.cell_of(entry.ground_position(map))]
	var reach: Dictionary = MapStructureValidator.walk_distances(grid, start)
	var opened_one: bool = true
	while opened_one:
		opened_one = false
		for cp: CheckpointMarker in closed.duplicate():
			if _source_reached(cp, map, reach, grid, step_flags, story, cfg):
				closed.erase(cp)
				grid.set_blocked(OverworldMode.checkpoint_cells(cp, grid), false)
				reach = MapStructureValidator.walk_distances(grid, start)
				opened_one = true
	if not _hits(reach, goal):
		errors.append("%s: its end '%s' is unreachable without a fight (closed: %s)"
				% [tag, leg.to, ", ".join(closed.map(func(c: CheckpointMarker) -> String: return String(c.marker_id)))])
	# Critical-path checkpoints: the leg's end is unreachable with only it closed.
	for cp: CheckpointMarker in map.checkpoints():
		if cp.failure_outcome != CheckpointMarker.FailureOutcome.ENCOUNTER or _is_story_checkpoint(cp, story):
			continue
		if _critical(map, cp, entry, goal, cfg):
			errors.append("%s: critical-path checkpoint '%s' has the encounter outcome" % [tag, cp.marker_id])
	return errors


## Flags set on or before the step that names this map and leg.
static func _flags_by_leg_step(steps: ChapterSteps, map_id: String, leg_id: String) -> Dictionary:
	var out: Dictionary = {}
	if steps == null:
		return out
	var flags: Dictionary = {}
	var by_id: Dictionary = {}
	for step: ChapterStep in steps.steps:
		for f: String in step.flags_on_enter:
			flags[f] = true
		by_id[step.id] = true
		if step.map_id == map_id and step.leg_id == leg_id:
			out = by_id.duplicate()
			for f: String in flags:
				out["flag:" + f] = true
			return out
	return out


static func _source_reached(cp: CheckpointMarker, map: OverworldMap, reach: Dictionary, grid: WalkGrid,
		step_flags: Dictionary, story: EncounterSymbol, cfg: OverworldConfig) -> bool:
	if _is_story_checkpoint(cp, story):
		return _near_reach(story.patrol_path[0], reach, grid, cfg.interact_reach_m)
	if step_flags.has(cp.obtained_at):
		return true
	for gag: GagInteractable in map.gags():
		if String(gag.marker_id) == cp.obtained_at and gag.response == GagInteractable.Response.CHANGE:
			return _near_reach(gag.ground_position(map), reach, grid, cfg.interact_reach_m)
	for npc: NpcSpawn in map.npc_spawns():
		if String(npc.marker_id) == cp.obtained_at:
			return _near_reach(npc.ground_position(map), reach, grid, cfg.interact_reach_m)
	return false


static func _near_reach(p: Vector2, reach: Dictionary, grid: WalkGrid, radius: float) -> bool:
	for c: Vector2i in reach:
		if grid.cell_center(c).distance_to(p) <= radius + grid.cell_m * 0.5:
			return true
	return false


## The map's story encounter: a Static symbol started on `confirm`.
static func _story_encounter(map: OverworldMap) -> EncounterSymbol:
	for sym: EncounterSymbol in map.symbol_markers():
		if sym.is_static and sym.start_on == EncounterSymbol.StartOn.CONFIRM and not sym.patrol_path.is_empty():
			return sym
	return null


static func _is_story_checkpoint(cp: CheckpointMarker, story: EncounterSymbol) -> bool:
	return story != null and cp.failure_outcome == CheckpointMarker.FailureOutcome.ENCOUNTER \
			and cp.linked_encounter_id == story.encounter_id


static func _critical(map: OverworldMap, cp: CheckpointMarker, entry: EntryPoint, goal: Dictionary,
		cfg: OverworldConfig) -> bool:
	var grid: WalkGrid = map.bake_walk_grid(cfg)
	grid.set_blocked(OverworldMode.checkpoint_cells(cp, grid), true)
	var start: Array[Vector2i] = [grid.cell_of(entry.ground_position(map))]
	return not _hits(MapStructureValidator.walk_distances(grid, start), goal)


static func _hits(reach: Dictionary, goal: Dictionary) -> bool:
	for c: Vector2i in goal:
		if reach.has(c):
			return true
	return false
