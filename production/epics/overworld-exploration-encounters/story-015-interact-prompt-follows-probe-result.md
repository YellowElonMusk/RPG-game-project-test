# Story 015: The interact prompt is drawn over exactly the current probe() result

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
**ADR Decision Summary**: The on-map interact prompt reads the same `probe()` result that drives `confirm`, so the prompt always marks what `confirm` will do; it must also respect the same transition/overlay/redirect lockouts as `probe()` itself, hiding rather than showing a stale target.
**ADR Version**: ADR-0012 2026-10-23; ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Shares ADR-0002's HIGH risk through the transition/redirect state the prompt must hide against; the draw logic itself is plain UI code.

**Control Manifest Rules (this layer)**:
- Required: "`probe()`... The interact prompt draws from the same result" — source: ADR-0012 §6, GDD rule 3
- Required: "No probe runs and no interaction starts while a transition is running or any overlay is open" — source: GDD rule 3 (the same condition that must hide the prompt)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-7e [L] (R3, UI)** On every frame of a scripted walk past 3 targets, the interact prompt is drawn above exactly one target, the `probe()` result (or is hidden when there is none). It is hidden while a transition, overlay or redirect runs. (Absorbs the former AC-44c.)

---

## Implementation Notes

*Derived from ADR-0012 §6 and GDD rule 3:*

GDD rule 3: "The on-map interact prompt (UI Requirements) is drawn over the
current `probe()` result. `confirm` acts on that same result, so the prompt
always marks what `confirm` will do." This story is a scripted walk-through,
not a single-frame snapshot, because the prompt must track a moving
`probe()` result continuously, including through the three lockout states.

- Script a walk past 3 targets positioned so each becomes the nearest eligible target in turn, with gaps where none is in reach.
- Every frame, assert the prompt either matches `probe()`'s current result exactly (drawn above that one target) or is hidden (when `probe()` is null).
- Insert a transition, then an overlay open, then a redirect (same-instance fade) partway through the walk and assert the prompt is hidden throughout each, re-appearing correctly once the lockout clears and `probe()` resumes.
- This absorbs the former AC-44c per the AC text — no separate story exists for that ID; this is its only home.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 011: the tie-order/search logic `probe()` itself runs.
- Story 013: the lockout gate's own condition logic.
- Story 016: per-kind eligibility (what makes a target returnable at all).

---

## Files

- `src/overworld/overworld_mode.gd`
- `tests/unit/overworld/interact_prompt_test.gd`
- `production/qa/evidence/` (UI screenshot)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/interact_prompt_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-011-probe-nearest-target-tie-order.md`
- Unlocks: None
