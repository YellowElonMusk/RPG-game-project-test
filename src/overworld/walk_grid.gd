## Baked walk-plane collision data (ADR-0012 §2 Key Interfaces). Built once
## per map visit by `bake()` from the map's hidden `WalkLayer`
## (`TileMapLayer`); `GroundMover.step()` (story 004) queries it for
## axis-separated collision and corner assist. `size`, `cell_m` and `cells`
## are public so a test can build a fixture grid directly, without a
## `TileMapLayer` (ADR-0012 Implementation Guidelines: "Tests... with
## fixture grids").
class_name WalkGrid
extends RefCounted

## Bit flags packed into each byte of `cells` (ADR-0012 §2: "Bits: 0 =
## walkable (baked), 1 = SAFE, 2 = runtime-blocked, others = terrain tags
## (zone)"). Terrain/zone tags (bits 3+) are TODO(ow-epic): no story in this
## epic reads them yet.
const FLAG_WALKABLE: int = 1 << 0
const FLAG_SAFE: int = 1 << 1
const FLAG_RUNTIME_BLOCKED: int = 1 << 2

## The eight neighbour offsets `bounded_search()` expands.
const _NEIGHBOURS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

## The four neighbours component labelling follows (GDD rule 5 check 3:
## "4-connected component labels (matching the A* diagonal rule)").
const _NEIGHBOURS4: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## Grid extent, in cells.
var size: Vector2i = Vector2i.ZERO

## Edge length of one cell, in metres (GDD Tuning Knobs; MVP default 1.0).
var cell_m: float = 1.0

## One byte per cell, row-major (`y * size.x + x`); see the `FLAG_*` constants.
var cells: PackedByteArray = PackedByteArray()

## Pathfinder spy (AC-9h, AC-10a): every `bounded_route()` and
## `find_path()` call -- the queries the shared `QueryBudget` meters.
var query_count: int = 0

## Cells the most recent bounded search expanded (story 029's spy).
var last_search_expanded: int = 0

## Largest route length, in metres, of any cell the most recent bounded
## search expanded; never above that search's cap (AC-9k).
var last_search_max_expanded_m: float = 0.0

## Bumped by every `set_blocked()` call (ADR-0012 §2). Symbol path and
## notice caches, the component labels and the A* solids are keyed on it.
var _revision: int = 0

## 4-connected symbol-legal component label per cell (-1: not legal).
var _labels: PackedInt32Array = PackedInt32Array()
var _labels_revision: int = -1

## The symbols' pathfinder (ADR-0012 §2): `update()` runs once, at first
## use; afterwards only solids change, re-synced when `_revision` moves.
var _astar: AStarGrid2D = null
var _astar_revision: int = -1


## Bakes a grid from `layer`'s `walk: bool` custom data layer (ADR-0012 §2;
## Engine Compatibility: the only post-cutoff APIs this ADR uses are
## `TileMapLayer.get_used_cells()`, `get_cell_tile_data()` and
## `TileData.get_custom_data()`, all at this bake). Grid-local cell (0, 0) is
## the minimum of `layer.get_used_cells()`, not the layer's own (0, 0) --
## aligning that to the map's ground origin is the map-loading story's job.
## Then tags `SAFE` from `safe_sources` (`apply_safe_sources()`, story 128).
static func bake(layer: TileMapLayer, cell_m: float, safe_sources: Array, cfg: OverworldConfig) -> WalkGrid:
	var used_cells: Array[Vector2i] = layer.get_used_cells()
	var grid := WalkGrid.new()
	grid.cell_m = cell_m
	if used_cells.is_empty():
		return grid

	var min_cell: Vector2i = used_cells[0]
	var max_cell: Vector2i = used_cells[0]
	for cell in used_cells:
		min_cell.x = mini(min_cell.x, cell.x)
		min_cell.y = mini(min_cell.y, cell.y)
		max_cell.x = maxi(max_cell.x, cell.x)
		max_cell.y = maxi(max_cell.y, cell.y)

	grid.size = max_cell - min_cell + Vector2i.ONE
	grid.cells.resize(grid.size.x * grid.size.y)
	for cell in used_cells:
		var tile_data: TileData = layer.get_cell_tile_data(cell)
		if tile_data != null and bool(tile_data.get_custom_data("walk")):
			var local: Vector2i = cell - min_cell
			grid.cells[local.y * grid.size.x + local.x] = FLAG_WALKABLE
	grid.apply_safe_sources(safe_sources)
	return grid


## A safe-zone source for `apply_safe_sources()`: a ground rectangle in
## metres (zero size for a point source -- an EntryPoint, a CampSpot, a
## return marker) and its radius (GDD rule 0).
static func safe_source(rect: Rect2, radius: float) -> Dictionary:
	return {"rect": rect, "radius": radius}


## Tags `SAFE` every cell whose nearest point lies within a source's radius
## of that source's rectangle (GDD rule 0: conservative, "a cell any part of
## which is in range counts"; story 128, AC-56). Cell `(x, y)` spans
## `[x, x + 1) * cell_m` on each axis, with the grid origin at ground (0, 0).
## Walls are tagged too: `SAFE` only matters on walkable cells.
func apply_safe_sources(safe_sources: Array) -> void:
	for source: Dictionary in safe_sources:
		var rect: Rect2 = source["rect"]
		var radius: float = source["radius"]
		var lo: Vector2i = Vector2i(floori((rect.position.x - radius) / cell_m),
				floori((rect.position.y - radius) / cell_m))
		var hi: Vector2i = Vector2i(floori((rect.end.x + radius) / cell_m),
				floori((rect.end.y + radius) / cell_m))
		for y in range(maxi(lo.y, 0), mini(hi.y, size.y - 1) + 1):
			for x in range(maxi(lo.x, 0), mini(hi.x, size.x - 1) + 1):
				var cell_rect := Rect2(Vector2(x, y) * cell_m, Vector2.ONE * cell_m)
				if rect_distance(cell_rect, rect) <= radius:
					cells[y * size.x + x] = cells[y * size.x + x] | FLAG_SAFE


## The distance between the nearest points of two rectangles (0 when they
## touch or overlap).
static func rect_distance(a: Rect2, b: Rect2) -> float:
	var dx: float = maxf(0.0, maxf(b.position.x - a.end.x, a.position.x - b.end.x))
	var dy: float = maxf(0.0, maxf(b.position.y - a.end.y, a.position.y - b.end.y))
	return Vector2(dx, dy).length()


## Baked walkable and not runtime-blocked (Key Interfaces). Out-of-bounds
## cells are blocked (ADR-0012 §2: "Cells outside the grid are blocked").
func is_walkable(cell: Vector2i) -> bool:
	if not _in_bounds(cell):
		return false
	var flags: int = cells[_index(cell)]
	return (flags & FLAG_WALKABLE) != 0 and (flags & FLAG_RUNTIME_BLOCKED) == 0


## Walkable and not `SAFE` -- the cells symbols path and move over (Key
## Interfaces; GDD "Symbol-legal cell").
func is_symbol_legal(cell: Vector2i) -> bool:
	if not is_walkable(cell):
		return false
	return (cells[_index(cell)] & FLAG_SAFE) == 0


## `true` iff `cell` should stop `GroundMover.step()`'s collision for a
## caller using `blocked_mask`: out of bounds, not baked-walkable, or
## runtime-blocked (all already covered by `is_walkable()`), or flagged by
## any bit in `blocked_mask`. The leader passes `blocked_mask = 0`, so
## `is_walkable()` alone is its rule; symbols will pass `FLAG_SAFE` on top
## (ADR-0012 §2: "the leader: baked walls + runtime-blocked; symbols: those
## plus SAFE").
func is_blocked(cell: Vector2i, blocked_mask: int) -> bool:
	if not is_walkable(cell):
		return true
	if blocked_mask == 0:
		return false
	return (cells[_index(cell)] & blocked_mask) != 0


## The only path that changes blocked cells at runtime (Key Interfaces):
## sets or clears `FLAG_RUNTIME_BLOCKED` on every cell in `cells_to_set`,
## batched into a single `revision()` bump. Out-of-bounds entries are
## skipped. The revision bump makes the next `component_of()` relabel once
## and the next `find_path()` re-sync the A* solids (ADR-0012 §2), and it
## invalidates every symbol's stored path and notice cache.
func set_blocked(cells_to_set: Array[Vector2i], on: bool) -> void:
	for cell in cells_to_set:
		if not _in_bounds(cell):
			continue
		var idx: int = _index(cell)
		if on:
			cells[idx] = cells[idx] | FLAG_RUNTIME_BLOCKED
		else:
			cells[idx] = cells[idx] & (0xFF ^ FLAG_RUNTIME_BLOCKED)
	_revision += 1


## Bumped once per `set_blocked()` call (Key Interfaces).
func revision() -> int:
	return _revision


## Converts a ground-plane position, in metres, to its containing cell.
func cell_of(ground: Vector2) -> Vector2i:
	return Vector2i(floori(ground.x / cell_m), floori(ground.y / cell_m))


## Ground-plane centre of `cell`, in metres.
func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cell_m


## `true` iff `cell` is in bounds and carries the `SAFE` bit (GDD rule 5
## notice test check 2: "the leader is not in a `SAFE` cell"; rule 12).
## Out-of-bounds cells are not safe.
func is_safe(cell: Vector2i) -> bool:
	if not _in_bounds(cell):
		return false
	return (cells[_index(cell)] & FLAG_SAFE) != 0


## The notice test's bounded search (GDD rule 5 check 4; ADR-0012 §5) as a
## route length: the length of `bounded_route()`'s route, or `INF` when it
## finds none within `cap_m`.
func bounded_search(from: Vector2i, to: Vector2i, cap_m: float) -> float:
	var route: Array[Vector2i] = bounded_route(from, to, cap_m)
	if route.is_empty():
		return INF
	return route_length(route)


## The notice test's bounded search (GDD rule 5 check 4; ADR-0012 §5):
## uniform-cost (Dijkstra-style) over symbol-legal cells, 8-connected with
## `cell_m * sqrt(2)` diagonal steps, a diagonal allowed only when both
## orthogonal cells it cuts past are symbol-legal (the A* diagonal rule).
## Returns the cell route `from` .. `to`, or `[]` when `to` is not reached
## within `cap_m`. No cell whose route length exceeds `cap_m` is ever
## expanded (`last_search_max_expanded_m` records it), so the cost is
## bounded by the cap. Counts as one query.
func bounded_route(from: Vector2i, to: Vector2i, cap_m: float) -> Array[Vector2i]:
	query_count += 1
	last_search_expanded = 0
	last_search_max_expanded_m = 0.0
	var route: Array[Vector2i] = []
	if cap_m < 0.0 or not is_symbol_legal(from) or not is_symbol_legal(to):
		return route
	if from == to:
		route.append(from)
		return route
	var dist: Dictionary[Vector2i, float] = {from: 0.0}
	var parent: Dictionary[Vector2i, Vector2i] = {}
	var done: Dictionary[Vector2i, bool] = {}
	var frontier: Array[Vector2i] = [from]
	while not frontier.is_empty():
		var best: int = 0
		for i in range(1, frontier.size()):
			if dist[frontier[i]] < dist[frontier[best]]:
				best = i
		var cell: Vector2i = frontier[best]
		frontier[best] = frontier[frontier.size() - 1]
		frontier.pop_back()
		if done.has(cell):
			continue
		done[cell] = true
		var d: float = dist[cell]
		last_search_expanded += 1
		last_search_max_expanded_m = maxf(last_search_max_expanded_m, d)
		if cell == to:
			var walk: Vector2i = to
			route.append(walk)
			while walk != from:
				walk = parent[walk]
				route.append(walk)
			route.reverse()
			return route
		for off: Vector2i in _NEIGHBOURS:
			var n: Vector2i = cell + off
			if done.has(n) or not is_symbol_legal(n):
				continue
			var diagonal: bool = off.x != 0 and off.y != 0
			if diagonal and (not is_symbol_legal(Vector2i(n.x, cell.y))
					or not is_symbol_legal(Vector2i(cell.x, n.y))):
				continue
			var nd: float = d + cell_m * (sqrt(2.0) if diagonal else 1.0)
			if nd > cap_m:
				continue
			if not dist.has(n) or nd < dist[n]:
				dist[n] = nd
				parent[n] = cell
				frontier.append(n)
	return route


## Length, in metres, of a cell route between its end cell centres
## (`cell_m` per orthogonal step, `cell_m * sqrt(2)` per diagonal one).
func route_length(route: Array[Vector2i]) -> float:
	var total: float = 0.0
	for i in range(1, route.size()):
		var step: Vector2i = route[i] - route[i - 1]
		total += cell_m * (sqrt(2.0) if step.x != 0 and step.y != 0 else 1.0)
	return total


## A* over symbol-legal cells (ADR-0012 §2 pathing setup: octile heuristic,
## no jumping, `DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES`,
## `allow_partial_path = false`). Returns the cell route `from` .. `to`, or
## `[]` when either end is not symbol-legal or `to` is unreachable. Counts
## as one query; callers meter it through the `QueryBudget`.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	query_count += 1
	var route: Array[Vector2i] = []
	if not is_symbol_legal(from) or not is_symbol_legal(to):
		return route
	_sync_astar()
	assert(not _astar.is_dirty(), "WalkGrid: A* queried while dirty")
	for id: Vector2i in _astar.get_id_path(from, to, false):
		route.append(id)
	return route


## 4-connected symbol-legal component label of `cell` (GDD rule 5 notice
## check 3), or -1 when `cell` is not symbol-legal. Labels are recomputed at
## most once per `set_blocked()` revision, on first use after it.
func component_of(cell: Vector2i) -> int:
	if not is_symbol_legal(cell):
		return -1
	if _labels_revision != _revision or _labels.size() != cells.size():
		_relabel()
	return _labels[_index(cell)]


## `true` iff the straight segment `a` -> `b`, swept by a square of
## half-width `radius`, crosses only cells that pass the rule: symbol-legal
## when `symbol_rule` is set (GDD rule 5 final approach), else walkable (the
## leader's rule, for `path_dist`'s gap). Sampled every `cell_m / 20`; the
## square makes the sweep conservative.
func segment_clear(a: Vector2, b: Vector2, radius: float, symbol_rule: bool) -> bool:
	var r: float = maxf(0.0, radius - 1e-6)
	var steps: int = maxi(1, ceili(a.distance_to(b) / (cell_m * 0.05)))
	for i in steps + 1:
		var p: Vector2 = a.lerp(b, float(i) / float(steps))
		var lo: Vector2i = cell_of(p - Vector2(r, r))
		var hi: Vector2i = cell_of(p + Vector2(r, r))
		for y in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1):
				var c := Vector2i(x, y)
				if not (is_symbol_legal(c) if symbol_rule else is_walkable(c)):
					return false
	return true


func _relabel() -> void:
	_labels.resize(cells.size())
	_labels.fill(-1)
	var next_label: int = 0
	for y in size.y:
		for x in size.x:
			var start := Vector2i(x, y)
			if _labels[_index(start)] >= 0 or not is_symbol_legal(start):
				continue
			_labels[_index(start)] = next_label
			var stack: Array[Vector2i] = [start]
			while not stack.is_empty():
				var cur: Vector2i = stack.pop_back()
				for off: Vector2i in _NEIGHBOURS4:
					var n: Vector2i = cur + off
					if is_symbol_legal(n) and _labels[_index(n)] < 0:
						_labels[_index(n)] = next_label
						stack.append(n)
			next_label += 1
	_labels_revision = _revision


func _sync_astar() -> void:
	if _astar == null:
		_astar = AStarGrid2D.new()
		_astar.region = Rect2i(Vector2i.ZERO, size)
		_astar.cell_size = Vector2.ONE
		_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		_astar.jumping_enabled = false
		_astar.update()
		_astar_revision = -1
	if _astar_revision != _revision:
		for y in size.y:
			for x in size.x:
				var c := Vector2i(x, y)
				_astar.set_point_solid(c, not is_symbol_legal(c))
		_astar_revision = _revision


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func _index(cell: Vector2i) -> int:
	return cell.y * size.x + cell.x
