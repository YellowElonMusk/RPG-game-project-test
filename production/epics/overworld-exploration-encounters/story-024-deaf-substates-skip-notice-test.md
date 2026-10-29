# Story 024: Returning, Stunned, cooldown and grace all skip the notice test entirely

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

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: The notice test "runs only in Patrol, outside the cooldown, and outside encounter grace" — Returning and Stunned are explicitly deaf and intangible sub-states, and any symbol during encounter grace is excluded regardless of its own sub-state, so the test must not even begin, whatever the leader's position.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Pure sub-state gating, evaluated before any of the four notice checks run; no engine API involved.

**Control Manifest Rules (this layer)**:
- Required: "Symbol AI lives in the pure `SymbolBrain` (sub-states, notice with cheap checks first...)" — source: ADR-0012 §5
- Guardrail: "Overworld symbol stepping + notice searches + repaths: ≤ 2.0 ms per frame at p99" — source: ADR-0012 Performance (a skipped test costs nothing, which is the point)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-9e [L] (R5, deaf states)** GIVEN a symbol in Returning, Stunned or the re-notice cooldown, or any symbol during encounter grace, THEN the notice test does not run, whatever the leader's position.

---

## Implementation Notes

*Derived from ADR-0012 §5 and GDD rule 5's Returning/Stunned rows plus the notice test's opening clause:*

GDD rule 5: "**Notice test.** It runs only in Patrol, outside the cooldown,
and outside encounter grace." The Returning and Stunned rows both say
"**Deaf and intangible**: no notice test, no contact." Rule 7's grace clause:
"During grace no symbol notices, and none makes contact... a Patrol symbol
stays in Patrol but cannot make contact during grace" — grace suppresses
notice **and** contact independent of sub-state.

- Four fixtures, each with the leader placed well inside what would otherwise be a guaranteed-notice position (front half-plane, within `symbol_chase_m`, reachable path): (1) sub-state Returning, (2) sub-state Stunned, (3) Patrol but within `renotice_cooldown_s` of a prior Returning→Patrol transition, (4) any sub-state during encounter grace.
- In every fixture, assert the notice test function is never entered (a spy/counter on the notice-test entry point records zero calls) across multiple frames, not just that the sub-state happens not to change.
- This is a short-circuit **before** check 1 of the notice test (radius), distinct from the radius/path/SAFE checks themselves (stories 022, 023, 025), which only matter once the sub-state gate has already passed.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 021: the Noticing→Chasing timer (a different sub-state, not gated here).
- Story 025: the `SAFE`-cell exclusion, which applies even in Patrol (a different gate, check 2, not a sub-state gate).
- AC-10b/10c (outside this batch): the give-up test and the Returning walk-to-resume-point behaviour this sub-state's deafness protects.

---

## Files

- `src/overworld/symbol_brain.gd`
- `tests/unit/overworld/symbol_brain_deaf_substates_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/symbol_brain_deaf_substates_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-020-patrol-loop-and-pingpong-traversal.md`
- Unlocks: None
