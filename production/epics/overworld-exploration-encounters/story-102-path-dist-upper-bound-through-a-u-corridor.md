# Story 102: `path_dist` stays a true upper bound on the leader's path distance through a U-shaped corridor

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-004`, `TR-overworld-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: `path_dist = arc(c_S → w_last) + |w_last − c_L(t₀)| + d_L(t₀ → t)` is a real route length and therefore an upper bound on the true path distance, so a stale or deferred path can only make give-up come earlier than the open-ground bound, never later.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: Deterministic `AStarGrid2D` pathing (pinned config, probed on 4.7.2); no new engine surface beyond stories 098–101.

**Control Manifest Rules (this layer)**:
- Required: "`path_dist = arc(c_S → w_last) + |w_last − c_L(t₀)| + d_L(t₀ → t)` (a real route length, hence an upper bound; the gap counts as +∞ when the leader stood in a `SAFE` cell at t₀ or the gap crosses a non-walkable cell)" — source: ADR-0012 §5

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-40c [L] (`path_dist`)** GIVEN a U-shaped corridor in which the leader rounds a wall end between repaths, THEN on every frame `path_dist` is at least the true walk-grid path distance from symbol to leader, and from the first frame on which `path_dist > symbol_giveup_m`, it stays above `symbol_giveup_m` on every frame until Returning, unless the true path distance falls below it.

---

## Implementation Notes

*Derived from GDD Formulas ("symbol_speeds", "Why I2 needs no repath term") and rule 5 ("Path distance"):*

- Build a U-shaped corridor fixture where the leader walks round the wall's far end **between** the symbol's repaths (`repath_s` apart), so the stored path goes stale relative to the leader's true position.
- On every frame, compute both `path_dist` (`arc(c_S → w_last) + |w_last − c_L(t₀)| + d_L(t₀ → t)`) and the true walk-grid shortest path distance from the symbol's current cell to the leader's current cell. Assert `path_dist ≥` the true distance on every frame — it is a real route length, hence an upper bound, never an underestimate.
- From the first frame `path_dist > symbol_giveup_m`, assert it stays above `symbol_giveup_m` on every subsequent frame until the symbol reaches **Returning**, unless the true path distance itself drops back below `symbol_giveup_m` first (a stale path can only make give-up come **earlier**, never later, per the Formulas' own closing note).
- Also cover the two `+∞` gap cases from `SymbolBrain.path_dist()`: the leader stood in a `SAFE` cell at `t₀`, or the straight gap from the path's end to the leader's `t₀` position crosses a non-walkable cell.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The open-ground escape-timing fixture (story 101).
- Density, walk-budget and the rest of the level-review formulas (stories 103, 104).

---

## Files

- `src/overworld/symbol_brain.gd`
- `tests/unit/overworld/path_dist_upper_bound_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/path_dist_upper_bound_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-101-symbol-speeds-escape-timing.md`
- Unlocks: None further in this epic

## Completion Notes (2026-10-30)

- Test: `tests/unit/overworld/path_dist_upper_bound_test.gd`, on a U corridor 14 × 26 with the wall on column 6. The leader walks down one arm, round the end and up the other, so it rounds the wall between repaths.
- Interpretation, flagged: "true path distance" is the exact point geodesic (straight when clear, else round the wall end's two corners), not cell-centre grid distance. The latter is not a lower bound for real positions: two points in opposite corners of their cells sat 1.5 m under it, so the first draft failed on a correct `path_dist`.
- The symbol cuts the bend and closes in there, so the test gives up at 5.0 m rather than 6.5; otherwise the chase never went beyond give-up in the fixture.
- Both `+INF` gaps are covered: a leader in a SAFE cell at `t0`, and a route end walled off from the leader.
- Mutation checked: dropping the leader-travel term (an underestimate) fails a test here.
