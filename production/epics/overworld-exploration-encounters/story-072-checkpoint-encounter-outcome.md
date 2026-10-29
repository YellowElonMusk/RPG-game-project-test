# Story 072: An encounter-outcome checkpoint starts its linked fight, and Victory opens it

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: A checkpoint's `encounter` failure outcome calls `start_encounter(enc_id, source)`, which builds the `EncounterDescriptor` and requests `Mode.BATTLE`; the two-step thaw's Victory branch opens the checkpoint.
**ADR Version**: ADR-0012 2026-10-23; ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No new runtime API; risk follows ADR-0002's row for `request_transition`/thaw (HIGH).

**Control Manifest Rules (this layer)**:
- Required: Encounters start only through `start_encounter(enc_id, source)` from an `encounter` record; a rejected request leaves the touched symbol in contact pending — source: ADR-0012 §5
- Forbidden: Never configure encounters inline on scene markers — source: ADR-0012 (Alternative 4)
- Guardrail: Overworld symbol stepping + notice searches + repaths ≤ 2.0 ms per frame at p99 — source: ADR-0012 Performance, Overworld GDD AC-46

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-28c [L] (R10)** GIVEN an unmet requirement with `encounter`, THEN the linked encounter starts, and a Victory opens the checkpoint.

---

## Implementation Notes

*Derived from GDD rule 10 ("Failure" outcomes) and ADR-0012 §5:*

- Rule 10, Failure branch `encounter`: a linked Clerk encounter starts via `start_encounter(enc_id, source)`, and winning it opens the checkpoint — resolved through the two-step thaw's Victory branch (rule 7), which this story wires the checkpoint's own open call into.
- Rule 10, "On the critical path": a checkpoint with the `encounter` outcome is **not allowed**, except as the region's story encounter (rule 13a). This story implements the generic mechanism only; the story-encounter-specific placement rules are checked in story-075 (AC-30b).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-070-checkpoint-opens-on-met-requirement: the success branch (AC-28a)
- story-071-checkpoint-redirect-and-queue-failure: the `redirect`/`queue` failure outcomes (AC-28b)
- story-075-town-dungeon-story-encounter-and-boss-placement: the story encounter's own placement rules (AC-30b)

---

## Files

- `src/overworld/overworld_mode.gd` (encounter-outcome checkpoint → `start_encounter`)
- `src/overworld/markers/interactable_checkpoint.gd`
- `tests/unit/overworld/checkpoint_encounter_outcome_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/checkpoint_encounter_outcome_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-070-checkpoint-opens-on-met-requirement.md`, `story-039-encounter-descriptor-matches-record.md` (AC-14, encounter-start integration)
- Unlocks: `production/epics/overworld-exploration-encounters/story-073-checkpoint-requirement-and-critical-path-reachability.md`
