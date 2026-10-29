# Story 042: Two symbols touching the leader at once pick the smaller closest-approach distance

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0002: Game State & Scene Flow (`transition_finished` after the thaw)
**ADR Decision Summary**: Contact is a swept circle test; when two symbols touch the leader the same frame, the one with the smaller closest-approach distance starts the encounter, ties broken by marker order, and the other switches to Returning once grace starts.
**ADR Version**: ADR-0012 2026-10-23; ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `transition_finished` is a foundational `GameStateMachine` signal (ADR-0002); HIGH risk follows ADR-0002's rating, not a post-cutoff API concern.

**Control Manifest Rules (this layer)**:
- Required: Contact is a swept circle test, never a physics query; MVP battles never merge symbols — ADR-0012 §5, GDD Edge Cases
- Forbidden: Never start two encounters from one frame's contact
- Guardrail: n/a

---

## Acceptance Criteria

- [ ] **AC-17 [L] (Edge Cases)** GIVEN two symbols in contact on the same frame, THEN the one with the smaller closest-approach distance starts the encounter. On an exact tie, the earlier one in marker order does. On `transition_finished` after the thaw, the other is in Returning.

---

## Implementation Notes

*Derived from GDD Edge Cases ("If two symbols touch the leader on the same frame"):*

- Build a fixture where two symbols both swept-contact the leader on the same frame, with distinguishable closest-approach distances; assert the smaller-distance symbol's `enc_` ID is the one passed to `start_encounter`, and the other is left untouched that frame (still Patrol/Noticing/Chasing, not resolved).
- Build a second fixture with an **exact** tie in closest-approach distance; assert the symbol earlier in marker order starts the encounter.
- After the (stubbed) thaw's `transition_finished` fires, assert the **other** (non-fighting) symbol has been switched to Returning — this is the grace-start transition from GDD rule 7 ("Any symbol in Noticing or Chasing when grace starts switches to Returning"), triggered here by the same-frame contact rather than an independent notice/chase.
- MVP battles never merge the two symbols into one fight (GDD Edge Cases) — assert the losing symbol's own `enc_` is never passed anywhere during this sequence.

---

## Out of Scope

- `story-038-contact-starts-encounter-once.md`: single-symbol contact.
- `story-047-encounter-grace-starts-on-reveal.md`: grace timing itself.

---

## Files

- `src/overworld/overworld_mode.gd`
- `tests/unit/overworld/overworld_mode_contact_tiebreak_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/overworld_mode_contact_tiebreak_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-038-contact-starts-encounter-once.md`
- Unlocks: None
