# Story 062: Liberation grumble share meets its floor; respawned Clerks use the deflated look

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-010`, `TR-overworld-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: The grumbling civilian share is a data floor (`liberation_grumble_min`) drawn from `OverworldMode`'s own seeded `RandomNumberGenerator`; a respawned Clerk on a liberated street swaps only its sprite set, never its behaviour parameters.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Pure GDScript; the only engine-adjacent concern is RNG seeding per visit, which the Guidelines call out as needing nothing special (REASONED, not probed).

**Control Manifest Rules (this layer)**:
- Required: Randomness comes only from `OverworldMode`'s own seeded `RandomNumberGenerator` — source: ADR-0012 Guidelines
- Forbidden: Never store a scene path on `MapData` — breaks Content Data Rule 3 — source: ADR-0012 (Alternative 5)
- Guardrail: Overworld symbol stepping + notice searches + repaths ≤ 2.0 ms per frame at p99 — source: ADR-0012 Performance, Overworld GDD AC-46

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-26d [L] (R9)** GIVEN a liberation with N reacting civilians, THEN at least `ceil(liberation_grumble_min · N)` play the grumble beat. GIVEN a Clerk respawned onto a liberated street, THEN its sprite set is the deflated variant and its behaviour parameters equal the normal Clerk's.

---

## Implementation Notes

*Derived from GDD rule 9 ("Reactions are mixed", "Permanence"):*

- The share of civilians who grumble is data, with a floor of `liberation_grumble_min` (an `OccupationStageData` field) — some grumble that the queue was the only orderly thing in Paris (Pillar 2: reactions are mixed, never unanimous relief).
- At least one reaction per map ribs the squad (checked separately, story-063).
- A Clerk respawned onto a liberated street uses a **deflated** look — a sheepish pose, no clipboard flourish — with **unchanged behaviour** (rule 5): same sub-state machine, same speeds, same notice/give-up parameters as the normal Clerk record. Only the sprite set differs.
- The grumble roll draws only from `OverworldMode`'s own seeded RNG (control manifest), never `randi()`/`randf()` directly, so the test can assert deterministically against a fixed seed.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-063-liberation-reaction-ribs-squad-tag: the ribs-squad tag's presence in data (AC-26e)
- story-061-liberation-screenshots-poster-queue-checkpoint: visual evidence of liberation (AC-26b)

---

## Files

- `src/overworld/overworld_mode.gd` (liberation reaction roll, seeded RNG)
- `src/overworld/markers/clutter.gd`
- `tests/unit/overworld/liberation_reaction_and_deflated_clerk_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/liberation_reaction_and_deflated_clerk_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-059-liberated-set-persists-across-respawn-and-stage.md`, `story-060-liberation-removal-timing-on-screen-and-off-screen.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-063-liberation-reaction-ribs-squad-tag.md`
