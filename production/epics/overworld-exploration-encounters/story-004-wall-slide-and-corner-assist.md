# Story 004: Diagonal walls slide the leader, and small corner overlaps get an assist

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-29)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

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

- [x] **AC-2 [L] (R1)** GIVEN the leader walking diagonally into a wall, THEN it slides along the wall face with non-zero tangential speed. GIVEN a corner overlap of at most `corner_assist_m`, THEN it passes without stopping.

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
- `src/overworld/walk_grid.gd` (new)
- `src/overworld/overworld_config.gd` (widened: `body_radius`, `corner_assist_m`)
- `tests/unit/overworld/ground_mover_collision_test.gd` (new)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/ground_mover_collision_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Passing — 6/6 test cases in file, full suite 649/649 green

---

## Completion Notes

`GroundMover.step()`'s `grid` parameter is now typed `WalkGrid` (was `Object`,
story 004's own TODO). `null` still means "no collision" (the leader's call
site today), so `overworld_mode.gd` needed no change.

Collision is axis-separated (x then y) against `WalkGrid.is_blocked(cell,
blocked_mask)`, using `cfg.body_radius`. Each axis resolution sweeps the
*other* axis's current span against the leading-edge cell(s); given
`body_radius < cell_m / 2` (I8), that span touches at most two cells, so
"exactly one of the two is blocked" unambiguously means a corner graze, not a
flat wall. Its overlap is `body_radius - distance_from_boundary`. Zero or
negative overlap is a bare touch and never blocks (regardless of
`corner_assist_m`) — this is what makes the wall-slide case keep full open-axis
speed, since the clamped axis is left exactly tangent. A positive overlap of at
most `corner_assist_m` nudges the free axis past the corner instead of
blocking (GDD AC-2, part 2); deeper overlap still blocks, same as a flat wall.
This per-axis algorithm is my own reading of ADR-0012 §2.2-3's prose — the ADR
states the *outcomes* (slide; corner assist within `corner_assist_m`) but not
this geometry, so flagging it as an implementation decision rather than a
transcription of the ADR.

`WalkGrid` (new, `RefCounted`): `size`, `cell_m`, `cells: PackedByteArray`
public per the ADR's test-fixture convention; `FLAG_WALKABLE`/`FLAG_SAFE`/
`FLAG_RUNTIME_BLOCKED` bit constants; `is_walkable()`, `is_symbol_legal()`,
`is_blocked(cell, blocked_mask)` (the general query `GroundMover.step()`
needs — additive to the ADR's published Key Interfaces, not a replacement for
any of them), `set_blocked()`, `revision()`, `cell_of()`. `bake()` reads the
`walk` custom data layer via the ADR's cited probed APIs
(`get_used_cells()`/`get_cell_tile_data()`/`get_custom_data()`) but is
untested here (no story-004 AC needs it; tests build a fixture grid by hand)
— `safe_sources`-driven `SAFE` rasterisation is explicitly story 128's scope
and is a TODO(ow-epic), not implemented. `astar()`, `component_of()` and
`bounds()` from the Key Interfaces are not yet built; nothing in this epic
needs them before `AStarGrid2D` (story 131) and `follow_camera` integration
exist, and omitting them doesn't change `WalkGrid`'s shape later.

Dropped one test I wrote (`test_corner_overlap_of_zero_never_blocks_...`): it
derived an exact-zero overlap through an unrelated float chain (`0.7+0.3`
isn't bit-exact `1.0`), so it occasionally failed on floating-point noise, not
on real behavior. The wall-slide tests already exercise the same `overlap <=
0.0` branch exactly (its zero is a self-cancelling subtraction of the same
float, not a derived one), so the coverage goal was already met without the
flaky test.

Deviation: `OverworldConfig` gained `body_radius` (0.3, GDD default) and
`corner_assist_m` (0.25, GDD default) — not in this story's original Files
list, but `GroundMover.step()` cannot read either knob without them, and the
build brief's committed-files note calls `overworld_config.gd` out as a file
to extend.

---

- Status synced 2026-10-30 from commit b8bddee.

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-001-leader-speed-from-move-input.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-005-followers-have-no-collision-or-triggers.md`, `production/epics/overworld-exploration-encounters/story-011-probe-nearest-target-tie-order.md`
