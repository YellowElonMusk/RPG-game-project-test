# Story 036: A chase into a safe zone never makes contact and gives up on schedule

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-29)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: `SAFE` cells are never symbol-legal, so a chasing symbol's centre can never enter one; the give-up test also passes whenever the leader stands in a `SAFE` cell.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: No engine-specific risk; relies on the same probed `WalkGrid.is_symbol_legal()` lookup as story 035.

**Control Manifest Rules (this layer)**:
- Required: Symbols never enter safe zones; `SAFE` cells are not symbol-legal — ADR-0012 §2, GDD rule 12
- Forbidden: Never let a symbol's centre enter a `SAFE` cell, on any frame, even approaching a fleeing leader
- Guardrail: n/a

---

## Acceptance Criteria

- [x] **AC-11 [L] (R5, R12)** GIVEN a chase toward a leader who enters a safe zone at `t₀`, THEN on no frame does the symbol's centre enter a `SAFE` cell, and no contact occurs. The symbol is still Chasing at `t₀ + giveup_s − dt` and Returning at `t₀ + giveup_s + dt`.

---

## Implementation Notes

*Derived from ADR-0012 §2, GDD rule 5 ("Give-up test") and rule 12 ("Symbols never enter safe zones"):*

This is the SAFE-cell branch of the give-up test that story 032 deliberately
left out of scope.

- Script a leader walking from open ground into a `SAFE` cell at `t₀` while a symbol is Chasing; assert on **every frame** thereafter that the symbol's centre never occupies a `SAFE` cell (the grid's `is_symbol_legal()` must reject it even as a path target).
- Assert no contact fires at any point, including the swept-circle window during the leader's crossing of the `SAFE` boundary — contact never counts while the leader is in a `SAFE` cell (GDD rule 5, "Contact").
- Apply the GDD timing rule to the give-up window: Chasing at `t₀ + giveup_s − dt`, Returning at `t₀ + giveup_s + dt`, driven by the "leader in a `SAFE` cell" branch of the give-up test rather than the `path_dist` branch.
- This is also an invariant check: `safe_radius_m > symbol_chase_m + 2·body_radius` (I7) guarantees a symbol can get no closer than the chase radius before `SAFE` stops it — the fixture's geometry should respect I7, not fight it.

---

## Out of Scope

- `story-032-chase-give-up-path-distance.md`: the `path_dist` give-up branch.
- `story-037-chase-pathing-edge-cases.md`: the empty-path give-up branch.

---

## Files

- `src/overworld/symbol_brain.gd`
- `tests/unit/overworld/symbol_brain_safe_zone_giveup_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/symbol_brain_safe_zone_giveup_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing (2026-10-29)

---

## Dependencies

- Depends on: `story-035-final-approach-legality.md`, `story-025-safe-cell-leader-never-noticed.md` (AC-9f, `SAFE` cells and reachability)
- Unlocks: `story-038-contact-starts-encounter-once.md`

---

## Completion Notes

SAFE-leader branch of the give-up test. Test: `symbol_brain_safe_zone_giveup_test.gd` (2). Shared implementation for stories 028-037: `src/overworld/query_budget.gd` (new), `symbol_brain.gd`, `walk_grid.gd` (component labels, `bounded_route`, `find_path` on AStarGrid2D, `segment_clear`, query spy), `overworld_config.gd` (f_chase, repath_s, repath_per_frame_max, symbol_giveup_m, giveup_s, `v_chase()`). Deviation: `step()` takes `budget: QueryBudget = null` as its last optional argument (ADR-0012 lists it fifth) so earlier callers compile; null serves every query.

- Status synced 2026-10-30 from commit 77024cb.
