# Story 022: The notice radius is wider in front than behind, split by the symbol's facing

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: The notice test's cheap first check splits the radius by half-plane: `symbol_chase_m` across the symbol's front half-plane, `symbol_notice_rear_m` across its rear half-plane, measured centre to centre — letting a player slip behind a patrol but never past its nose.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Pure half-plane distance comparison; no engine API involved.

**Control Manifest Rules (this layer)**:
- Required: "Symbol AI lives in the pure `SymbolBrain` (sub-states... notice with cheap checks first...)" — source: ADR-0012 §5
- Required: "A symbol's logical facing is snapped to its displayed facing" — source: ADR-0012 §2, §5 (the facing that decides which half-plane applies)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-9c [L] (R5, facing)** GIVEN the leader in the rear half-plane at a distance between `symbol_notice_rear_m` and `symbol_chase_m`, THEN no notice. Inside `symbol_notice_rear_m`, THEN notice.

---

## Implementation Notes

*Derived from ADR-0012 §5 and GDD rule 5's notice test, check 1:*

GDD rule 5: "the leader's centre is within the **notice radius**:
`symbol_chase_m` across the symbol's front half-plane and
`symbol_notice_rear_m` across its rear half-plane, measured centre to
centre. A player can slip behind a Clerk, but not past its nose."
`symbol_notice_rear_m`'s Tuning Knobs row: default 1.5 m, safe range 1.5–3.0,
capped at `symbol_chase_m` (I12: "Sneaking is impossible" at the high end).

- Fixture a stationary symbol with a fixed facing; place the leader in the rear half-plane at a distance strictly between `symbol_notice_rear_m` and `symbol_chase_m` — assert the notice test fails at check 1 (no search even attempted).
- Place the leader inside `symbol_notice_rear_m` in the rear half-plane — assert notice fires (subject to the later checks: `SAFE`, component, bounded search, all held eligible in this fixture so check 1 is isolated).
- This story does not test the front-half-plane radius itself (covered implicitly by story 021's fixture) or the boundary-exactly-on-the-dividing-line case (that is AC-9g's concern, story 026).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 021: the Noticing timer/hold once the radius check passes.
- Story 023: the bounded-search reachability check (check 4).
- Story 025: the `SAFE`-cell exclusion (check 2).
- Story 026: facing exactly on the half-plane boundary.

---

## Files

- `src/overworld/symbol_brain.gd`
- `tests/unit/overworld/symbol_brain_notice_radius_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/symbol_brain_notice_radius_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing (full suite 726/726 after stories 021-027, 2026-10-29)

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-020-patrol-loop-and-pingpong-traversal.md`
- Unlocks: None

---

## Completion Notes

**Implemented**: 2026-10-29
- Check 1 in `SymbolBrain._notice_test()`: `symbol_chase_m` when `offset.dot(diagonal) >= 0`, else `symbol_notice_rear_m`; `notice_tests_run`/`notice_searches_run` diagnostic counters prove check 1 rejects before any search.
- Config: `symbol_chase_m` 3.0, `symbol_notice_rear_m` 1.5.
- Tests: `tests/unit/overworld/symbol_brain_notice_radius_test.gd` (5): rear band rejected with 0 searches, inside rear noticed, same distance in front noticed; default + custom.
- `SymbolBrain.step()` widened to `step(dt, leader, grid, grace, cfg)` (stories 021-025 share one notice-test implementation in `src/overworld/symbol_brain.gd`). `tests/unit/overworld/symbol_brain_patrol_test.gd` (story 020) updated to the new signature, `heading` (the raw movement direction, renamed from `facing`), and `turn_pause_s = 0` so its uninterrupted arc-length checks still hold.

**Deviations**: none.
