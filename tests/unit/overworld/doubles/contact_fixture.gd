## Shared fixtures for the overworld contact tests (stories 038-042).
class_name ContactFixture
extends RefCounted

const GRID_SIZE: Vector2i = Vector2i(12, 10)


## Fully walkable grid, no `SAFE` cells.
static func open_grid() -> WalkGrid:
	var grid := WalkGrid.new()
	grid.size = GRID_SIZE
	grid.cell_m = 1.0
	grid.cells.resize(GRID_SIZE.x * GRID_SIZE.y)
	grid.cells.fill(WalkGrid.FLAG_WALKABLE)
	return grid


## An `OverworldMode` on `machine` with an open grid, the leader at `leader`
## and `catalog` holding the given `enc_` records. Caller frees it.
static func make_mode(machine: GameStateMachine, cfg: OverworldConfig, leader: Vector2,
		enc_ids: Array[String]) -> OverworldMode:
	var mode := OverworldMode.new()
	mode.config = cfg
	mode.setup(machine, null)
	mode.set_walk_grid(open_grid())
	mode.set_leader_position(leader)
	var catalog := RecordCatalogDouble.new()
	for id: String in enc_ids:
		catalog.add(&"encounter", RecordCatalogDouble.make_encounter(id))
	mode.encounter_catalog = catalog
	return mode


## A patrol brain; `deaf` puts it in the re-notice cooldown so it keeps
## walking whatever the leader does.
static func brain(path: Array[Vector2], marker_index: int, cfg: OverworldConfig,
		deaf: bool) -> SymbolBrain:
	var b := SymbolBrain.new(PackedVector2Array(path), SymbolBrain.PathMode.PINGPONG, marker_index)
	if deaf:
		b.rejoin_patrol(cfg)
	return b
