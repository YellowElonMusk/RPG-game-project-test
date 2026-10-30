## Story 117, AC-49 (GDD rule 16, Player Fantasy guardrail 4): on every
## shipped map at every reachable stage, every active clutter marker either
## responds to `confirm` (a `gag` with a usable response) or blocks a route
## on the baked `WalkGrid`. Pure static; run by `MapValidator.validate_catalog()`.
##
## A clutter marker is a `GagInteractable` with a `clutter_kind` or a
## liberation link (`is_liberatable()`), excluding decree gags and
## liberated-set content (rule 9). "Active" is `marker_activation`'s
## `visible(m)` at the map's stage: slotted within its kind's cap, not
## liberated (a `liberation_flag` already set counts), and the map not
## region-liberated. A Victory's liberation is not assumed, so every
## not-yet-liberated marker is checked (the worst case).
##
## Reachable stages come from the ChapterFlow step list (test plan O-04),
## never a hand list: per step, the flags set so far (plus the map's
## `region_liberation_flag` from `last_act_from` on) through
## `OccupationStage.compute()`.
##
## Usage example:
## [codeblock]
## var out: Dictionary = ClutterResponseCheck.check(steps, records, maps, stage_records, cfg)
## for err: String in out["errors"]: printerr(err)
## [/codeblock]
class_name ClutterResponseCheck
extends RefCounted


## Returns `{assessed: Array[String], checked: Array[String], errors:
## PackedStringArray}`. `assessed` holds one `"map_id@stage"` (suffix
## `+liberated` when region-liberated) per reachable configuration; `checked`
## one `"map_id:marker_id@stage"` per active marker examined. Each error
## names the map, marker and stage. `maps` is map_id -> OverworldMap,
## `records` map_id -> MapData, `stage_records` the `occupation_stage`
## records (for the clutter caps).
static func check(steps: ChapterSteps, records: Dictionary, maps: Dictionary,
		stage_records: Array, cfg: OverworldConfig) -> Dictionary:
	var assessed: Array[String] = []
	var checked: Array[String] = []
	var errors := PackedStringArray()
	if steps == null:
		return {"assessed": assessed, "checked": checked, "errors": errors}
	var grids: Dictionary = {}
	for config: Array in reachable_stages(steps, records):
		var map_id: String = config[0]
		var stage: int = config[1]
		var flags: Array = config[2]
		var rec: MapData = records.get(map_id) as MapData
		var map: OverworldMap = maps.get(map_id) as OverworldMap
		if rec == null or map == null:
			continue
		var region: bool = not rec.region_liberation_flag.is_empty() and flags.has(rec.region_liberation_flag)
		var key: String = "%s@%d%s" % [map_id, stage, "+liberated" if region else ""]
		if assessed.has(key):
			continue
		assessed.append(key)
		if not grids.has(map_id):
			grids[map_id] = map.bake_walk_grid(cfg)
		var grid: WalkGrid = grids[map_id]
		for gag: GagInteractable in active_markers(map, rec, stage, flags, stage_records):
			checked.append("%s:%s@%d" % [map_id, gag.marker_id, stage])
			if not responds(gag) and not blocks_route(gag, grid):
				errors.append("%s: clutter marker '%s' at stage %d neither responds to confirm nor blocks a route (AC-49)"
						% [map_id, gag.marker_id, stage])
	return {"assessed": assessed, "checked": checked, "errors": errors}


## `[map_id, stage, flags]` per step, in step order (duplicates kept; the
## caller dedupes). The stage never goes down, as at runtime, because the
## flags only accumulate.
static func reachable_stages(steps: ChapterSteps, records: Dictionary) -> Array:
	var out: Array = []
	var flags: Array = []
	var last_act: bool = false
	for step: ChapterStep in steps.steps:
		if step == null:
			continue
		for f: String in step.flags_on_enter:
			if not flags.has(f):
				flags.append(f)
		last_act = last_act or (not steps.last_act_from.is_empty() and step.id == steps.last_act_from)
		var rec: MapData = records.get(step.map_id) as MapData
		if rec == null:
			continue
		var on: Array = flags.duplicate()
		if last_act and not rec.region_liberation_flag.is_empty():
			on.append(rec.region_liberation_flag)
		var stage: int = OccupationStage.compute(rec, func(f: String) -> bool: return on.has(f), 0)[0]
		out.append([step.map_id, stage, on])
	return out


## `true` for a clutter marker (see the class doc).
static func is_clutter(gag: GagInteractable) -> bool:
	if gag.is_decree() or not gag.liberated_role.is_empty():
		return false
	return not gag.clutter_kind.is_empty() or gag.is_liberatable()


## The clutter markers `MarkerActivation.visible()` shows on `map` at
## `stage` with `flags` set. Uncapped clutter (no `clutter_kind`) is active
## until liberated; a map with no stage (0) slots every marker, as
## `OverworldMode._activate_markers()` does.
static func active_markers(map: OverworldMap, rec: MapData, stage: int, flags: Array,
		stage_records: Array) -> Array[GagInteractable]:
	var out: Array[GagInteractable] = []
	if not rec.region_liberation_flag.is_empty() and flags.has(rec.region_liberation_flag):
		return out
	var markers: Array = []
	var order: int = 0
	for gag: GagInteractable in map.gags():
		order += 1
		if not gag.clutter_kind.is_empty() and not gag.is_decree():
			markers.append({"id": gag.marker_id, "kind": gag.clutter_kind,
					"min_stage": gag.min_stage, "order": order})
	var slotted: Dictionary = {}
	if stage > 0:
		slotted = MarkerActivation.slotted(markers, stage, _caps(rec.faction_id, stage, stage_records))
	else:
		for m: Dictionary in markers:
			slotted[m["id"]] = true
	for gag: GagInteractable in map.gags():
		if not is_clutter(gag):
			continue
		if not gag.liberation_flag.is_empty() and flags.has(gag.liberation_flag):
			continue
		if not gag.clutter_kind.is_empty() and not slotted.has(gag.marker_id):
			continue
		out.append(gag)
	return out


## `true` when `gag` answers `confirm`: `line` and `change` show their
## text; `clue` shows its text and adds its rumour.
static func responds(gag: GagInteractable) -> bool:
	if gag.text.strip_edges().is_empty():
		return false
	if gag.response == GagInteractable.Response.CLUE:
		return not gag.rumour_id.is_empty()
	return true


## `true` when `gag.blocked_rect` covers at least one cell walkable on the
## baked grid (a rectangle over walls or off the map blocks nothing).
static func blocks_route(gag: GagInteractable, grid: WalkGrid) -> bool:
	var r: Rect2 = gag.blocked_rect
	if r.size == Vector2.ZERO or grid == null:
		return false
	for y: int in range(floori(r.position.y / grid.cell_m), ceili(r.end.y / grid.cell_m)):
		for x: int in range(floori(r.position.x / grid.cell_m), ceili(r.end.x / grid.cell_m)):
			if grid.is_walkable(Vector2i(x, y)):
				return true
	return false


static func _caps(faction_id: String, stage: int, stage_records: Array) -> Dictionary:
	for r: Resource in stage_records:
		var o: OccupationStageData = r as OccupationStageData
		if o != null and o.faction_id == faction_id and o.stage == stage:
			return o.clutter_caps
	return {}
