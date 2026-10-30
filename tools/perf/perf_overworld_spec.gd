## Story 133 (TR-overworld-005, test plan O-08 / OW-T01): the authored
## parameters of the `perf_overworld` fixture. Data only; read by
## `PerfOverworldFixture`. Lives under `tools/`, not `data/`, so the content
## catalog and the map validators never see it.
class_name PerfOverworldSpec
extends Resource

## O-08 Case A (everything chasing) or Case B (fenced patrol: the bounded
## notice search runs and fails every frame).
enum PerfCase { CHASE, FENCED }

## The fixture's map record (stage 3, exterior).
@export var map_record: MapData = null
## Which O-08 case the fixture lays out.
@export var perf_case: PerfCase = PerfCase.CHASE
## Walk-grid size in cells, all walkable except the Case B fence.
@export var grid_size: Vector2i = Vector2i(48, 32)
## Cell size in metres.
@export var cell_m: float = 1.0
## Symbol count N. -1 = `N_max` of this grid under the record's
## `density_type` (`MapValidator.density_band`). Set it to the shipped
## dungeon's stage-3 `N_max` once that record exists (story 114 blocker).
@export var symbol_count: int = -1
## Followers in the party (O-08: 3). Scene-side only; the step timer does
## not read it.
@export var follower_count: int = 3
## The stage's full civilian count. Scene-side only (story 114 run).
@export var civilian_count: int = 0
## Tilt-shift on for the run (O-08). Scene-side only (story 114 run).
@export var tilt_shift: bool = true
## Measured window in seconds (O-08: 120 s).
@export var duration_s: float = 120.0
## Case A: radius of the ring the symbols start on around the leader, in
## metres; must sit inside `symbol_notice_rear_m` so every symbol notices
## whichever way it faces.
@export var chase_ring_m: float = 1.2
## Half-length of each symbol's patrol leg, in metres.
@export var patrol_half_m: float = 0.5
## Case B: the fence row's gap column (the only way around).
@export var fence_gap_x: int = 0
