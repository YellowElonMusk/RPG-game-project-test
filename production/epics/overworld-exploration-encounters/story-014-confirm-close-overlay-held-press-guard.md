# Story 014: The confirm that closes a Dialogue is consumed, and a held press starts nothing new

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
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
**ADR Decision Summary**: The `confirm` press that closes an overlay is consumed by the overlay and never reaches `probe()`; a new `confirm` is accepted only after release, so a closing press held down cannot immediately reopen or start a new interaction. This is `interaction-patterns.md` P2's carry-over idea, applied at the overlay-close boundary.
**ADR Version**: ADR-0012 2026-10-23; ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: ADR-0002's Knowledge Risk is HIGH for the same reason as story 013 (uncovered Core APIs); the held-press guard itself is simple GDScript state, not an engine-specific concern.

**Control Manifest Rules (this layer)**:
- Required: "The `confirm` press that closes an overlay is consumed by the overlay and never reaches `probe()`... A new `confirm` is accepted only after release, so closing a line cannot reopen it" — source: GDD rule 3, ADR-0012 §6
- Required: "Mode reads movement only through `machine.get_move_vector(self)`; discrete actions arrive only through `handle_action()`" — source: ADR-0002 Implementation Guidelines

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-7d [L] (R3)** GIVEN a Dialogue line opened at an NPC, WHEN the `confirm` that closes it is pressed and then **held for at least 10 frames**, THEN the overlay closes and no new interaction starts while it is held. A release followed by a new press starts one.

---

## Implementation Notes

*Derived from ADR-0012 §6 and GDD rule 3:*

This is the GDD's named reference to the carry-over idea from
`interaction-patterns.md` P2: a single physical press must not both close one
interaction and open the next. The 10-frame hold in the AC is deliberately
longer than any debounce window, so the test proves the guard holds for a
sustained press, not just a one-frame overlap.

- Open a Dialogue overlay at an NPC (via the interim `DialogueStubOverlay`, ADR-0012 §6, since the real Dialogue overlay has no ADR yet).
- Drive the synthetic action source: press `confirm` (closes the overlay), then hold it for at least 10 more frames. Assert the overlay is closed and no new `probe()`/interaction starts during the entire hold.
- Release `confirm`, then press it again: assert a new interaction can now start normally (falls through to story 011's tie-order search).
- Dialogue, Banter & Quests has no epic yet; this story depends on it only as a named dependency, and tests against the interim stub overlay ADR-0012 §6 already specifies.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 013: the lockout gate itself (transition/overlay open).
- Story 011: the tie-order search a fresh press after release falls through to.
- Dialogue, Banter & Quests' real overlay content (named dependency, no epic yet).

---

## Files

- `src/overworld/overworld_mode.gd`
- `tests/unit/overworld/probe_overlay_close_guard_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/probe_overlay_close_guard_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-013-probe-blocked-during-transition-or-overlay.md`; Dialogue, Banter & Quests (named dependency, no epic yet)
- Unlocks: None
