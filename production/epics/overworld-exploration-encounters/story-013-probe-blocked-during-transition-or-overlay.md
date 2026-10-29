# Story 013: No probe or interaction starts during a transition or while any overlay is open

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine; ADR-0002: Game State & Scene Flow
**ADR Decision Summary**: `probe()` must not run, and `confirm` must start nothing, while a transition is running or any overlay (Menu, Dialogue, CampPrompt) is open — a lockout read from Game State's own `current_mode`/`phase`/`overlay_stack`, not something the Overworld tracks itself.
**ADR Version**: ADR-0012 2026-10-23; ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: ADR-0002's Knowledge Risk is HIGH because its foundational Core APIs (`Node.add_child`/`remove_child`, `process_mode`, `CanvasLayer`) are not yet covered by `docs/engine-reference/godot/`, despite being low-level in isolation.

**Control Manifest Rules (this layer)**:
- Required: "No probe runs and no interaction starts while a transition is running or **any** overlay is open, Dialogue included" — source: GDD rule 3, ADR-0012 §6
- Required: "`request_in_mode_fade` is legal only when `current_mode == OVERWORLD`, `phase == IDLE` and no overlay is open" — source: ADR-0002 §11 (the same state this lockout reads)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-7c [L] (R3)** During a transition, or with any overlay open (Menu, Dialogue, CampPrompt), `probe()` is not called and `confirm` starts nothing.

---

## Implementation Notes

*Derived from ADR-0012 §6 and GDD rule 3:*

GDD rule 3's "Lockouts" clause: "No probe runs and no interaction starts
while a transition is running or **any** overlay is open, Dialogue included.
Input inside an overlay belongs to the overlay." This story tests the gate
itself, not what the overlay does with the input once it owns it (story 014).

- Use the test harness's Game State stub to drive each lockout condition independently: a transition in progress, Menu open, Dialogue open, CampPrompt open.
- In every one of those states, assert `probe()` is never invoked by the mode's `confirm` handling, and no interaction (overlay open, state change, audio) results from a `confirm` press.
- The lockout check reads Game State's own mode/overlay state (stubbed here); the Overworld does not duplicate that bookkeeping.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 011/012: `probe()`'s own target search and empty-reach case, both assumed to run only outside lockouts.
- Story 014: what happens to the `confirm` press that closes an overlay (consumed, not passed through).

---

## Files

- `src/overworld/overworld_mode.gd`
- `tests/unit/overworld/probe_lockout_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/probe_lockout_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-011-probe-nearest-target-tie-order.md`; Game State mode/overlay machinery (`production/epics/game-state-scene-flow/`, epic done)
- Unlocks: `production/epics/overworld-exploration-encounters/story-014-confirm-close-overlay-held-press-guard.md`
