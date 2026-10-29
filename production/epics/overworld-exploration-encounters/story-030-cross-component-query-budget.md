# Story 030: A leader in another symbol-legal component costs zero A* queries

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: `WalkGrid` keeps 4-connected symbol-legal component labels, recomputed once per frame; the notice test's component check rejects a leader in a different component before any search runs, and the shared query budget covers only queries that survive that check.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: Component relabelling after `set_blocked()` is probed at ~0.83 ms per full pass on a 60×60 grid (4.7.2) — cheap enough to run once per frame, but this story's fixture should keep the grid small so the test stays fast.

**Control Manifest Rules (this layer)**:
- Required: `WalkGrid.set_blocked()` marks 4-connected symbol-legal component labels for one relabel per frame — ADR-0012 §2
- Forbidden: Never let a component-rejected leader reach the bounded search or the query budget — the component check is the "cheap check" that must short-circuit first (GDD rule 5)
- Guardrail: Overworld symbol stepping + notice searches + repaths ≤ 2.0 ms per frame at p99 — ADR-0012 Performance

---

## Acceptance Criteria

- [x] **AC-9h [L] (R5, query budget)** GIVEN a leader in a different symbol-legal component from 6 patrolling symbols with the leader inside their radii, THEN the pathfinder spy records **zero** A* queries (the component check rejects them). GIVEN the same component, THEN notice queries plus repaths never exceed `repath_per_frame_max` on any frame, and a repeated (symbol cell, leader cell) pair is served from the cache.

---

## Implementation Notes

*Derived from ADR-0012 §2 and §5, and GDD rule 5 ("Notice test", step 3):*

The notice test's cheap checks run in order and the first failure ends the
test with no search at all; the component check is the cheapest check that
can reject a leader who is radius-eligible but unreachable.

- Use a pathfinder spy (a stub or a call counter around `WalkGrid.astar()`/the bounded search) to assert **zero** queries when 6 symbols all have the leader in radius but in a different `component_of(cell)` label.
- In the same-component branch, assert the **combined** notice-plus-repath query count never exceeds `repath_per_frame_max` on any single frame (this reuses story 028's budget machinery, but the assertion here is about the component check feeding it correctly).
- A repeated `(symbol cell, leader cell)` pair must be served from the per-symbol waypoint cache, not re-queried — assert the spy's count does not grow on a second identical frame.
- Component labels are recomputed once per frame after that frame's `set_blocked` calls (ADR-0012 §2); the fixture must call `set_blocked` before stepping to exercise a real component split, not a synthetic label.

---

## Out of Scope

- `story-028-notice-repath-budget-fairness.md`: fairness of the round-robin cursor once queries exist.
- `story-029-bounded-notice-search-cap.md`: the in-component distance cap.

---

## Files

- `src/overworld/symbol_brain.gd`
- `src/overworld/walk_grid.gd`
- `tests/unit/overworld/symbol_brain_cross_component_budget_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/symbol_brain_cross_component_budget_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing (2026-10-29)

---

## Dependencies

- Depends on: `story-023-notice-respects-bounded-path-cap.md` (AC-9d, same-component reachability), `story-028-notice-repath-budget-fairness.md`, `story-029-bounded-notice-search-cap.md`
- Unlocks: `story-031-chase-speed-and-repath-throttle.md`

---

## Completion Notes

Notice check 3 (4-connected component labels, relabelled lazily per `set_blocked` revision) closes story 023's TODO. Test: `symbol_brain_cross_component_budget_test.gd` (5). Shared implementation for stories 028-037: `src/overworld/query_budget.gd` (new), `symbol_brain.gd`, `walk_grid.gd` (component labels, `bounded_route`, `find_path` on AStarGrid2D, `segment_clear`, query spy), `overworld_config.gd` (f_chase, repath_s, repath_per_frame_max, symbol_giveup_m, giveup_s, `v_chase()`). Deviation: `step()` takes `budget: QueryBudget = null` as its last optional argument (ADR-0012 lists it fifth) so earlier callers compile; null serves every query.
