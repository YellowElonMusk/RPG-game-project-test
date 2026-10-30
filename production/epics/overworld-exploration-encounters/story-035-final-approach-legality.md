# Story 035: The final approach steers straight at the leader only over legal cells

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-29)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: A chasing symbol steers straight at its offset point, bypassing the path, only when the leader's cell is still the path's target, the leader is not in a `SAFE` cell, and every cell the straight segment crosses is symbol-legal; the step always goes through `GroundMover` with the symbol mask.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: No post-cutoff API involved; the swept-cell check over the straight segment is pure geometry against `WalkGrid.is_symbol_legal()`.

**Control Manifest Rules (this layer)**:
- Required: Final approach only over legal cells, stepped by `GroundMover` with the symbol mask, so a symbol never ends a frame on a non-legal cell — ADR-0012 §5
- Forbidden: Never let a symbol's centre land on a `SAFE` or blocked cell, even mid-frame — GDD rule 0, rule 5
- Guardrail: n/a

---

## Acceptance Criteria

- [x] **AC-10e [L] (R5, final approach legality)** GIVEN a leader standing one cell inside a `SAFE` edge, a leader who rounds a wall corner between repaths, and a diagonal approach past a blocked corner, THEN on every frame the symbol's centre lies on a symbol-legal cell, the final approach is used only while the leader's cell is the path's target and every crossed cell is legal, and every A* query starts from a symbol-legal cell.

---

## Implementation Notes

*Derived from ADR-0012 §5 and GDD rule 5 ("Chase target", "Final approach"):*

Three fixtures, each targeting one of the final approach's three legality
conditions:

- **Leader one cell inside a `SAFE` edge**: the leader is not in a `SAFE` cell is false here, so the final approach must **not** engage — the symbol keeps following the path, which itself never crosses into `SAFE` (symbols are never symbol-legal there).
- **Leader rounds a wall corner between repaths**: the path's target cell goes stale for a frame or two; assert the final approach does not engage until the leader's cell is again the path's **current** target, and that the symbol's centre never leaves a symbol-legal cell in the gap.
- **Diagonal approach past a blocked corner**: sweep the straight segment (by `body_radius`) across the two cells adjacent to the corner and assert the final approach is rejected if either crossed cell is not symbol-legal, falling back to the path.
- Across all three fixtures, assert on **every frame** that the symbol's centre is on a symbol-legal cell (never `SAFE`, never blocked) and that every A* query in the fixture started from a symbol-legal origin snapped to the nearest legal cell (ADR-0012 §2's origin-snap rule).

---

## Out of Scope

- `story-034-chase-target-offset.md`: what the target point is.
- `story-036-chase-gives-up-at-safe-zone.md`: give-up behaviour once the leader reaches `SAFE`.

---

## Files

- `src/overworld/symbol_brain.gd`
- `src/overworld/ground_mover.gd`
- `src/overworld/walk_grid.gd`
- `tests/unit/overworld/symbol_brain_final_approach_legality_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/symbol_brain_final_approach_legality_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing (2026-10-29)

---

## Dependencies

- Depends on: `story-034-chase-target-offset.md`, `story-025-safe-cell-leader-never-noticed.md` (AC-9f, `SAFE` cells are not symbol-legal)
- Unlocks: `story-036-chase-gives-up-at-safe-zone.md`

---

## Completion Notes

Final approach requires: route non-empty, chase-target cell == route target cell (interpreted as the offset target's cell, not literally the leader's), leader not SAFE, `segment_clear` swept by body_radius (conservative square sweep). Test: `symbol_brain_final_approach_legality_test.gd` (3). `ground_mover.gd` unchanged; it still applies corner assist to symbols (ADR says leader only) -- flagged, not changed. Shared implementation for stories 028-037: `src/overworld/query_budget.gd` (new), `symbol_brain.gd`, `walk_grid.gd` (component labels, `bounded_route`, `find_path` on AStarGrid2D, `segment_clear`, query spy), `overworld_config.gd` (f_chase, repath_s, repath_per_frame_max, symbol_giveup_m, giveup_s, `v_chase()`). Deviation: `step()` takes `budget: QueryBudget = null` as its last optional argument (ADR-0012 lists it fifth) so earlier callers compile; null serves every query.

- Status synced 2026-10-30 from commit 77024cb.
