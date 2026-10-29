# Story 031: Chasing moves at v_chase and repaths no more than once per repath_s

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: In Chasing, `SymbolBrain` moves at `v_chase` along an `AStarGrid2D` path, repathing only when the target cell changes or a `set_blocked` call invalidates the path, at most once per `repath_s`.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: `AStarGrid2D.get_id_path()` is probed deterministic with `allow_partial_path = false`; a dirty grid silently returns `[]`, so the fixture's grid must be baked once and never re-dirtied mid-test.

**Control Manifest Rules (this layer)**:
- Required: Movement goes through the pure static `GroundMover.step(...)`; symbol AI lives in the pure `SymbolBrain` — ADR-0012 §2, §5
- Forbidden: Never call `AStarGrid2D.update()` outside the bake — ADR-0012 §2
- Guardrail: Overworld symbol stepping + notice searches + repaths ≤ 2.0 ms per frame at p99 — ADR-0012 Performance

---

## Acceptance Criteria

- [ ] **AC-10a [L] (R5)** GIVEN Chasing, THEN the symbol's speed is `v_chase`, and the pathfinder spy records at most one repath per `repath_s`, none while the target cell is unchanged and no `set_blocked` call happened, and at most `repath_per_frame_max` queries (notice and repath together) across all symbols on any frame.

---

## Implementation Notes

*Derived from ADR-0012 §5 and GDD rule 5 (Chasing row and "Path distance"):*

Chasing is the sub-state that moves at speed and spends the query budget on
repaths rather than notice searches.

- Assert displacement over N frames equals `v_chase · Σdt` (within the formula test's 1e-4 tolerance), the same pattern as the leader's AC-1a.
- The repath spy must record **zero** repaths while the chase target's cell is unchanged and no `set_blocked` call has run, and at most one per `repath_s` once it starts repathing — test both a static-target window and a moving-target window.
- Reuse story 030's combined-budget assertion (notice + repath ≤ `repath_per_frame_max` on any frame) with at least one Chasing symbol and one Patrol symbol noticing in the same fixture, since the budget is shared across sub-states.
- A chase's **first** path is the notice search's own path, reused rather than re-queried (GDD rule 5, "Path distance") — this story only needs the repath throttle to hold after that reuse.

---

## Out of Scope

- `story-032-chase-give-up-path-distance.md`: when Chasing ends.
- `story-034-chase-target-offset.md`: what cell the chase targets.
- `story-035-final-approach-legality.md`: the straight-line final approach.

---

## Files

- `src/overworld/symbol_brain.gd`
- `src/overworld/ground_mover.gd`
- `tests/unit/overworld/symbol_brain_chase_speed_repath_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/symbol_brain_chase_speed_repath_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-021-notice-delay-before-chasing-starts.md` (AC-9b, Noticing → Chasing transition), `story-030-cross-component-query-budget.md`
- Unlocks: `story-032-chase-give-up-path-distance.md`, `story-034-chase-target-offset.md`, `story-035-final-approach-legality.md`
