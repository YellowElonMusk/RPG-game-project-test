# Story 088: Contact with the boss never finds it moved, and its descriptor forbids Flee but allows Retreat

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-29)
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-007`, `TR-overworld-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0002: Game State & Scene Flow (`EncounterDescriptor` → `request_transition(BATTLE)`; Flee gated on `can_flee`)
**ADR Decision Summary**: The boss is a `Static` symbol with `start_on = contact_or_confirm` that never moves (rule 5); `start_encounter()` builds an `EncounterDescriptor` from its record, carrying `is_boss = true`, `can_flee = false` and `retreat_allowed = true` through to Game State's `request_transition(BATTLE)`.
**ADR Version**: ADR-0012 2026-10-23 · ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `GameStateMachine` is a pure `RefCounted`, no scene-tree reads; its detach/freeze mechanics were empirically probed on 4.7.2 headless (`remove_child`/`add_child` fire `_ready()` once in total; a detached `Timer`'s `time_left` does not advance) — not exercised directly by this story, but the descriptor it builds is what that machine consumes.

**Control Manifest Rules (this layer)**:
- Required: "Encounters start only through `start_encounter(enc_id, source)` from an `encounter` record" — source: ADR-0012 §5
- Required: "Its record sets `is_boss = true`, `can_flee = false`, `retreat_allowed = true` and `respawn = never`" — source: ADR-0012 §3 `EncounterData`, GDD rule 13

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-33a [I] (R13)** GIVEN contact with the boss, THEN the boss had not moved before contact, and the descriptor has `can_flee = false` and `retreat_allowed = true`.

---

## Implementation Notes

*Derived from ADR-0012 §3, §5 and GDD rule 13 ("Boss"):*

- The boss is a `Static` `EncounterSymbol` with `start_on = contact_or_confirm` (rule 5); `Static` symbols never move, so "the boss had not moved before contact" reduces to: log its position at the frame `start_encounter()` fires and assert it equals its placed position.
- Its `enc_` record sets `is_boss = true`, `can_flee = false`, `retreat_allowed = true`, `respawn = never` (rule 13). Assert the `EncounterDescriptor` built by `start_encounter(enc_id, source)` carries these fields unchanged into the `BattleEntryPayload`.
- This story proves the descriptor only. Game State's own refusal of Flee when `can_flee` is false is `game-state-scene-flow.md`'s test, out of scope here.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Game State's refusal of a Flee command when `can_flee` is false.
- Retreat's destination after a boss Defeat (story 089).
- The boss staying resolved across a later Retreat and Continue (story 090).

---

## Files

- `tests/integration/overworld/boss_contact_descriptor_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/overworld/boss_contact_descriptor_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-001-overworld-to-battle-signal-order.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-089-story-encounter-flee-returns-to-registered-camp.md`, `production/epics/overworld-exploration-encounters/story-090-boss-stays-resolved-through-retreat-and-continue.md`
