## A map scene's root (ADR-0012 §2, story 136): owns the map's authoring
## `TileMapLayer` (read once, at load, as data only -- it is never drawn) and
## builds the diorama's set geometry from the baked `WalkGrid`, so the walls
## the leader stops at and the walls on screen come from one source.
##
## Ground plane convention (matches `FollowCamera.apply_transform()`): a
## ground point `g` sits at world `(g.x, 0, g.y)`. Grid cell (0, 0) is the
## minimum used cell of `walk_layer` (`WalkGrid.bake()`), and the ground
## origin is that cell's corner, so the map spans `[0, size * cell_m]`.
##
## Story 138: `MapExit` and `EntryPoint` children, and the scene-path
## convention `scene_path()`. TODO(ow-epic): stages and the remaining
## marker kinds (stories 055, 070+).
class_name OverworldMap
extends Node3D

## Story 066: the group of faction set-dressing nodes a liberated set kit
## removes (rule 17).
const FACTION_DRESSING_GROUP: StringName = &"faction_dressing"

## The walk layer: a `TileSet` with a `walk: bool` custom data layer. Hidden
## at load (it is a 2D node; drawing it would overlay the 3D diorama).
## Persistent map id (`WorldState.map_id`; story 137). Matches the map's
## record id once map records exist.
@export var map_id: String = ""
@export var walk_layer: TileMapLayer
## Metres per walk cell, passed to `WalkGrid.bake()`. Map authoring data.
@export var cell_m: float = 1.0
## The grid-local cell the leader spawns in (its centre).
@export var leader_spawn_cell: Vector2i = Vector2i.ZERO
@export_group("Placeholder Set")
## Height of a blocked cell's wall box, in metres.
@export var wall_height_m: float = 1.2
## Floor and wall albedo for the placeholder set geometry.
@export var floor_color: Color = Color(0.62, 0.58, 0.5)
@export var wall_color: Color = Color(0.78, 0.7, 0.55)
## Placeholder tint of a MapExit rectangle's floor patch (story 138).
@export var exit_color: Color = Color(0.35, 0.6, 0.85)
## Placeholder tint of a CampSpot's floor patch.
@export var camp_color: Color = Color(0.45, 0.7, 0.4)
## Placeholder colour of a closed checkpoint's barrier boxes.
@export var checkpoint_color: Color = Color(0.85, 0.3, 0.25)
## Placeholder colours of an NPC's box and a gag's poster board.
@export var npc_color: Color = Color(0.3, 0.55, 0.75)
@export var gag_color: Color = Color(0.95, 0.9, 0.6)


## Bakes this map's `WalkGrid` from `walk_layer` (the only read of the
## layer) and hides the layer. Returns an empty grid (every cell blocked)
## when no layer is assigned.
func bake_walk_grid(cfg: OverworldConfig) -> WalkGrid:
	if walk_layer == null:
		push_error("OverworldMap: walk_layer is not assigned")
		return WalkGrid.new()
	walk_layer.visible = false
	return WalkGrid.bake(walk_layer, cell_m, safe_sources(cfg), cfg)


## The map's `EncounterSymbol` markers in child order (story 137;
## ADR-0012 §4-5). The order is the symbols' marker order.
func symbol_markers() -> Array[EncounterSymbol]:
	var out: Array[EncounterSymbol] = []
	for child: Node in get_children():
		if child is EncounterSymbol:
			out.append(child as EncounterSymbol)
	return out


## The map's `MapExit` markers in child order (story 138).
func map_exits() -> Array[MapExit]:
	var out: Array[MapExit] = []
	for child: Node in get_children():
		if child is MapExit:
			out.append(child as MapExit)
	return out


## The map's `EntryPoint` markers in child order (story 138).
func entry_points() -> Array[EntryPoint]:
	var out: Array[EntryPoint] = []
	for child: Node in get_children():
		if child is EntryPoint:
			out.append(child as EntryPoint)
	return out


## The map's `CampSpot` markers in child order.
func camp_spots() -> Array[CampSpot]:
	var out: Array[CampSpot] = []
	for child: Node in get_children():
		if child is CampSpot:
			out.append(child as CampSpot)
	return out


## The map's `NpcSpawn` markers in child order.
func npc_spawns() -> Array[NpcSpawn]:
	var out: Array[NpcSpawn] = []
	for child: Node in get_children():
		if child is NpcSpawn:
			out.append(child as NpcSpawn)
	return out


## The map's gag `Interactable`s in child order.
func gags() -> Array[GagInteractable]:
	var out: Array[GagInteractable] = []
	for child: Node in get_children():
		if child is GagInteractable:
			out.append(child as GagInteractable)
	return out


## The map's `CheckpointMarker`s in child order.
func checkpoints() -> Array[CheckpointMarker]:
	var out: Array[CheckpointMarker] = []
	for child: Node in get_children():
		if child is CheckpointMarker:
			out.append(child as CheckpointMarker)
	return out


## The map's `JunctionNode` markers in child order (story 110). `leg_id`
## empty = every leg's.
func junction_nodes(leg_id: String = "") -> Array[JunctionNode]:
	var out: Array[JunctionNode] = []
	for child: Node in get_children():
		if child is JunctionNode and (leg_id.is_empty() or (child as JunctionNode).leg_id == leg_id):
			out.append(child as JunctionNode)
	return out


## The map's `WaypointBeacon` markers (story 110). With `leg_id`, that leg's
## chain sorted by `order`; empty = every beacon in child order. Story 112
## lights `beacons(<current leg>)`.
func beacons(leg_id: String = "") -> Array[WaypointBeacon]:
	var out: Array[WaypointBeacon] = []
	for child: Node in get_children():
		if child is WaypointBeacon and (leg_id.is_empty() or (child as WaypointBeacon).leg_id == leg_id):
			out.append(child as WaypointBeacon)
	if not leg_id.is_empty():
		out.sort_custom(func(a: WaypointBeacon, b: WaypointBeacon) -> bool: return a.order < b.order)
	return out


## The CheckpointMarker with `marker_id`, or null.
func find_checkpoint(marker_id: StringName) -> CheckpointMarker:
	for cp: CheckpointMarker in checkpoints():
		if cp.marker_id == marker_id:
			return cp
	return null


## Every safe-zone source on this map (GDD rule 0; ADR-0012 §2): EntryPoints,
## MapExit rectangles and CampSpots at `safe_radius_m`; checkpoint and
## Static-symbol return markers at `return_safe_radius_m`. In the shape
## `WalkGrid.apply_safe_sources()` reads.
func safe_sources(cfg: OverworldConfig) -> Array:
	var out: Array = []
	for entry: EntryPoint in entry_points():
		out.append(WalkGrid.safe_source(Rect2(entry.ground_position(self), Vector2.ZERO), cfg.safe_radius_m))
	for exit: MapExit in map_exits():
		out.append(WalkGrid.safe_source(exit.trigger_rect, cfg.safe_radius_m))
	for camp: CampSpot in camp_spots():
		out.append(WalkGrid.safe_source(Rect2(camp.ground_position(self), Vector2.ZERO), cfg.safe_radius_m))
	for cp: CheckpointMarker in checkpoints():
		out.append(WalkGrid.safe_source(Rect2(cp.return_marker, Vector2.ZERO), cfg.return_safe_radius_m))
	for sym: EncounterSymbol in symbol_markers():
		if sym.is_static and sym.return_marker != Vector2.ZERO:
			out.append(WalkGrid.safe_source(Rect2(sym.return_marker, Vector2.ZERO), cfg.return_safe_radius_m))
	return out


## Ground position (`x`, `z`) of `marker` relative to `map_root`, composed
## from the local transforms of the marker and its ancestors below
## `map_root` (never `global_*`: markers are read before the map enters the
## tree).
static func ground_position_of(marker: Node3D, map_root: Node) -> Vector2:
	var xf: Transform3D = marker.transform
	var node: Node = marker.get_parent()
	while node != null and node != map_root and node is Node3D:
		xf = (node as Node3D).transform * xf
		node = node.get_parent()
	return Vector2(xf.origin.x, xf.origin.z)


## The EntryPoint with `marker_id`, or null.
func find_entry_point(marker_id: StringName) -> EntryPoint:
	for entry: EntryPoint in entry_points():
		if entry.marker_id == marker_id:
			return entry
	return null


## Every MapExit, EntryPoint, CampSpot and checkpoint `marker_id`, in child order (duplicates kept,
## for `MapValidator`).
func marker_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for exit: MapExit in map_exits():
		out.append(exit.marker_id)
	for entry: EntryPoint in entry_points():
		out.append(entry.marker_id)
	for camp: CampSpot in camp_spots():
		out.append(camp.marker_id)
	for cp: CheckpointMarker in checkpoints():
		out.append(cp.marker_id)
	for npc: NpcSpawn in npc_spawns():
		out.append(npc.marker_id)
	for gag: GagInteractable in gags():
		out.append(gag.marker_id)
	for jn: JunctionNode in junction_nodes():
		out.append(jn.marker_id)
	for bc: WaypointBeacon in beacons():
		out.append(bc.marker_id)
	return out


## The scene path of `map_id` by convention (story 138): `map_<name>` ->
## `<dir>/<name>.tscn`. Records never store paths (ADR-0012 §3).
static func scene_path(map_id: String, dir: String) -> String:
	return dir.path_join(map_id.trim_prefix("map_") + ".tscn")


## The ground-plane centre of `leader_spawn_cell` in `grid`.
func spawn_position(grid: WalkGrid) -> Vector2:
	return (Vector2(leader_spawn_cell) + Vector2(0.5, 0.5)) * grid.cell_m


## The map's ground bounds `[min, max]` for `FollowCamera.advance()`.
static func ground_bounds(grid: WalkGrid) -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(grid.size) * grid.cell_m)


## Builds the placeholder set on `DioramaStage.LAYER_SET`: one floor plane
## (`fit_floor()`: the grid plus the camera's overhang) and one box per
## non-walkable cell. Idempotent: a second call replaces the first set.
## `presentation` is the follow camera's config; null = its defaults.
func build_set(grid: WalkGrid, presentation: PresentationConfig = null) -> void:
	var old: Node = get_node_or_null(^"PlaceholderSet")
	if old != null:
		remove_child(old)
		old.queue_free()
	var set_root := Node3D.new()
	set_root.name = "PlaceholderSet"
	add_child(set_root)

	var floor_mesh := PlaneMesh.new()
	floor_mesh.material = _flat_material(floor_color)
	var floor_node := MeshInstance3D.new()
	floor_node.name = "Floor"
	floor_node.mesh = floor_mesh
	floor_node.layers = DioramaStage.LAYER_SET
	set_root.add_child(floor_node)
	fit_floor(grid, presentation)

	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(grid.cell_m, wall_height_m, grid.cell_m)
	wall_mesh.material = _flat_material(wall_color)
	for y: int in grid.size.y:
		for x: int in grid.size.x:
			if grid.is_walkable(Vector2i(x, y)):
				continue
			var wall := MeshInstance3D.new()
			wall.mesh = wall_mesh
			wall.layers = DioramaStage.LAYER_SET
			wall.position = Vector3((x + 0.5) * grid.cell_m, wall_height_m * 0.5,
					(y + 0.5) * grid.cell_m)
			set_root.add_child(wall)

	# Story 138: a flat tinted patch per MapExit rectangle (placeholder only).
	for exit: MapExit in map_exits():
		var patch_mesh := PlaneMesh.new()
		patch_mesh.size = exit.trigger_rect.size
		patch_mesh.material = _flat_material(exit_color)
		var patch := MeshInstance3D.new()
		patch.name = "ExitPatch_%s" % exit.marker_id
		patch.mesh = patch_mesh
		patch.layers = DioramaStage.LAYER_SET
		var c: Vector2 = exit.trigger_rect.get_center()
		patch.position = Vector3(c.x, 0.01, c.y)
		set_root.add_child(patch)

	# A flat tinted patch per CampSpot, and a barrier per checkpoint over its
	# blocked cells, hidden once it opens (`set_checkpoint_shown()`).
	for camp: CampSpot in camp_spots():
		var camp_mesh := PlaneMesh.new()
		camp_mesh.size = Vector2(1.6, 1.6)
		camp_mesh.material = _flat_material(camp_color)
		var camp_patch := MeshInstance3D.new()
		camp_patch.name = "CampPatch_%s" % camp.marker_id
		camp_patch.mesh = camp_mesh
		camp_patch.layers = DioramaStage.LAYER_SET
		var at: Vector2 = camp.ground_position(self)
		camp_patch.position = Vector3(at.x, 0.01, at.y)
		set_root.add_child(camp_patch)
	for cp: CheckpointMarker in checkpoints():
		var bar_mesh := BoxMesh.new()
		bar_mesh.size = Vector3(cp.blocked_rect.size.x, wall_height_m * 0.6, cp.blocked_rect.size.y)
		bar_mesh.material = _flat_material(checkpoint_color)
		var bar := MeshInstance3D.new()
		bar.name = "Checkpoint_%s" % cp.marker_id
		bar.mesh = bar_mesh
		bar.layers = DioramaStage.LAYER_SET
		var bc: Vector2 = cp.blocked_rect.get_center()
		bar.position = Vector3(bc.x, wall_height_m * 0.3, bc.y)
		set_root.add_child(bar)

	# Story 068: closable exits get a hidden tape barrier.
	for exit: MapExit in map_exits():
		if exit.closed_rect.size == Vector2.ZERO:
			continue
		var r: Rect2 = exit.closed_rect
		_marker_box(set_root, "Tape_%s" % exit.marker_id, r.get_center(),
				Vector3(r.size.x, 0.9, maxf(r.size.y * 0.2, 0.1)), checkpoint_color)
		(set_root.get_node("Tape_%s" % exit.marker_id) as Node3D).visible = false

	for npc: NpcSpawn in npc_spawns():
		_marker_box(set_root, "Npc_%s" % npc.marker_id, npc.ground_position(self),
				Vector3(0.4, 1.4, 0.4), npc_color)
	for gag: GagInteractable in gags():
		_marker_box(set_root, "Gag_%s" % gag.marker_id, gag.ground_position(self),
				Vector3(0.8, 1.0, 0.1), gag_color)


## Sprite-camera story 039 (AC-35 coverage): sizes the set's floor to
## `floor_rect()`, so wherever the map clamp puts the camera's focus, at
## every supported aspect, the frame shows floor and never the clear colour
## (a map smaller than the footprint centres the camera and is seen past
## both edges). No-op before `build_set()`.
func fit_floor(grid: WalkGrid, presentation: PresentationConfig = null) -> void:
	var floor_node: MeshInstance3D = get_node_or_null(^"PlaceholderSet/Floor") as MeshInstance3D
	if floor_node == null:
		return
	var cfg: PresentationConfig = presentation if presentation != null else PresentationConfig.new()
	var rect: Rect2 = floor_rect(grid, cfg)
	(floor_node.mesh as PlaneMesh).size = rect.size
	var c: Vector2 = rect.get_center()
	floor_node.position = Vector3(c.x, 0.0, c.y)


## The ground rectangle the floor covers: the walk grid grown by
## `FollowCamera.map_overflow()` for `presentation`'s camera plus one cell of
## slack on every side.
static func floor_rect(grid: WalkGrid, presentation: PresentationConfig) -> Rect2:
	var bounds: Rect2 = ground_bounds(grid)
	var pad: Vector2 = FollowCamera.map_overflow_for(presentation, bounds.size) \
			+ Vector2(grid.cell_m, grid.cell_m)
	return bounds.grow_individual(pad.x, pad.y, pad.x, pad.y)


func _marker_box(parent: Node3D, node_name: String, at: Vector2, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _flat_material(color)
	var box := MeshInstance3D.new()
	box.name = node_name
	box.mesh = mesh
	box.layers = DioramaStage.LAYER_SET
	box.position = Vector3(at.x, size.y * 0.5, at.y)
	parent.add_child(box)


## Hides gag `marker_id`'s placeholder once its `change` is done.
func set_gag_shown(marker_id: StringName, shown: bool) -> void:
	var box: Node3D = get_node_or_null("PlaceholderSet/Gag_%s" % marker_id) as Node3D
	if box != null:
		box.visible = shown

## Shows or hides NPC `marker_id`'s placeholder box.
func set_npc_shown(marker_id: StringName, shown: bool) -> void:
	var box: Node3D = get_node_or_null("PlaceholderSet/Npc_%s" % marker_id) as Node3D
	if box != null:
		box.visible = shown


## Story 066 (rule 17): applies a set kit. The liberated kit removes every
## faction set-dressing addition (nodes in `FACTION_DRESSING_GROUP`).
func apply_set_kit(kit: SetKit) -> void:
	var strip: bool = kit != null and kit.removes_faction_dressing
	for node: Node in find_children("*", "Node3D", true, false):
		if node.is_in_group(FACTION_DRESSING_GROUP):
			(node as Node3D).visible = not strip


## Shows or hides checkpoint `marker_id`'s placeholder barrier.
func set_checkpoint_shown(marker_id: StringName, shown: bool) -> void:
	var bar: Node3D = get_node_or_null("PlaceholderSet/Checkpoint_%s" % marker_id) as Node3D
	if bar != null:
		bar.visible = shown


func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat


## Story 068: shows or hides exit `marker_id`'s tape barrier.
func set_exit_taped(marker_id: StringName, taped: bool) -> void:
	var tape: Node3D = get_node_or_null("PlaceholderSet/Tape_%s" % marker_id) as Node3D
	if tape != null:
		tape.visible = taped
