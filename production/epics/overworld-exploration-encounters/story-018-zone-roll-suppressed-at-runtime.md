# Story 018: At runtime, a non-zero zone_rate logs an error and no zone roll ever fires

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: This is the runtime half of rule 4's zone suppression: even if a bad record somehow reaches runtime (CI should have already caught it per story 017), the zone-roll mechanism must still behave as if `zone_rate = 0`, logging an error rather than rolling.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Pure runtime guard logic; no engine API involved.

**Control Manifest Rules (this layer)**:
- Required: "Randomness comes only from `OverworldMode`'s own seeded `RandomNumberGenerator` (MVP has no random rolls, since `zone_rate = 0`)" — source: ADR-0012 Implementation Guidelines
- Required: "MVP encounters come only from visible symbols; zones stay in code and data, and CI asserts `zone_rate = 0` on every MVP map" — source: ADR-0012 Summary, §3

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-8c [L] (R4)** At runtime a fixture map with `zone_rate = 0.1` logs an error, and the zone-roll spy records zero rolls over `ceil(60 / dt_max)` frames.

---

## Implementation Notes

*Derived from ADR-0012 §9 and GDD rule 4, Edge Cases:*

Edge Cases: "If an MVP `map_` record has `zone_rate > 0`: CI fails. At
runtime the value is treated as 0 and an error is logged." This story proves
the runtime belt-and-suspenders half, independent of whether CI (story 017)
has already run against this exact fixture.

- Load a fixture map record with `zone_rate = 0.1` directly into the runtime zone-roll check (bypassing CI, to test the runtime path in isolation).
- Assert exactly one error is logged (not one per frame) and a zone-roll spy records **zero** rolls across `ceil(60 / dt_max)` frames of simulated `Exploring` time — enough frames to cover a full second of wall time at the worst-case `dt_max`.
- The zone-roll mechanism itself stays in code per ADR-0012 §9 ("zones stay supported in code and data, at rate 0"); this story does not implement a zone encounter, only the suppression guard.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 017: the CI-time rejection of such a record before it ships.
- The zone encounter mechanism's own content and selection logic (code-and-data only, never exercised at `zone_rate = 0` in MVP; no story in this batch implements it further).

---

## Files

- `src/overworld/overworld_mode.gd`
- `src/data/records/map_data.gd`
- `tests/unit/overworld/data/zone_runtime_suppression_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/data/zone_runtime_suppression_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-017-zone-rate-zero-on-every-mvp-map.md`
- Unlocks: None
