# Story 035: The final approach steers straight at the leader only over legal cells

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

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

- [ ] **AC-10e [L] (R5, final approach legality)** GIVEN a leader standing one cell inside a `SAFE` edge, a leader who rounds a wall corner between repaths, and a diagonal approach past a blocked corner, THEN on every frame the symbol's centre lies on a symbol-legal cell, the final approach is used only while the leader's cell is the path's target and every crossed cell is legal, and every A* query starts from a symbol-legal cell.

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

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-034-chase-target-offset.md`, `story-025-safe-cell-leader-never-noticed.md` (AC-9f, `SAFE` cells are not symbol-legal)
- Unlocks: `story-036-chase-gives-up-at-safe-zone.md`
