# Story 037: Chase pathing edge cases — empty path, deferred repath, unreachable resume

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
**ADR Decision Summary**: A pending (budget-deferred) path is kept and is never treated as empty; a genuinely empty A* result counts as "beyond" for the give-up test; an unreachable resume point holds the symbol still, deaf, until reload, logging one warning.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: `AStarGrid2D.get_id_path()` returns `[]` for a target it cannot reach with `allow_partial_path = false` (probed, 4.7.2) — the fixture must distinguish that from a budget-deferred query returning nothing because it was never issued.

**Control Manifest Rules (this layer)**:
- Required: A pending path is never empty; `get_id_path(..., allow_partial_path = false)` — ADR-0012 §2, §5, Edge Cases
- Forbidden: Never treat a budget-deferred repath as a give-up signal — only a genuinely empty path (nothing pending) counts
- Guardrail: n/a

---

## Acceptance Criteria

- [ ] **AC-12 [L] (R5, Edge Cases)** GIVEN a pathfinder that returns an empty path at `t₀` during a chase, with nothing pending, THEN the symbol holds still, is still Chasing at `t₀ + giveup_s − dt` and Returning at `t₀ + giveup_s + dt`. GIVEN a first repath deferred by the budget, THEN the symbol follows the notice path and its give-up timer does not start. GIVEN an unreachable resume point, THEN it holds still, notices nothing until reload, and logs exactly one warning.

---

## Implementation Notes

*Derived from GDD Edge Cases ("If a chase path is empty", "If a symbol's first repath is deferred", "If the resume point is unreachable"):*

Three independent branches, one fixture each:

- **Empty path, nothing pending**: force the pathfinder stub to return `[]` at `t₀` with no deferred query outstanding; assert the symbol holds its position (no movement) and the give-up timer starts at `t₀`, landing on Chasing at `t₀ + giveup_s − dt` and Returning at `t₀ + giveup_s + dt` — this is the "beyond" branch of the give-up test (GDD rule 5).
- **First repath deferred by the budget**: saturate the per-frame budget (story 028's mechanism) so the chase's first repath is deferred; assert the symbol follows the **notice search's own path** (reused as the first chase path, per rule 5 "Path distance") and that the give-up timer does **not** start while the path is pending, never empty.
- **Unreachable resume point**: after give-up and Returning begins, make the resume point unreachable (block it); assert the symbol holds still, deaf (no notice test runs, matching Returning/Patrol-no-contact semantics), until the map reloads, and assert exactly **one** warning is logged, not one per frame.
- All three branches share the "pending is never empty" distinction (Edge Cases) — write it once as a shared helper assertion if the test harness allows, so the three fixtures do not duplicate that check three different ways.

---

## Out of Scope

- `story-032-chase-give-up-path-distance.md`: the `path_dist`-based give-up window.
- `story-033-returning-to-resume-point.md`: the ordinary (reachable) Returning walk.

---

## Files

- `src/overworld/symbol_brain.gd`
- `tests/unit/overworld/symbol_brain_chase_edge_cases_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/symbol_brain_chase_edge_cases_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-031-chase-speed-and-repath-throttle.md`, `story-033-returning-to-resume-point.md`
- Unlocks: None
