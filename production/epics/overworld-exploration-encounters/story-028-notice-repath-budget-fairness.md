# Story 028: Notice and repath requests share the per-frame budget fairly

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
**ADR Decision Summary**: A pure `GroundMover`/`WalkGrid` with no physics engine, a pure `SymbolBrain` for patrol/notice/chase, and deterministic `AStarGrid2D` pathing behind a shared per-frame query budget.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: `AStarGrid2D` is probed deterministic on 4.7.2 (octile heuristic, no jumping, `DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES`); the round-robin budget cursor is pure GDScript bookkeeping with no engine-specific risk.

**Control Manifest Rules (this layer)**:
- Required: "Notice searches, repaths and Returning paths share `repath_per_frame_max` through a round-robin cursor" — ADR-0012 §5
- Forbidden: Never call `AStarGrid2D.update()` after the bake, or change `region`/`cell_size`/`offset` — ADR-0012 §2
- Guardrail: Overworld symbol stepping + notice searches + repaths ≤ 2.0 ms per frame at p99 (GTX 1080-class PC and Steam Deck) — ADR-0012 Performance

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-9j [L] (R5, budget fairness)** GIVEN N symbols all requesting a search on the same frame with `repath_per_frame_max` B, THEN every request is served within `⌈N/B⌉` frames, the oldest deferred request first, whatever the marker order; Returning paths count toward B.

---

## Implementation Notes

*Derived from ADR-0012 Implementation Guidelines and GDD rule 5:*

`SymbolBrain.step()` is pure and stepped once per symbol per frame, but the A*
queries it can trigger (notice search, chase repath, Returning path) are the
expensive part, so the GDD caps how many resolve per frame.

- The budget is a shared pool, `repath_per_frame_max`, drawn from by a **round-robin cursor** that serves the oldest deferred request first — never marker order (GDD rule 5, "Query budget").
- Returning paths draw from the **same** pool as notice searches and chase repaths; a fixture must include at least one symbol in each sub-state to prove fairness across all three request kinds.
- The bound is `⌈N_req / repath_per_frame_max⌉` frames for every request to be served, including the oldest deferred one — assert this directly rather than an approximate schedule.
- A deferred notice query counts as "not noticed this frame" (Edge Cases); a deferred repath keeps its old, pending path, never an empty one.
- Expected values come from `OverworldConfig.repath_per_frame_max`, never a literal; run the test once more with a non-default budget.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-029-bounded-notice-search-cap.md`: the notice search's own `notice_path_cap_m` bound, independent of the frame budget.
- `story-030-cross-component-query-budget.md`: the component check that rejects a query before it ever reaches the budget.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/overworld/symbol_brain.gd`
- `src/overworld/walk_grid.gd` (the shared query-budget cursor, if it lives here rather than in `SymbolBrain`)
- `tests/unit/overworld/symbol_brain_budget_fairness_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/symbol_brain_budget_fairness_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing (2026-10-29)

---

## Dependencies

- Depends on: `story-021-notice-delay-before-chasing-starts.md` (AC-9b, the notice test this budget gates), `story-023-notice-respects-bounded-path-cap.md` (AC-9d, the bounded search sharing the pool)
- Unlocks: `story-029-bounded-notice-search-cap.md`, `story-030-cross-component-query-budget.md`

---

## Completion Notes

Round-robin `QueryBudget` (reserved slots for the oldest deferred first). Test: `tests/unit/overworld/symbol_brain_budget_fairness_test.gd` (5). Shared implementation for stories 028-037: `src/overworld/query_budget.gd` (new), `symbol_brain.gd`, `walk_grid.gd` (component labels, `bounded_route`, `find_path` on AStarGrid2D, `segment_clear`, query spy), `overworld_config.gd` (f_chase, repath_s, repath_per_frame_max, symbol_giveup_m, giveup_s, `v_chase()`). Deviation: `step()` takes `budget: QueryBudget = null` as its last optional argument (ADR-0012 lists it fifth) so earlier callers compile; null serves every query.
