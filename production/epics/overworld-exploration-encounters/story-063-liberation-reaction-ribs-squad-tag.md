# Story 063: Every map's liberation reaction set includes a ribs_squad entry

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-010`, `TR-overworld-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: `validate_maps.gd` asserts every map's liberation reaction content set carries at least one entry tagged `ribs_squad`, so Pillar 2's "the squad is fair game too" is enforced in data, not left to authoring discipline.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Pure data-pass over loaded records; no post-cutoff API touched.

**Control Manifest Rules (this layer)**:
- Required: `tools/ci/validate_maps.gd` runs after `validate-content.gd`, asserts every [D] criterion of the Overworld GDD — source: ADR-0012 §3
- Forbidden: Never store a scene path on `MapData` — source: ADR-0012 (Alternative 5)
- Guardrail: Overworld load: one single-pass bake plus one component-labelling pass, inside the fade — source: ADR-0012 Performance (Load Time)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-26e [D] (R9)** Each map's liberation reaction set has at least one entry tagged `ribs_squad` (AC-51 confirms the tag is honest).

---

## Implementation Notes

*Derived from GDD rule 9 and rule 16 (Pillar 2):*

- Rule 9: "at least one reaction per map ribs the squad, for example a café owner sweeping up the torn posters and glaring at the leader."
- `validate_maps.gd` walks each map's liberation reaction content set and fails, naming the map, if no entry carries the `ribs_squad` tag.
- This story checks only the tag's **presence**. AC-51 (outside this writer's range) separately confirms the tagged line actually reads as ribbing the squad — this story never substitutes for that narrative check.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-062-liberation-grumble-share-and-deflated-clerk: the grumble-share floor itself (AC-26d)
- AC-51 (outside this range): the content-honesty check on the tag

---

## Files

- `tools/ci/validate_maps.gd`
- `data/maps/map_town.tres`, `data/maps/map_overworld_segment.tres`, `data/maps/map_dungeon.tres`
- `tests/unit/overworld/liberation_reaction_ribs_squad_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic (Data validation)
**Required evidence**:
- `tests/unit/overworld/liberation_reaction_ribs_squad_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-062-liberation-grumble-share-and-deflated-clerk.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-064-clutter-marker-visibility-and-symbol-activity.md`

## Completion Notes (2026-10-30)

- `MapValidator.check_reaction_sets()` runs in `validate_maps`. A map's liberation reaction set is its `liberated_role` markers (story 066).
- Each last-act map (segment, Town; the same scope as story 069) needs at least one entry tagged `ribs_squad`, a new field on `NpcSpawn` / `GagInteractable`. The dungeon and boss chamber are closed behind the squad, so nobody sees them liberated.
- Content:
  - Town: the café owner sweeping torn posters ("Who is liberating my broom?").
  - Segment: a street sweeper.
  - Both lines need rule-18 / AC-51 narrative sign-off.
- AC-51 narrative sign-off done 2026-10-30: both lines pass and both `ribs_squad` tags are honest (`production/qa/evidence/signoff-overworld.md`).
