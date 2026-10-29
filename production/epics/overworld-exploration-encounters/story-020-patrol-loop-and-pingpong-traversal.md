# Story 020: A patrolling symbol walks its full loop or pingpong path at v_patrol

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: `SymbolBrain` owns the symbol sub-state machine's Patrol behaviour: walk the marker's patrol polyline at `v_patrol`, closing a `loop` path's last segment back to the first, or reversing direction at each `pingpong` end.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Pure `SymbolBrain.step()` over a fixture `WalkGrid`; no `AStarGrid2D` query is needed for straight polyline patrol, only `GroundMover`-style stepping toward the next waypoint.

**Control Manifest Rules (this layer)**:
- Required: "Symbol AI lives in the pure `SymbolBrain` (sub-states, notice with cheap checks first then a bounded uniform-cost search, `path_dist` upper bound..., facing hysteresis, Static `start_on`)" — source: ADR-0012 §5
- Forbidden: "Never use a physics body, area, cast or collision shape in the Overworld, 2D or 3D" — source: ADR-0012 §2, §3

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-9a [L] (R5)** GIVEN a patrolling symbol with a `loop` path, THEN it traverses every segment, the closing one included, at `v_patrol`. With a `pingpong` path it reverses at each end.

---

## Implementation Notes

*Derived from ADR-0012 §5 and GDD rule 5's Patrol row:*

GDD rule 5's sub-state table: "Patrol: Walks its marker's patrol path at
`v_patrol`. The path is a polyline marked `loop` (closed: last vertex back to
first) or `pingpong` (walks back the way it came)." This story is the
baseline Patrol behaviour that every later sub-state (Noticing, Chasing,
Returning, Stunned) eventually returns to.

- Fixture: a `loop` polyline of at least 3 vertices; step the brain and assert every segment is walked in order at `v_patrol`, including the closing segment back to vertex 0, with no skipped or truncated segment.
- Fixture: a `pingpong` polyline; assert the symbol reverses direction exactly at each end vertex and retraces the same segments backward.
- `v_patrol` comes from `OverworldConfig`'s `f_patrol × walk_speed`-style formula (Tuning Knobs), never a literal; this story does not yet exercise turn pauses at `pingpong` ends or sharp `loop` vertices — that is story 026's scope.
- A waypoint counts as reached within `cfg.waypoint_tol_m` (ADR-0012 §2), the same tolerance `GroundMover` uses for the leader.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 026: turn pauses at `pingpong` ends and sharp `loop` vertices, and the facing flip timing.
- Story 021–025, 027: Noticing/notice-test/facing-hysteresis behaviour layered on top of Patrol.
- WalkGrid baking from a real `TileMapLayer` (outside this batch) — this story's fixture builds its `WalkGrid` directly in the test.

---

## Files

- `src/overworld/symbol_brain.gd`
- `tests/unit/overworld/symbol_brain_patrol_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/symbol_brain_patrol_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing -- `tests/unit/overworld/symbol_brain_patrol_test.gd` (6 cases)

---

## Dependencies

- Depends on: None
- Unlocks: `production/epics/overworld-exploration-encounters/story-021-notice-delay-before-chasing-starts.md`, `production/epics/overworld-exploration-encounters/story-022-notice-front-and-rear-half-plane-radius.md`, `production/epics/overworld-exploration-encounters/story-023-notice-respects-bounded-path-cap.md`, `production/epics/overworld-exploration-encounters/story-024-deaf-substates-skip-notice-test.md`, `production/epics/overworld-exploration-encounters/story-025-safe-cell-leader-never-noticed.md`, `production/epics/overworld-exploration-encounters/story-026-facing-tracks-leader-with-turn-pause.md`

---

## Completion Notes

**Implemented**: 2026-10-29
- `src/overworld/symbol_brain.gd` (new): pure `RefCounted` `SymbolBrain` with the full `SubState` enum (only `PATROL` has behaviour; the rest hold still, TODO(overworld)) and a `PathMode { LOOP, PINGPONG }`. `step()` spends `cfg.v_patrol() * dt` of arc length per frame, carrying leftover budget across vertices, each leg stepped by `GroundMover.step()` with `WalkGrid.FLAG_SAFE` as the symbol mask.
- `src/overworld/overworld_config.gd`: added `f_patrol` (0.6, GDD Tuning Knobs), `waypoint_tol_m` and `v_patrol()`.
- Tests: `tests/unit/overworld/symbol_brain_patrol_test.gd` checks every frame's position against the analytic point at arc length `v_patrol * t` (loop and unfolded pingpong), the waypoint order, the end reversals, default and custom config.

**Deviations**:
- `step(dt, grid, cfg)` rather than ADR-0012's full `step(dt, leader, leader_safe, grid, budget, grace, cfg)`: `QueryBudget` does not exist yet; stories 021+ widen it.
- `waypoint_tol_m` default 0.05 m chosen here: neither ADR-0012 nor the GDD gives it a value.
- `waypoint_tol_m` applies only after a leg that should arrive this step. Applied up front, it skipped up to `tol` of path whenever a frame ended just short of a vertex, which truncates segments.
