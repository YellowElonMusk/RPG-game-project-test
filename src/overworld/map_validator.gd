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

## Where lighting profiles resolve (ADR-0005 §5; `PresentationDirector`).
const LIGHTING_PROFILE_DIR: String = "res://data/presentation/profiles"


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
	var records: Dictionary = {}
	for rec: Resource in catalog.all_records(&"map"):
		if rec is MapData:
			records[String(rec.get("id"))] = rec
	var steps: ChapterSteps = null
	if ResourceLoader.exists(cfg.chapter_steps_path):
		steps = ResourceLoader.load(cfg.chapter_steps_path) as ChapterSteps
	if steps == null:
		errors.append("chapter steps: no ChapterSteps at %s" % cfg.chapter_steps_path)
	else:
		errors.append_array(validate_steps(steps, records))
		errors.append_array(validate_last_act(steps, records, maps, cfg))
	var registry: StoryFlagRegistry = null
	if ResourceLoader.exists(cfg.flag_registry_path):
		registry = ResourceLoader.load(cfg.flag_registry_path) as StoryFlagRegistry
	errors.append_array(check_references(maps, catalog, registry))
	errors.append_array(CheckpointRules.check(maps, records, steps, catalog, cfg))
	errors.append_array(check_clutter_placement(maps, cfg, PresentationConfig.new()))
	errors.append_array(check_reaction_sets(steps, maps))
	if steps != null:
		errors.append_array(WalkBudget.compute(steps, records, maps, cfg)["errors"])
	errors.append_array(check_first_encounter(steps, records, maps, cfg))
	for rec: Resource in catalog.all_records(&"map"):
		var rec_map: OverworldMap = maps.get(String(rec.get("id"))) as OverworldMap
		if rec_map != null and rec is MapData:
			errors.append_array(validate_legs(rec as MapData, rec_map))
			errors.append_array(BypassSearch.check(rec as MapData, rec_map, cfg))
			errors.append_array(BypassSearch.check_pressure(rec as MapData, rec_map, cfg))
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
		errors.append_array(check_no_physics(map_id, map))
	return errors


## Physics node classes a shipped map may not contain (ADR-0012: no
## physics engine; story 079). `CSGShape3D` is banned outright (bake it to
## a `MeshInstance3D`).
const BANNED_PHYSICS_CLASSES: Array[String] = [
	"CollisionObject3D", "CollisionObject2D", "SoftBody3D", "RayCast3D", "ShapeCast3D",
	"RayCast2D", "ShapeCast2D", "SpringArm3D", "Joint3D", "Joint2D",
	"PhysicalBoneSimulator3D", "CSGShape3D",
]


## Story 079 (AC-30e): no node of a `BANNED_PHYSICS_CLASSES` class (or a
## subclass) under `map`; every `GridMap` has collision layer and mask 0
## and no item shapes; every `TileMapLayer` has `collision_enabled` off.
static func check_no_physics(map_id: String, map: Node) -> PackedStringArray:
	var errors := PackedStringArray()
	var nodes: Array[Node] = [map]
	nodes.append_array(map.find_children("*", "", true, false))
	for node: Node in nodes:
		for cls: String in BANNED_PHYSICS_CLASSES:
			if node.is_class(cls):
				errors.append("%s: node %s is a %s (no physics nodes in shipped maps)"
						% [map_id, map.get_path_to(node), cls])
				break
		if node is GridMap:
			var gm: GridMap = node
			if gm.collision_layer != 0 or gm.collision_mask != 0:
				errors.append("%s: GridMap %s has collision_layer/mask set" % [map_id, map.get_path_to(node)])
			if gm.mesh_library != null:
				for item: int in gm.mesh_library.get_item_list():
					if not gm.mesh_library.get_item_shapes(item).is_empty():
						errors.append("%s: GridMap %s item %d has collision shapes"
								% [map_id, map.get_path_to(node), item])
		if node is TileMapLayer and (node as TileMapLayer).collision_enabled:
			errors.append("%s: TileMapLayer %s has collision_enabled on" % [map_id, map.get_path_to(node)])
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


## Story 074, AC-30a (GDD rule 0): every chapter step names an existing
## `map_` record and a `critical_path` leg on it, with unique step IDs.
static func validate_steps(steps: ChapterSteps, records: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary = {}
	for step: ChapterStep in steps.steps:
		if step == null:
			errors.append("%s: an empty step" % steps.chapter_id)
			continue
		if step.id.is_empty() or seen.has(step.id):
			errors.append("%s: step id '%s' is empty or repeated" % [steps.chapter_id, step.id])
		seen[step.id] = true
		var rec: MapData = records.get(step.map_id) as MapData
		if rec == null:
			errors.append("%s: step '%s' names unknown map '%s'" % [steps.chapter_id, step.id, step.map_id])
			continue
		var found: bool = false
		for leg: CriticalPathLeg in rec.critical_path:
			found = found or (leg != null and leg.id == step.leg_id)
		if not found:
			errors.append("%s: step '%s' names leg '%s', which %s does not have"
					% [steps.chapter_id, step.id, step.leg_id, step.map_id])
	return errors


## Story 069 (AC-27e, rule 17): every map a last-act step (from
## `steps.last_act_from` on) names has a `liberated_profile_id` and a
## `liberated_kit_id` that each resolve. With its `region_liberation_flag`
## set, its flag-closed exits taped, no EntryPoint on it can walk to an exit
## that leads off the last act's maps (the dungeon and boss chamber are
## closed behind the squad, rule 13). `maps` is map_id -> OverworldMap.
static func validate_last_act(steps: ChapterSteps, records: Dictionary, maps: Dictionary,
		cfg: OverworldConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	if steps.last_act_from.is_empty():
		return errors
	var act: Dictionary = {}
	var started: bool = false
	for step: ChapterStep in steps.steps:
		started = started or (step != null and step.id == steps.last_act_from)
		if started and step != null:
			act[step.map_id] = true
	if not started:
		errors.append("%s: last_act_from names unknown step '%s'" % [steps.chapter_id, steps.last_act_from])
		return errors
	for map_id: String in act:
		var rec: MapData = records.get(map_id) as MapData
		if rec == null:
			continue
		if rec.liberated_profile_id.is_empty() or not ResourceLoader.exists(
				"%s/%s.tres" % [LIGHTING_PROFILE_DIR, rec.liberated_profile_id]):
			errors.append("%s: liberated_profile_id '%s' does not resolve" % [map_id, rec.liberated_profile_id])
		if SetKit.resolve(rec.liberated_kit_id) == null:
			errors.append("%s: liberated_kit_id '%s' does not resolve" % [map_id, rec.liberated_kit_id])
		var map: OverworldMap = maps.get(map_id) as OverworldMap
		if map == null:
			continue
		var grid: WalkGrid = map.bake_walk_grid(cfg)
		for exit: MapExit in map.map_exits():
			if exit.closed_when_flag == rec.region_liberation_flag and not exit.closed_when_flag.is_empty():
				grid.set_blocked(_cells_in(exit.closed_rect, grid), true)
		var starts: Array[Vector2i] = []
		for entry: EntryPoint in map.entry_points():
			starts.append(grid.cell_of(entry.ground_position(map)))
		var reach: Dictionary = MapStructureValidator.walk_distances(grid, starts)
		for exit: MapExit in map.map_exits():
			if act.has(exit.target_map_id):
				continue
			for c: Vector2i in _cells_in(exit.trigger_rect, grid):
				if reach.has(c):
					errors.append("%s: liberated, exit %s to %s is still reachable"
							% [map_id, exit.marker_id, exit.target_map_id])
					break
	return errors


static func _cells_in(r: Rect2, grid: WalkGrid) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(floori(r.position.y / grid.cell_m), ceili(r.end.y / grid.cell_m)):
		for x in range(floori(r.position.x / grid.cell_m), ceili(r.end.x / grid.cell_m)):
			out.append(Vector2i(x, y))
	return out


## Story 078 (AC-30d): every reference a map's markers and their encounter
## records make resolves, with one named error per broken reference:
## symbol `encounter_id`s (records) and symbol IDs (unique per map); gag
## `liberate_symbol` and `decree_first_sight` (symbols on the map),
## `liberation_flag` (registry), `decree_stage` (a registered flag in the
## map record's `stage_table` raises to it); checkpoint
## `requirement_item_id` (item records), `requirement_flag` (registry),
## `linked_encounter_id` (records); and each placed encounter's
## `victory_payoff` (a known type; `open` names a checkpoint on the map,
## `item` an item record, `clue` a facet). `catalog` is duck-typed
## (`get_record(type, id)`). No marker has a `recruit_remark` field yet.
static func check_references(maps: Dictionary, catalog: Object,
		registry: StoryFlagRegistry) -> PackedStringArray:
	var errors := PackedStringArray()
	for map_id: String in maps:
		var map: OverworldMap = maps[map_id]
		var map_rec: MapData = catalog.call(&"get_record", &"map", map_id) as MapData
		var symbols: Dictionary = {}
		var placed: Dictionary = {}
		for sym: EncounterSymbol in map.symbol_markers():
			var sid: String = sym.symbol_id if not sym.symbol_id.is_empty() else sym.encounter_id
			if symbols.has(sid):
				errors.append("%s: symbol '%s' is not unique" % [map_id, sid])
			symbols[sid] = true
			if catalog.call(&"get_record", &"encounter", sym.encounter_id) == null:
				errors.append("%s: symbol '%s' encounter_id '%s' does not resolve" % [map_id, sid, sym.encounter_id])
			else:
				placed[sym.encounter_id] = true
		var checkpoints: Dictionary = {}
		for cp: CheckpointMarker in map.checkpoints():
			checkpoints[String(cp.marker_id)] = true
			if not cp.requirement_item_id.is_empty() \
					and catalog.call(&"get_record", &"item", cp.requirement_item_id) == null:
				errors.append("%s: checkpoint '%s' requirement_item_id '%s' does not resolve"
						% [map_id, cp.marker_id, cp.requirement_item_id])
			if not cp.requirement_flag.is_empty() and not _registered(registry, cp.requirement_flag):
				errors.append("%s: checkpoint '%s' requirement_flag '%s' is not registered"
						% [map_id, cp.marker_id, cp.requirement_flag])
			if not cp.linked_encounter_id.is_empty() \
					and catalog.call(&"get_record", &"encounter", cp.linked_encounter_id) == null:
				errors.append("%s: checkpoint '%s' linked_encounter_id '%s' does not resolve"
						% [map_id, cp.marker_id, cp.linked_encounter_id])
		for gag: GagInteractable in map.gags():
			if not gag.liberate_symbol.is_empty() and not symbols.has(gag.liberate_symbol):
				errors.append("%s: gag '%s' liberate_symbol '%s' is no symbol on the map"
						% [map_id, gag.marker_id, gag.liberate_symbol])
			if not gag.liberation_flag.is_empty() and not _registered(registry, gag.liberation_flag):
				errors.append("%s: gag '%s' liberation_flag '%s' is not registered"
						% [map_id, gag.marker_id, gag.liberation_flag])
			if not gag.decree_first_sight.is_empty() and not symbols.has(gag.decree_first_sight):
				errors.append("%s: decree gag '%s' decree_first_sight '%s' is no symbol on the map"
						% [map_id, gag.marker_id, gag.decree_first_sight])
			if gag.decree_stage > 0 and not _raised_by_registered_flag(map_rec, gag.decree_stage, registry):
				errors.append("%s: decree gag '%s' decree_stage %d has no registered raising flag"
						% [map_id, gag.marker_id, gag.decree_stage])
		for enc_id: String in placed:
			var rec: EncounterData = catalog.call(&"get_record", &"encounter", enc_id) as EncounterData
			var p: Dictionary = rec.victory_payoff
			if p.is_empty():
				continue
			var type: String = String(p.get("type", ""))
			match type:
				"none":
					pass
				"clue":
					if String(p.get("facet", "")).is_empty():
						errors.append("%s: %s victory_payoff clue names no facet" % [map_id, enc_id])
				"open":
					if not checkpoints.has(String(p.get("checkpoint", ""))):
						errors.append("%s: %s victory_payoff opens '%s', no checkpoint on the map"
								% [map_id, enc_id, p.get("checkpoint", "")])
				"item":
					if catalog.call(&"get_record", &"item", String(p.get("item_id", ""))) == null:
						errors.append("%s: %s victory_payoff item_id '%s' does not resolve"
								% [map_id, enc_id, p.get("item_id", "")])
				_:
					errors.append("%s: %s victory_payoff type '%s' is unknown" % [map_id, enc_id, type])
	return errors


static func _registered(registry: StoryFlagRegistry, flag: String) -> bool:
	return registry != null and registry.has_flag(flag)


static func _raised_by_registered_flag(rec: MapData, stage: int, registry: StoryFlagRegistry) -> bool:
	if rec == null:
		return false
	for flag: String in rec.stage_table:
		if rec.stage_table[flag] >= stage and _registered(registry, flag):
			return true
	return false


## Story 064 (AC-26c, rule 9 "Placement"): a clutter marker naming a
## `liberate_symbol` lies within `R_vis` (the shipped camera's) of at least
## one vertex of that symbol's patrol, so winning shows its result. Symbols
## carry no stage gate (every placed symbol is active at every stage until
## the region is liberated, which frees the marker too), so the "active at
## every stage the marker is" half holds whenever the symbol is on the map;
## a missing symbol is story 078's error.
static func check_clutter_placement(maps: Dictionary, cfg: OverworldConfig,
		presentation: PresentationConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	var radius: float = ChaseVisibility.r_vis(presentation, cfg.walk_speed)
	for map_id: String in maps:
		var map: OverworldMap = maps[map_id]
		for gag: GagInteractable in map.gags():
			if gag.liberate_symbol.is_empty():
				continue
			for sym: EncounterSymbol in map.symbol_markers():
				var sid: String = sym.symbol_id if not sym.symbol_id.is_empty() else sym.encounter_id
				if sid != gag.liberate_symbol:
					continue
				var nearest: float = INF
				for v: Vector2 in sym.patrol_path:
					nearest = minf(nearest, v.distance_to(gag.ground_position(map)))
				if nearest > radius:
					errors.append("%s: clutter '%s' is %.2f m from %s's patrol (R_vis %.2f)"
							% [map_id, gag.marker_id, nearest, sid, radius])
	return errors


## Story 063 (AC-26e, rule 9): each last-act map's liberation reaction set
## (its `liberated_role` markers) has at least one entry tagged
## `ribs_squad`. Presence only; AC-51 checks the line really ribs the squad.
static func check_reaction_sets(steps: ChapterSteps, maps: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if steps == null or steps.last_act_from.is_empty():
		return errors
	var started: bool = false
	var act: Dictionary = {}
	for step: ChapterStep in steps.steps:
		started = started or (step != null and step.id == steps.last_act_from)
		if started and step != null:
			act[step.map_id] = true
	for map_id: String in act:
		var map: OverworldMap = maps.get(map_id) as OverworldMap
		if map == null:
			continue
		var ribs: bool = false
		for npc: NpcSpawn in map.npc_spawns():
			ribs = ribs or (not npc.liberated_role.is_empty() and npc.ribs_squad)
		for gag: GagInteractable in map.gags():
			ribs = ribs or (not gag.liberated_role.is_empty() and gag.ribs_squad)
		if not ribs:
			errors.append("%s: no liberation reaction is tagged ribs_squad" % map_id)
	return errors


## Stories 086 and 119 (GDD rules 12 "First patrol", 16): measurements along
## `leg`'s `L_crit` on the first-encounter map. The path set is every cell on
## some shortest route (distance from the start plus distance to the end
## equals `L_crit`); a cell's arc is its walk distance from the leg's start
## EntryPoint. Returns `l_crit`, `first_notice` (arc of the first path cell
## within `symbol_chase_m` of any patrol), `first_patrol` (arc of the path
## cell nearest the first patrol's path), `clue` and `teach` (arcs of the
## first path cell within reach of a `faction_clue` gag / `optional_teach`
## NPC; INF when none), `section_ratio` (the first patrol's band section:
## `L_bypass / L_crit` from the last path cell before its band to the first
## after it) and `first_symbol`.
static func first_encounter_metrics(map: OverworldMap, leg: CriticalPathLeg, cfg: OverworldConfig) -> Dictionary:
	var out: Dictionary = {"l_crit": INF, "first_notice": INF, "first_patrol": INF, "clue": INF,
			"teach": INF, "section_ratio": INF, "first_symbol": ""}
	var entry: EntryPoint = map.find_entry_point(leg.from_entry)
	if entry == null:
		return out
	var grid: WalkGrid = map.bake_walk_grid(cfg)
	for cp: CheckpointMarker in map.checkpoints():
		grid.set_blocked(OverworldMode.checkpoint_cells(cp, grid), true)
	var start: Array[Vector2i] = [grid.cell_of(entry.ground_position(map))]
	var goal: Dictionary = BypassSearch._goal_cells(map, grid, leg.to, cfg)
	var ds: Dictionary = MapStructureValidator.walk_distances(grid, start)
	var goal_cells: Array[Vector2i] = []
	for c: Vector2i in goal:
		goal_cells.append(c)
	var dg: Dictionary = MapStructureValidator.walk_distances(grid, goal_cells)
	var l_crit: float = INF
	for c: Vector2i in goal:
		l_crit = minf(l_crit, float(ds.get(c, INF)))
	out["l_crit"] = l_crit
	if l_crit == INF:
		return out
	var path: Array[Vector2i] = []
	for c: Vector2i in ds:
		if dg.has(c) and absf(float(ds[c]) + float(dg[c]) - l_crit) < 1e-3:
			path.append(c)
	# The first patrol: the patrolling symbol whose path comes nearest the
	# leg earliest (smallest arc of a path cell within its notice radius).
	var first: EncounterSymbol = null
	for sym: EncounterSymbol in map.symbol_markers():
		if sym.is_static or sym.patrol_path.is_empty():
			continue
		for c: Vector2i in path:
			if _patrol_distance(sym, grid.cell_center(c)) <= cfg.symbol_chase_m \
					and float(ds[c]) < float(out["first_notice"]):
				out["first_notice"] = float(ds[c])
				first = sym
	if first != null:
		out["first_symbol"] = first.symbol_id if not first.symbol_id.is_empty() else first.encounter_id
		var nearest: float = INF
		for c: Vector2i in path:
			var d: float = _patrol_distance(first, grid.cell_center(c))
			if d < nearest - 1e-6 or (absf(d - nearest) < 1e-6 and float(ds[c]) < float(out["first_patrol"])):
				nearest = d
				out["first_patrol"] = float(ds[c])
		# Its section: the last path cell before its band to the first after.
		var band: Dictionary = {}
		for c: Vector2i in BypassSearch._band_cells(map, first, cfg):
			band[c] = true
		var band_lo: float = INF
		var band_hi: float = -INF
		for c: Vector2i in path:
			if band.has(c):
				band_lo = minf(band_lo, float(ds[c]))
				band_hi = maxf(band_hi, float(ds[c]))
		var s0: Vector2i = Vector2i(-1, -1)
		var s1: Vector2i = Vector2i(-1, -1)
		for c: Vector2i in path:
			if band.has(c):
				continue
			var a: float = float(ds[c])
			if a < band_lo and (s0 == Vector2i(-1, -1) or a > float(ds[s0])):
				s0 = c
			if a > band_hi and (s1 == Vector2i(-1, -1) or a < float(ds[s1])):
				s1 = c
		if s0 != Vector2i(-1, -1) and s1 != Vector2i(-1, -1):
			var section_crit: float = float(ds[s1]) - float(ds[s0])
			var banded: WalkGrid = map.bake_walk_grid(cfg)
			for cp: CheckpointMarker in map.checkpoints():
				banded.set_blocked(OverworldMode.checkpoint_cells(cp, banded), true)
			banded.set_blocked(BypassSearch._band_cells(map, first, cfg), true)
			var from: Array[Vector2i] = [s0]
			var bypass: float = float(MapStructureValidator.walk_distances(banded, from).get(s1, INF))
			out["section_ratio"] = bypass / section_crit if section_crit > 0.0 else INF
	for gag: GagInteractable in map.gags():
		if gag.faction_clue:
			for c: Vector2i in path:
				if grid.cell_center(c).distance_to(gag.ground_position(map)) <= cfg.interact_reach_m + grid.cell_m * 0.5:
					out["clue"] = minf(float(out["clue"]), float(ds[c]))
	for npc: NpcSpawn in map.npc_spawns():
		if npc.optional_teach and npc.liberated_role.is_empty():
			for c: Vector2i in path:
				if grid.cell_center(c).distance_to(npc.ground_position(map)) <= 2.0 * cfg.interact_reach_m + grid.cell_m * 0.5:
					out["teach"] = minf(float(out["teach"]), float(ds[c]))
	return out


## Distance from `p` to `sym`'s patrol polyline (a loop's closing segment
## included).
static func _patrol_distance(sym: EncounterSymbol, p: Vector2) -> float:
	var pts: PackedVector2Array = sym.patrol_path
	if pts.size() == 1:
		return p.distance_to(pts[0])
	var best: float = INF
	var n: int = pts.size()
	var segs: int = n if sym.path_mode == SymbolBrain.PathMode.LOOP and n > 2 else n - 1
	for i: int in segs:
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, pts[i], pts[(i + 1) % n])
		best = minf(best, q.distance_to(p))
	return best


## Stories 086 and 119 (AC-31c, AC-50; GDD rules 12, 16): for each faction,
## its first-encounter map is the map of the first chapter step whose map
## holds a patrolling symbol of that faction's map record. Along that
## step's leg (`first_encounter_metrics`): the first patrol is at least
## `safe_radius_m + symbol_chase_m + first_patrol_clearance_m` along
## `L_crit`; a `faction_clue` marker and the `optional_teach` speaker (an
## NPC: a proximity bark, never a confirm-only gag) come before the first
## notice point; the first patrol's section has `L_bypass / L_crit <=
## first_bypass_ratio_max`.
static func check_first_encounter(steps: ChapterSteps, records: Dictionary, maps: Dictionary,
		cfg: OverworldConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	if steps == null:
		return errors
	var seen: Dictionary = {}
	for step: ChapterStep in steps.steps:
		var rec: MapData = records.get(step.map_id) as MapData
		var map: OverworldMap = maps.get(step.map_id) as OverworldMap
		if rec == null or map == null or seen.has(rec.faction_id):
			continue
		var patrols: bool = false
		for sym: EncounterSymbol in map.symbol_markers():
			patrols = patrols or (not sym.is_static and not sym.patrol_path.is_empty())
		if not patrols:
			continue
		seen[rec.faction_id] = true
		var leg: CriticalPathLeg = null
		for l: CriticalPathLeg in rec.critical_path:
			if l != null and l.id == step.leg_id:
				leg = l
		if leg == null:
			continue
		var m: Dictionary = first_encounter_metrics(map, leg, cfg)
		var tag: String = "%s: first-encounter leg '%s'" % [rec.id, leg.id]
		var clearance: float = cfg.safe_radius_m + cfg.symbol_chase_m + cfg.first_patrol_clearance_m
		if float(m["first_patrol"]) < clearance:
			errors.append("%s: first patrol %s is %.1f m along L_crit (< %.1f)"
					% [tag, m["first_symbol"], m["first_patrol"], clearance])
		if not float(m["clue"]) < float(m["first_notice"]):
			errors.append("%s: no faction_clue marker before the first notice point (%.1f m)" % [tag, m["first_notice"]])
		if not float(m["teach"]) < float(m["first_notice"]):
			errors.append("%s: no optional_teach speaker before the first notice point (%.1f m)" % [tag, m["first_notice"]])
		if float(m["section_ratio"]) > cfg.first_bypass_ratio_max:
			errors.append("%s: first patrol's section bypass ratio %.2f > first_bypass_ratio_max %.2f"
					% [tag, m["section_ratio"], cfg.first_bypass_ratio_max])
	return errors
