# Story 004: Diagonal walls slide the leader, and small corner overlaps get an assist

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: `GroundMover.step` resolves collision by axis-separated resolution (x then y) against the blocked mask, using `cfg.body_radius`, so a diagonal wall approach slides along the open axis instead of stopping dead; a corner overlap of at most `cfg.corner_assist_m` nudges the leader along the free axis toward the open side instead of snagging.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Pure GDScript geometry against a fixture `WalkGrid`; no `TileMapLayer`, `AStarGrid2D` or physics API is exercised by this story.

**Control Manifest Rules (this layer)**:
- Required: "Movement goes through the pure static `GroundMover.step(pos, input_vec, dt, grid, cfg, speed, blocked_mask)` with axis-separated collision against the baked `WalkGrid`" — source: ADR-0012 §2
- Forbidden: "Never use a physics body, area, cast or collision shape in the Overworld, 2D or 3D" — source: ADR-0012 §2, §3

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-2 [L] (R1)** GIVEN the leader walking diagonally into a wall, THEN it slides along the wall face with non-zero tangential speed. GIVEN a corner overlap of at most `corner_assist_m`, THEN it passes without stopping.

---

## Implementation Notes

*Derived from ADR-0012 Implementation Guidelines and GDD rule 1:*

GDD rule 1 defers the mechanics of collision to ADR-0012 §2 directly: "Movement,
collision, wall-slide and corner assist follow ADR-0012 §2." The two behaviours
under test are both inside `GroundMover.step`'s collision step, not two
separate systems.

- **Axis-separated collision**: resolve the x move, then the y move, each against cells in `blocked_mask` (for the leader: baked walls plus runtime-blocked cells) with `cfg.body_radius`. Resolving one axis before the other is exactly what produces the slide: a diagonal approach into a wall loses the blocked axis's component but keeps the open axis's, giving non-zero tangential speed.
- **Corner assist (leader only)**: if `cfg.corner_assist_m > 0` and the blocked axis's overlap with a cell corner is ≤ `corner_assist_m`, nudge along the free axis by at most that overlap, toward the open side. `corner_assist_m`'s safe range is 0–0.4 m (Tuning Knobs); too high visibly cuts through walls, too low snags on corners — the fixture should cover a value inside that range plus a boundary case at exactly `corner_assist_m`.
- Build the fixture `WalkGrid` directly in the test (per the ADR-0012 test-fixture convention); no bake pipeline is needed for a pure collision test.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Stories 001–002: speed from input magnitude, with no obstacles.
- Story 003: non-`move` actions.
- Story 005: follower collision (followers have none).

---

## Files

- `src/overworld/ground_mover.gd`
- `src/overworld/walk_grid.gd`
- `tests/unit/overworld/ground_mover_collision_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/ground_mover_collision_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-001-leader-speed-from-move-input.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-005-followers-have-no-collision-or-triggers.md`, `production/epics/overworld-exploration-encounters/story-011-probe-nearest-target-tie-order.md`
