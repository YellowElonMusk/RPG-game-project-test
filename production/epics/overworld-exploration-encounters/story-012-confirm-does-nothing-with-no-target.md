# Story 012: With nothing in reach, confirm does nothing and makes no sound

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine; ADR-0003: Input System
**ADR Decision Summary**: `probe()` returning null means `confirm` opens nothing and plays no audio; ADR-0003 is cited for the pointer-input half of this AC — pointer events must never substitute for `confirm` or cause an interaction on the overworld map.
**ADR Version**: ADR-0012 2026-10-23; ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: The pointer-ignored guarantee rests on ADR-0003's action/pointer separation, a HIGH-risk post-cutoff surface; `probe()` itself touches nothing engine-specific.

**Control Manifest Rules (this layer)**:
- Required: "Interaction is one `probe()` (nearest eligible target...) that drives both the prompt and `confirm`" — source: ADR-0012 §6
- Required: "Pointer input is ignored (`input-system.md` rule 3)" — source: ADR-0012 §6, ADR-0003

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-7b [L] (R3)** With nothing in reach, `confirm` opens nothing and the audio spy records zero events. Pointer events cause no interaction.

---

## Implementation Notes

*Derived from ADR-0012 §6 and GDD rule 3:*

GDD rule 3: "Nothing in reach. `confirm` does nothing and makes no sound,"
and "Pointer input is ignored (`input-system.md` rule 3)." This is the
simplest probe outcome and the one every eligibility and lockout story (013,
014, 016) ultimately falls back to.

- Fixture with no target within `interact_reach_m` of the probe point (or no target on the map at all).
- Assert `probe()` returns null, `confirm` opens no overlay and triggers no state change, and an audio spy attached for this test records zero events.
- Separately, drive synthetic pointer events (click/tap) at any on-screen position and assert no interaction starts — the overworld must not wire pointer input to `probe()`/`confirm()` at all, per ADR-0003's input GDD rule 3.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 011: the positive case (a target found, with ties).
- Story 013: lockouts during transitions/overlays (a different reason confirm does nothing).
- Story 016: eligibility rules for targets that exist but are ineligible.

---

## Files

- `src/overworld/overworld_mode.gd`
- `tests/unit/overworld/probe_empty_reach_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/probe_empty_reach_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-011-probe-nearest-target-tie-order.md`
- Unlocks: None
