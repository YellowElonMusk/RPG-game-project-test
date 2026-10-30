# Story 019: Every faction record used by a shipped map names a resolving patrol_archetype_id

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine; ADR-0001: Content Data
**ADR Decision Summary**: `FactionData` gains `patrol_archetype_id` (the faction's symbol look and behaviour preset), an additive amendment to ADR-0001's record vocabulary; `validate_maps.gd` must confirm every `faction_` record a shipped map actually uses names an ID that resolves in the catalog.
**ADR Version**: ADR-0012 2026-10-23; ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: ADR-0001's record/catalog layer is HIGH risk per the brief's risk table; this check itself touches no post-cutoff engine API.

**Control Manifest Rules (this layer)**:
- Required: "`tools/ci/validate_maps.gd` runs after `validate-content.gd`... and asserts every [D] criterion of the Overworld GDD" including "every reference resolves (`enc_`, `map_`, `symbol_id`... payoffs, items...)" — source: ADR-0012 §3
- Required: "Records never contain file paths; tuning comes from `OverworldConfig` or records" — source: ADR-0012 §9

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-8b [D] (R4)** Every `faction_` record used by a shipped map names a `patrol_archetype_id` that resolves.

---

## Implementation Notes

*Derived from ADR-0012 §3 (`FactionData` amendment) and §3's `validate_maps.gd` reference-resolution checklist:*

GDD rule 4: "In the fiction, each symbol is its faction's patrol archetype,
data-defined per faction (`faction_` record, `patrol_archetype_id`) so each
faction's patrol is its own joke." Bureaucratia's is named directly as the
worked example: the Compliance Clerk.

- `validate_maps.gd` collects every `faction_id` actually referenced by a shipped map's symbols (via `MapData.faction_id` and/or per-symbol faction linkage) and asserts each resolves to a `faction_` record whose `patrol_archetype_id` field is non-empty and itself resolves in the catalog.
- A record with a `patrol_archetype_id` that does not resolve must fail CI and name both the faction record and the dangling ID.
- This check runs alongside story 017's `zone_rate` check inside the same `validate_maps.gd` pass, after `ContentBootstrap.run()`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 017: `zone_rate = 0` validation.
- The patrol archetype's own visual/behavioural preset content (art-director/level-designer content work, not a code story in this batch).

---

## Files

- `tools/ci/validate_maps.gd`
- `src/data/records/faction_data.gd`
- `tests/unit/overworld/data/patrol_archetype_resolution_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic (Config/Data CI gate)
**Required evidence**:
- `tests/unit/overworld/data/patrol_archetype_resolution_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing (2026-10-30, single-file run)

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-017-zone-rate-zero-on-every-mvp-map.md`
- Unlocks: None

## Completion Notes (2026-10-30)

MapValidator.check_patrol_archetypes(): every faction_id a shipped map record uses must resolve to a faction record whose patrol_archetype_id is non-empty and in OverworldConfig.patrol_archetype_ids; errors name the faction and the dangling ID (or the map, for an unknown faction). Run from validate_catalog(). Deviation: no patrol_ record type exists, so the ID resolves against a new OverworldConfig registry (default [patrol_compliance_clerk]) rather than the content catalog.

**Test Evidence**: tests/unit/overworld/data/patrol_archetype_resolution_test.gd, 5/5 passing.

**Files**: src/overworld/map_validator.gd, src/overworld/overworld_config.gd, tests/unit/overworld/data/patrol_archetype_resolution_test.gd
