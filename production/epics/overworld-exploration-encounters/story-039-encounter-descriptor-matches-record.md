# Story 039: Game State receives an encounter descriptor matching the enc_ record field-for-field

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-29)
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0002: Game State & Scene Flow (shared `EncounterDescriptor` fields, Rule 6)
**ADR Decision Summary**: `start_encounter` builds an `EncounterDescriptor` from the `enc_` record and calls `machine.request_transition(Mode.BATTLE, payload)`; the descriptor's fields are the shared contract between Overworld and Game State (GDD rule 6 / Game State rule 6).
**ADR Version**: ADR-0012 2026-10-23; ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `EncounterDescriptor` and `BattleEntryPayload` are plain `RefCounted` payload classes (ADR-0002 Key Interfaces); no post-cutoff API is involved, but the HIGH rating follows ADR-0002's own Knowledge Risk (no `modules/core.md` reference page).

**Control Manifest Rules (this layer)**:
- Required: Encounters start only through `start_encounter()`; the descriptor comes from an `encounter` record — ADR-0012 §5
- Forbidden: Never hand-build descriptor fields outside the record; never diverge the descriptor between Overworld and Game State
- Guardrail: n/a

---

## Acceptance Criteria

- [x] **AC-14 [I] (R4/R5 × Game State rule 6)** GIVEN contact with a symbol whose `enc_` record is a fixture, THEN the Encounter descriptor Game State receives equals the record field for field: `encounter_id`, enemy IDs, `battle_stage_id`, `faction_id`, `is_boss`, `can_flee`, `retreat_allowed`.

---

## Implementation Notes

*Derived from ADR-0012 §5 and ADR-0002 Key Interfaces (`EncounterDescriptor`):*

This is the integration counterpart to story 038: it runs against the real
`GameStateMachine` (per the evidence tags' `[I]` test harness), not a stub, to
prove the descriptor actually reaching Game State matches the record.

- Author an `enc_` fixture record covering every descriptor field: `encounter_id`, `enemy_ids`, `battle_stage_id`, `faction_id`, `is_boss`, `can_flee`, `retreat_allowed`.
- Drive contact against the real `GameStateMachine.request_transition(Mode.BATTLE, payload)` and capture the `BattleEntryPayload.descriptor` it receives.
- Assert field-for-field equality against the fixture record — not just that a transition was requested, since a field-mapping bug would otherwise pass a looser check.
- `enemy_ids` and `battle_stage_id` etc. are "exactly the descriptor's fields" per ADR-0012 §3's `EncounterData` — there is no transformation step between record and descriptor to get wrong, so a mismatch here means a copy-paste or field-order bug, not a formula.

---

## Out of Scope

- `story-038-contact-starts-encounter-once.md`: that `start_encounter` is called once, with stubs.
- `story-049-thaw-preserves-mid-chase-snapshot.md`: the return trip (Battle → Overworld) snapshot.

---

## Files

- `src/overworld/overworld_mode.gd`
- `src/data/records/encounter_data.gd`
- `tests/integration/overworld/encounter_descriptor_matches_record_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/overworld/encounter_descriptor_matches_record_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `story-038-contact-starts-encounter-once.md`, `game-state-scene-flow/story-001-overworld-to-battle-signal-order.md`
- Unlocks: `story-049-thaw-preserves-mid-chase-snapshot.md`

---

## Completion Notes

**Completed**: 2026-10-29 (implemented, awaiting /story-done)

- Integration test against the real `GameStateMachine` (GameStateFixtures, stub loader/presenter): the payload captured at `begin_swap` carries a descriptor equal to the fixture `enc_` record on all seven fields (fixture sets `can_flee = false` against the descriptor's `true` default to catch a missed copy). `src/data/records/encounter_data.gd` needed no change.
- Deviations (flagged): `start_encounter` returns the machine's `RequestResult` (ADR-0012 §4 Key Interfaces says `void`); a MapExit crossing only emits `map_exit_requested` and ends the frame (the MapChanging request is a TODO for the map-change stories); `grace_active` exists but nothing sets it yet (story 047); the battle party comes from an injected `party_source` Callable (empty by default) until the Squad Roster / ChapterFlow interim source is wired; the encounter catalog is injected (`encounter_catalog`, duck-typed `get_record`) and the game does not wire it or register symbols yet.
- Also in this change: `GroundMover.step()` corner assist is now opt-in (`corner_assist = true`, leader only, ADR-0012 §2.3); tested by `tests/unit/overworld/ground_mover_corner_assist_leader_only_test.gd`.
- Full suite: 780/780 passing.
- Status synced 2026-10-30 from commit a93f8a2.
