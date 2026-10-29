# Story 029: The notice search never explores past its path-length cap

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: `SymbolBrain`'s notice test runs a bounded, uniform-cost (Dijkstra-style) search over symbol-legal cells, stopping at `notice_path_cap_m`, with waypoints cached per symbol.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: The bounded search is hand-rolled (not `AStarGrid2D`), so it carries no post-cutoff API risk; it still must start from a symbol-legal origin, matching the A* origin rule ADR-0012 §2 probes.

**Control Manifest Rules (this layer)**:
- Required: Symbol AI lives in the pure `SymbolBrain`, including "notice with cheap checks first then a bounded uniform-cost search" — ADR-0012 §5
- Forbidden: Never let the notice search explore beyond its cap — unbounded search cost is exactly what rule 5's "bounded search" guards against
- Guardrail: Overworld symbol stepping + notice searches + repaths ≤ 2.0 ms per frame at p99 — ADR-0012 Performance

---

## Acceptance Criteria

- [ ] **AC-9k [L] (R5, bounded notice search)** GIVEN a leader 3 m from a symbol in the same component but 60 m round a wall, THEN the notice search visits no cell whose path length exceeds `notice_path_cap_m`, and no notice occurs. The cached waypoints are per symbol, and two symbols in the same cell with different marker indices get different chase targets.

---

## Implementation Notes

*Derived from ADR-0012 §5 and GDD rule 5 ("Notice test", step 4):*

The notice test's fourth and most expensive check is a bounded uniform-cost
search over symbol-legal cells with √2 diagonal steps, stopping once the
visited path length exceeds `notice_path_cap_m`.

- Instrument the search (a spy or visited-cell counter) to prove it **never** explores a cell whose path length is past the cap — not just that it returns no notice, since a fence could fail either for the right or the wrong reason.
- Waypoints found by a successful search are cached per symbol, invalidated only when the symbol's cell, the leader's cell, or a `set_blocked` call changes (rule 5).
- Two symbols on the same cell are told apart by marker index when computing the chase target offset (rule 5, "Chase target") — this story only needs that the cached waypoints and the resulting notice decision are kept **per symbol**, never shared.
- Expected the cap value from `OverworldConfig.notice_path_cap_m`, never a literal.

---

## Out of Scope

- `story-028-notice-repath-budget-fairness.md`: the per-frame budget across symbols, not the search's own distance bound.
- `story-034-chase-target-offset.md`: the per-symbol chase-target offset itself.

---

## Files

- `src/overworld/symbol_brain.gd`
- `tests/unit/overworld/symbol_brain_notice_search_cap_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/symbol_brain_notice_search_cap_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-023-notice-respects-bounded-path-cap.md` (AC-9d, reachability and the notice-path cap concept), `story-028-notice-repath-budget-fairness.md`
- Unlocks: `story-030-cross-component-query-budget.md`
