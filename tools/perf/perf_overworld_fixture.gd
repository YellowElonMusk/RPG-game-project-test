## Story 133 (TR-overworld-005, test plan O-08 / OW-T01): builds the
## `perf_overworld` fixture onto an `OverworldMode` from a
## `PerfOverworldSpec`, and drives one measured frame including the
## leader-oscillation hook (Case B). The caller owns the mode and its
## `GameStateMachine` (dependency injection).
class_name PerfOverworldFixture
extends RefCounted

## Case A spec path.
const CHASE_SPEC_PATH: String = "res://tools/perf/perf_overworld_chase.tres"
## Case B spec path.
const FENCED_SPEC_PATH: String = "res://tools/perf/perf_overworld_fenced.tres"
## Encounter ID every fixture symbol carries (contact is off in the run).
const ENC_ID: String = "enc_perf_fixture"

## The leader's two oscillation positions, set by `populate()` (Case A
## holds both on the same spot).
var oscillation: Array[Vector2] = []


## The fixture's walk grid: all walkable; Case B adds a fence row, open
## only at `fence_gap_x`.
static func build_grid(spec: PerfOverworldSpec) -> WalkGrid:
	var grid := WalkGrid.new()
	grid.size = spec.grid_size
	grid.cell_m = spec.cell_m
	grid.cells.resize(spec.grid_size.x * spec.grid_size.y)
	grid.cells.fill(WalkGrid.FLAG_WALKABLE)
	if spec.perf_case == PerfOverworldSpec.PerfCase.FENCED:
		var row: int = fence_row(spec)
		for x: int in spec.grid_size.x:
			if x != spec.fence_gap_x:
				grid.cells[row * spec.grid_size.x + x] = 0
	return grid


## The Case B fence row.
static func fence_row(spec: PerfOverworldSpec) -> int:
	return spec.grid_size.y / 2 - 1


## Walkable cells `W` of `grid`.
static func walkable_cells(grid: WalkGrid) -> int:
	var w: int = 0
	for y: int in grid.size.y:
		for x: int in grid.size.x:
			if grid.is_walkable(Vector2i(x, y)):
				w += 1
	return w


## Symbol count N: the spec's override, else `N_max` of `grid` under the
## record's `density_type` (GDD Formulas `symbol_density`).
static func symbol_count(spec: PerfOverworldSpec, grid: WalkGrid, cfg: OverworldConfig) -> int:
	if spec.symbol_count >= 0:
		return spec.symbol_count
	return MapValidator.density_band(spec.map_record.density_type, walkable_cells(grid), cfg).y


## Sets the debug flags O-08 needs on `cfg`: `no_contact` and `no_giveup`
## always; `notice_cache_off` when `cache_off` (the alternative to the
## oscillation hook for Case B).
static func apply_debug_flags(cfg: OverworldConfig, cache_off: bool = false) -> void:
	cfg.no_contact = true
	cfg.no_giveup = true
	cfg.notice_cache_off = cache_off


## Lays the fixture onto `mode` (already `setup()`, config set): grid,
## leader and N symbols. Case A: leader at the centre, symbols on a ring of
## `chase_ring_m` around it so all notice and chase. Case B: leader just
## below the fence, symbols clustered just above it (see below).
func populate(mode: OverworldMode, spec: PerfOverworldSpec) -> void:
	var grid: WalkGrid = build_grid(spec)
	mode.set_walk_grid(grid)
	var n: int = symbol_count(spec, grid, mode.config)
	var centre_x: int = spec.grid_size.x / 2
	var leg := Vector2(spec.patrol_half_m, 0.0)
	if spec.perf_case == PerfOverworldSpec.PerfCase.CHASE:
		var leader: Vector2 = grid.cell_center(Vector2i(centre_x, spec.grid_size.y / 2))
		oscillation = [leader, leader]
		mode.set_leader_position(leader)
		for i: int in n:
			var at: Vector2 = leader + Vector2.RIGHT.rotated(TAU * float(i) / float(n)) * spec.chase_ring_m
			mode.add_symbol(ENC_ID, SymbolBrain.new(PackedVector2Array([at, at + leg]),
					SymbolBrain.PathMode.PINGPONG, i), "%s_%d" % [ENC_ID, i])
		return
	var row: int = fence_row(spec)
	var leader_cell := Vector2i(centre_x, row + 1)
	oscillation = [grid.cell_center(leader_cell), grid.cell_center(leader_cell + Vector2i.RIGHT)]
	mode.set_leader_position(oscillation[0])
	# Every symbol sits within `symbol_chase_m` of both oscillation cells and
	# patrols a diagonal leg toward / away from the fence; even and odd
	# symbols run in opposite phase, so some always face the leader (front
	# radius) and their notice test reaches the bounded search, which then
	# fails (the only way round is the gap), so they stay in Patrol.
	var diag := Vector2(spec.patrol_half_m, spec.patrol_half_m)
	for i: int in n:
		var at: Vector2 = grid.cell_center(Vector2i(centre_x + i % 2, row - 1))
		var path := PackedVector2Array([at - diag, at] if i % 2 == 0 else [at, at - diag])
		mode.add_symbol(ENC_ID, SymbolBrain.new(path, SymbolBrain.PathMode.PINGPONG, i),
				"%s_%d" % [ENC_ID, i])


## Leader-oscillation hook: the leader position for `frame`, alternating
## between two adjacent cells so the notice-cache key changes every frame.
func oscillate_position(frame: int) -> Vector2:
	return oscillation[frame % oscillation.size()]


## One measured frame: places the leader by the oscillation hook when
## `oscillate`, then steps `mode` with no input.
func step(mode: OverworldMode, frame: int, dt: float, oscillate: bool) -> void:
	if oscillate:
		mode.set_leader_position(oscillate_position(frame))
	mode.step_frame(dt, Vector2.ZERO)
