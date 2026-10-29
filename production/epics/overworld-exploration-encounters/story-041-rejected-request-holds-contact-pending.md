# Story 041: A rejected encounter request holds contact pending and retries every frame

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0002: Game State & Scene Flow (`request_transition` rejection, `RequestResult.REJECTED_BUSY`)
**ADR Decision Summary**: While `start_encounter` is rejected because a transition is already running, the touched symbol holds still in contact pending and retries next frame; the rejection is logged once per contact, not once per frame.
**ADR Version**: ADR-0012 2026-10-23; ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `RequestResult.REJECTED_BUSY` is a foundational `GameStateMachine` enum value (ADR-0002 Key Interfaces); HIGH risk follows ADR-0002's own rating (no `modules/core.md` reference page), not any post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: Encounters start only through `start_encounter()`; a rejected request leaves the touched symbol in contact pending — ADR-0012 §5
- Forbidden: Never let a contact-pending symbol move, or change sub-state, while the overlap holds
- Guardrail: n/a

---

## Acceptance Criteria

- [x] **AC-16 [L] (Edge Cases)** GIVEN `start_encounter` rejected for 30 frames while the bodies overlap, THEN the symbol does not move, the request is retried every frame, one rejection is logged, and the first accepted frame enters Frozen.

---

## Implementation Notes

*Derived from ADR-0012 §5 and GDD Edge Cases ("If `start_encounter` is rejected"):*

- Stub `machine.request_transition` to return `REJECTED_BUSY` for 30 consecutive frames while the leader and symbol stay overlapped; assert the symbol does not move and keeps its pre-contact sub-state across all 30 frames (contact pending, GDD rule 5).
- Assert the request is retried **every** frame the overlap holds — not once, not on a timer.
- Assert exactly **one** rejection is logged across the whole 30-frame window, not one per frame (GDD Edge Cases: "The rejection is logged once per contact, not once per frame").
- On the 31st frame, stub the request to succeed; assert the mode enters Frozen (the States and Transitions table's EncounterStarting → Frozen edge) on that same frame.

---

## Out of Scope

- `story-038-contact-starts-encounter-once.md`: the accepted-on-first-try path.
- `story-042-two-symbols-contact-tiebreak.md`: which symbol starts the encounter when two touch at once.

---

## Files

- `src/overworld/overworld_mode.gd`
- `src/overworld/symbol_brain.gd`
- `tests/unit/overworld/overworld_mode_contact_pending_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/overworld_mode_contact_pending_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `story-038-contact-starts-encounter-once.md`, `game-state-scene-flow/story-008-busy-transition-rejects-requests.md`
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-29 (implemented, awaiting /story-done)

- `SymbolBrain.contact_pending` (resolves story 027's TODO): `step()` holds the symbol still while set; `OverworldMode` retries `start_encounter` every frame the swept overlap holds, logs (push_warning + `rejections_logged`) only on the first rejection of a contact, and releases the hold when the overlap ends. `SymbolBrain.on_contact()` stores the resume point for a Patrol contact. Test: 30 REJECTED_BUSY frames then OK on frame 31 -> Frozen.
- Deviations (flagged): `start_encounter` returns the machine's `RequestResult` (ADR-0012 §4 Key Interfaces says `void`); a MapExit crossing only emits `map_exit_requested` and ends the frame (the MapChanging request is a TODO for the map-change stories); `grace_active` exists but nothing sets it yet (story 047); the battle party comes from an injected `party_source` Callable (empty by default) until the Squad Roster / ChapterFlow interim source is wired; the encounter catalog is injected (`encounter_catalog`, duck-typed `get_record`) and the game does not wire it or register symbols yet.
- Also in this change: `GroundMover.step()` corner assist is now opt-in (`corner_assist = true`, leader only, ADR-0012 §2.3); tested by `tests/unit/overworld/ground_mover_corner_assist_leader_only_test.gd`.
- Full suite: 780/780 passing.
