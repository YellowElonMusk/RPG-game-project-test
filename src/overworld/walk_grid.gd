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

## Grid extent, in cells.
var size: Vector2i = Vector2i.ZERO

## Edge length of one cell, in metres (GDD Tuning Knobs; MVP default 1.0).
var cell_m: float = 1.0

## One byte per cell, row-major (`y * size.x + x`); see the `FLAG_*` constants.
var cells: PackedByteArray = PackedByteArray()

## Bumped by every `set_blocked()` call (ADR-0012 §2). TODO(ow-epic): read
## by symbol path/notice caches once `SymbolBrain` exists -- `set_blocked`
## is already the only path that changes it.
var _revision: int = 0


## Bakes a grid from `layer`'s `walk: bool` custom data layer (ADR-0012 §2;
## Engine Compatibility: the only post-cutoff APIs this ADR uses are
## `TileMapLayer.get_used_cells()`, `get_cell_tile_data()` and
## `TileData.get_custom_data()`, all at this bake). Grid-local cell (0, 0) is
## the minimum of `layer.get_used_cells()`, not the layer's own (0, 0) --
## aligning that to the map's ground origin is the map-loading story's job.
## TODO(ow-epic): `safe_sources`-driven `SAFE` rasterisation
## (EntryPoint/MapExit/CampSpot/return-marker radii, exact to 0.01 m) is
## story 128's scope; `safe_sources` and `cfg` are accepted here (so this
## signature does not change shape when that story lands) but not yet read --
## every baked cell's `SAFE` bit is 0 until then.
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
	return grid


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
## skipped. TODO(ow-epic): syncing the symbols' `AStarGrid2D` and
## relabelling symbol-legal components (ADR-0012 §2) is later stories'
## scope -- no `AStarGrid2D` or component labelling exists yet.
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


## The notice test's bounded search (GDD rule 5 check 4; ADR-0012 §5):
## uniform-cost (Dijkstra-style) over symbol-legal cells, 8-connected with
## `cell_m * sqrt(2)` diagonal steps, a diagonal allowed only when both
## orthogonal cells it cuts past are symbol-legal (the A* diagonal rule).
## Returns the route length between the two cell centres, in metres, or
## `INF` when `to` is not reached within `cap_m`. No cell whose route length
## exceeds `cap_m` is ever expanded, so the cost is bounded by the cap.
## TODO(overworld): the per-symbol waypoint cache cleared by `set_blocked`
## (AC-9k) is outside stories 021-027.
func bounded_search(from: Vector2i, to: Vector2i, cap_m: float) -> float:
	if cap_m < 0.0 or not is_symbol_legal(from) or not is_symbol_legal(to):
		return INF
	if from == to:
		return 0.0
	var dist: Dictionary[Vector2i, float] = {from: 0.0}
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
		if cell == to:
			return d
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
				frontier.append(n)
	return INF


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func _index(cell: Vector2i) -> int:
	return cell.y * size.x + cell.x
