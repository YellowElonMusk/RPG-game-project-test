# Story 017: Every MVP map record ships with zone_rate = 0, enforced in CI

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

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine; ADR-0001: Content Data
**ADR Decision Summary**: The zone encounter mechanism stays in code and data, but every MVP `map_` record must set `zone_rate = 0`, checked by `tools/ci/validate_maps.gd`; a fixture with `zone_rate = 0.1` must fail CI and name the offending record. This is a content-vocabulary rule, so ADR-0001's record and catalog validation layer governs it alongside ADR-0012.
**ADR Version**: ADR-0012 2026-10-23; ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: ADR-0001's Knowledge Risk sits at the project's HIGH tier (per the brief's risk table); no post-cutoff engine API is exercised directly by this CI check itself.

**Control Manifest Rules (this layer)**:
- Required: "`tools/ci/validate_maps.gd` runs after `validate-content.gd`, runs `ContentBootstrap.run()` first, loads and bakes every map, and asserts every [D] criterion of the Overworld GDD" — source: ADR-0012 §3
- Required: "Records never contain file paths; tuning comes from `OverworldConfig` or records, validated by `OverworldConfig.validate()`" — source: ADR-0012 §9

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-8 [D] (R4)** Every MVP `map_` record has `zone_rate = 0`. A fixture with `zone_rate = 0.1` fails CI, naming the record.

---

## Implementation Notes

*Derived from ADR-0012 §3 and GDD rule 4:*

GDD rule 4: "The zone mechanism stays in code and data (ADR-0012 §9), but
every MVP `map_` record sets `zone_rate = 0`. At 0, no zone roll is made, so
no zone encounter can happen." `zone_rate`'s own Tuning Knobs row confirms:
"Any value > 0 fails CI in MVP (symbols only)."

- `validate_maps.gd` iterates every shipped `map_` record and asserts `zone_rate == 0`, failing the CI run and naming the specific record ID when any record violates it.
- Add a deliberately-bad fixture record (`zone_rate = 0.1`) to the test's fixture set and assert the validator both fails and names that exact record — a validator that fails generically without naming the record does not satisfy this AC.
- This check runs after `validate-content.gd` and after `ContentBootstrap.run()` (ADR-0004 boot ordering), per the CI pipeline order ADR-0012 §3 fixes.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 018: the runtime behaviour when a fixture map somehow still carries `zone_rate > 0` (treated as 0, logged).
- Story 019: `patrol_archetype_id` resolution (a different `faction_`/`map_` CI check).

---

## Files

- `tools/ci/validate_maps.gd`
- `src/data/records/map_data.gd`
- `tests/unit/overworld/data/zone_rate_validation_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic (Config/Data CI gate)
**Required evidence**:
- `tests/unit/overworld/data/zone_rate_validation_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: `production/epics/overworld-exploration-encounters/story-018-zone-roll-suppressed-at-runtime.md`, `production/epics/overworld-exploration-encounters/story-019-faction-patrol-archetype-id-resolves.md`
