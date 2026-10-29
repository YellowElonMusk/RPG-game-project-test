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
## TODO(ow-epic): `map_` records, entry points and exits are story 055/073+'s
## scope; this map carries only what the walkable placeholder needs.
class_name OverworldMap
extends Node3D

## The walk layer: a `TileSet` with a `walk: bool` custom data layer. Hidden
## at load (it is a 2D node; drawing it would overlay the 3D diorama).
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


## Bakes this map's `WalkGrid` from `walk_layer` (the only read of the
## layer) and hides the layer. Returns an empty grid (every cell blocked)
## when no layer is assigned.
func bake_walk_grid(cfg: OverworldConfig) -> WalkGrid:
	if walk_layer == null:
		push_error("OverworldMap: walk_layer is not assigned")
		return WalkGrid.new()
	walk_layer.visible = false
	return WalkGrid.bake(walk_layer, cell_m, [], cfg)


## The ground-plane centre of `leader_spawn_cell` in `grid`.
func spawn_position(grid: WalkGrid) -> Vector2:
	return (Vector2(leader_spawn_cell) + Vector2(0.5, 0.5)) * grid.cell_m


## The map's ground bounds `[min, max]` for `FollowCamera.advance()`.
static func ground_bounds(grid: WalkGrid) -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(grid.size) * grid.cell_m)


## Builds the placeholder set on `DioramaStage.LAYER_SET`: one floor plane
## over the whole grid and one box per non-walkable cell. Idempotent: a
## second call replaces the first set.
func build_set(grid: WalkGrid) -> void:
	var old: Node = get_node_or_null(^"PlaceholderSet")
	if old != null:
		remove_child(old)
		old.queue_free()
	var set_root := Node3D.new()
	set_root.name = "PlaceholderSet"
	add_child(set_root)

	var extent: Vector2 = Vector2(grid.size) * grid.cell_m
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = extent
	floor_mesh.material = _flat_material(floor_color)
	var floor_node := MeshInstance3D.new()
	floor_node.name = "Floor"
	floor_node.mesh = floor_mesh
	floor_node.layers = DioramaStage.LAYER_SET
	floor_node.position = Vector3(extent.x * 0.5, 0.0, extent.y * 0.5)
	set_root.add_child(floor_node)

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


func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat
