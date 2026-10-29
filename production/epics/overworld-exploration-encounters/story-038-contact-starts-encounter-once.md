# Story 038: Contact calls start_encounter exactly once with the record's enc_ ID

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters (battle request routed through ADR-0002)
**ADR Decision Summary**: Contact is a swept circle test with no physics query; the first contact in a frame calls `start_encounter(enc_id, symbol)`, which builds the descriptor and calls `machine.request_transition(Mode.BATTLE, payload)`.
**ADR Version**: ADR-0012 2026-10-23; ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `request_transition` and its `RequestResult` enum are foundational, pre-4.0-era APIs (ADR-0002), carrying HIGH knowledge risk only because no `modules/core.md` engine-reference page exists yet to cross-check against — not because the APIs themselves are new.

**Control Manifest Rules (this layer)**:
- Required: Encounters start only through `start_encounter(enc_id, source)` from an `encounter` record — ADR-0012 §5
- Forbidden: Never configure encounters inline on scene markers; never call `request_transition` from anywhere but `start_encounter` — ADR-0012 (Alternative 4)
- Guardrail: n/a

---

## Acceptance Criteria

- [x] **AC-13 [L] (R5, R6)** GIVEN contact, THEN `start_encounter` is called once with the record's `enc_` ID. The descriptor is identical whatever the contact direction or which body moved.

---

## Implementation Notes

*Derived from ADR-0012 §5 and GDD rule 6 (no ambush/first-strike bonus):*

Rule 6 is the reason this AC insists the descriptor never varies by contact
direction: Turn Battle's turn order is fixed regardless of who touched whom.

- Spy on `start_encounter` (or the `OverworldMode` method it calls) and assert it fires **exactly once** per contact, with the symbol's own `enc_` ID, never a default or a different symbol's.
- Vary the contact fixture across at least three cases: leader walks into a stationary symbol, symbol walks into a stationary leader, and both moving toward each other — assert the built `EncounterDescriptor` is field-for-field identical across all three.
- This story only needs `start_encounter` to be called correctly; the descriptor's field values matching the `enc_` record is verified at the integration level by story 039.

---

## Out of Scope

- `story-039-encounter-descriptor-matches-record.md`: that the descriptor's fields equal the record's, verified against the real Game State.
- `story-040-exit-beats-contact-same-frame.md`: contact versus a same-frame exit.
- `story-042-two-symbols-contact-tiebreak.md`: two symbols contacting the same frame.

---

## Files

- `src/overworld/overworld_mode.gd`
- `src/overworld/symbol_brain.gd`
- `tests/unit/overworld/overworld_mode_contact_start_encounter_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/overworld_mode_contact_start_encounter_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `story-036-chase-gives-up-at-safe-zone.md`, `game-state-scene-flow/story-001-overworld-to-battle-signal-order.md`
- Unlocks: `story-039-encounter-descriptor-matches-record.md`, `story-040-exit-beats-contact-same-frame.md`, `story-041-rejected-request-holds-contact-pending.md`, `story-042-two-symbols-contact-tiebreak.md`

---

## Completion Notes

**Completed**: 2026-10-29 (implemented, awaiting /story-done)

- `OverworldMode.step_frame()` runs ADR-0012 §5's frame order; `_check_contact()` is the swept circle test (`closest_approach()`, GDD frame_step_safety); `start_encounter(enc_id, source)` builds the descriptor from the `encounter` record (`build_descriptor()`) and calls `machine.request_transition(Mode.BATTLE, payload)`; accepted -> `State.FROZEN`, so a contact calls it once. New `src/overworld/encounter_source.gd`. Test: three contact directions (leader moves, symbol moves, both), descriptors field-for-field identical, plus a non-default config.
- Deviations (flagged): `start_encounter` returns the machine's `RequestResult` (ADR-0012 §4 Key Interfaces says `void`); a MapExit crossing only emits `map_exit_requested` and ends the frame (the MapChanging request is a TODO for the map-change stories); `grace_active` exists but nothing sets it yet (story 047); the battle party comes from an injected `party_source` Callable (empty by default) until the Squad Roster / ChapterFlow interim source is wired; the encounter catalog is injected (`encounter_catalog`, duck-typed `get_record`) and the game does not wire it or register symbols yet.
- Also in this change: `GroundMover.step()` corner assist is now opt-in (`corner_assist = true`, leader only, ADR-0012 §2.3); tested by `tests/unit/overworld/ground_mover_corner_assist_leader_only_test.gd`.
- Full suite: 780/780 passing.
