## The leg beacon chain and the "Show next destination" arrow (story 112;
## GDD Overworld rule 19 "Diegetic beacon chain", "Objective line" and
## "Optional marker"; ADR-0012 §3, §8). Pure logic, no drawing: which leg is
## current, which beacons are lit, which beacon is next, and the arrow's
## direction along the walk grid's path and its visibility.
##
## The arrow's path reads the same baked `WalkGrid` the leader moves on
## (`is_walkable()`: baked walls and runtime-blocked cells, never a straight
## line through them), solved with an `AStarGrid2D` configured like the
## grid's own (octile, no jumping, diagonals only past clear corners). The
## grid's own A* is symbol-legal only (it excludes `SAFE` cells, where the
## leader may stand), so the guide keeps a leader-legal twin, re-synced on
## each `WalkGrid.revision()`.
##
## Usage example:
## [codeblock]
## var guide := BeaconGuide.new()
## var dir: Vector2 = guide.path_direction(grid, leader_pos, beacon_pos)
## [/codeblock]
class_name BeaconGuide
extends RefCounted


## The arrow's state for the view (TODO(ui): the drawn screen-edge widget
## that shows `glyph` rotated to `direction` while `visible`).
class Arrow:
	extends RefCounted
	## `true` when the arrow is drawn.
	var visible: bool = false
	## Unit ground-plane direction of the path's next segment, or zero.
	var direction: Vector2 = Vector2.ZERO
	## The shape glyph (never a colour-only cue; guardrail 5).
	var glyph: String = ""
	## The beacon the arrow leads to, or `&""`.
	var target_marker_id: StringName = &""


var _astar: AStarGrid2D = null
var _astar_grid_id: int = 0
var _astar_revision: int = -1


## The current leg on `map_id`: the leg of `step_id` in `steps` when that
## step is on `map_id`, else `""` (no chain on this map is lit).
static func current_leg(steps: ChapterSteps, step_id: String, map_id: String) -> String:
	if steps == null or step_id.is_empty():
		return ""
	for step: ChapterStep in steps.steps:
		if step.id == step_id:
			return step.leg_id if step.map_id == map_id else ""
	return ""


## Lights `leg_id`'s chain on `map` and unlights every other beacon. Returns
## the lit chain in `order` (empty when `leg_id` is empty).
static func apply_lit(map: OverworldMap, leg_id: String) -> Array[WaypointBeacon]:
	var chain: Array[WaypointBeacon] = []
	if map == null:
		return chain
	if not leg_id.is_empty():
		chain = map.beacons(leg_id)
	for bc: WaypointBeacon in map.beacons():
		bc.lit = not leg_id.is_empty() and bc.leg_id == leg_id
	return chain


## The highest chain index the leader at `leader` (ground, relative to
## `map_root`) is within `reach_m` of, or `progress` if that is higher.
## Progress never goes back.
static func advance_progress(chain: Array[WaypointBeacon], progress: int, leader: Vector2,
		map_root: Node, reach_m: float) -> int:
	var out: int = progress
	for i: int in range(chain.size() - 1, out, -1):
		if chain[i].ground_position(map_root).distance_to(leader) <= reach_m:
			return i
	return out


## The chain index of the next beacon after `progress` (the last one once
## every beacon is reached), or -1 for an empty chain.
static func next_index(chain_size: int, progress: int) -> int:
	if chain_size <= 0:
		return -1
	return mini(progress + 1, chain_size - 1)


## Unit direction of the first segment of the leader-legal walk-grid path
## from ground `from` to ground `to`, or `Vector2.ZERO` when either end is
## not walkable, the target is unreachable, or both are in the same cell.
func path_direction(grid: WalkGrid, from: Vector2, to: Vector2) -> Vector2:
	if grid == null:
		return Vector2.ZERO
	var a: Vector2i = grid.cell_of(from)
	var b: Vector2i = grid.cell_of(to)
	if a == b or not grid.is_walkable(a) or not grid.is_walkable(b):
		return Vector2.ZERO
	_sync(grid)
	var route: Array[Vector2i] = _astar.get_id_path(a, b, false)
	if route.size() < 2:
		return Vector2.ZERO
	return (grid.cell_center(route[1]) - grid.cell_center(route[0])).normalized()


## Arrow visibility: the setting is on, there is a direction to show, and
## the beacon is not already on screen (GDD rule 19 "Optional marker").
static func arrow_shown(enabled: bool, direction: Vector2, beacon_on_screen: bool) -> bool:
	return enabled and not direction.is_zero_approx() and not beacon_on_screen


func _sync(grid: WalkGrid) -> void:
	var grid_id: int = grid.get_instance_id()
	if _astar == null or _astar_grid_id != grid_id or _astar.region.size != grid.size:
		_astar = AStarGrid2D.new()
		_astar.region = Rect2i(Vector2i.ZERO, grid.size)
		_astar.cell_size = Vector2.ONE
		_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		_astar.jumping_enabled = false
		_astar.update()
		_astar_grid_id = grid_id
		_astar_revision = -1
	if _astar_revision != grid.revision():
		for y: int in grid.size.y:
			for x: int in grid.size.x:
				var c := Vector2i(x, y)
				_astar.set_point_solid(c, not grid.is_walkable(c))
		_astar_revision = grid.revision()
