# Story 075: Town, dungeon, story-encounter and boss placement match the map-structure rules

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-29)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-012`, `TR-overworld-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine; ADR-0005: Sprite & Camera Presentation (the `R_e` visibility edge from the camp's safe-zone edge)
**ADR Decision Summary**: `validate_maps.gd` checks Town, the dungeon's first room, the story encounter and the boss against rule 11's map-structure table and rule 13a's telegraph and return-marker distances, using the `confirm`-started Static exemption from the symbol-legal placement rule.
**ADR Version**: ADR-0012 2026-10-23; ADR-0005 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: The `R_e` visibility-edge check against the camp's safe-zone edge depends on the shipped camera's resolved `chase_visibility` footprint (I14 — "needs the shipped camera"). Risk follows ADR-0005's row (HIGH).

**Control Manifest Rules (this layer)**:
- Required: `tools/ci/validate_maps.gd` asserts story encounter and boss placement — the `confirm`-started Static exemption, return-marker distance, telegraph from the camp's safe-zone edge — source: ADR-0012 §3
- Forbidden: Never use a physics body, area, cast or collision shape in the Overworld, 2D or 3D — source: ADR-0012 §2, §3
- Guardrail: Overworld load: one single-pass bake plus one component-labelling pass, inside the fade — source: ADR-0012 Performance (Load Time)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-30b [D] (R11, R13, R13a)** Town has 0 symbols and a CampSpot flagged as the region default. The dungeon's first room holds a CampSpot and the story encounter. The story encounter stands on a walkable cell in front of its checkpoint (it is exempt from the symbol-legal rule, rule 13a); its walk-grid distance from the CampSpot's safe-zone edge is at most `story_sight_m`; the visibility edge `R_e` in its direction from that edge is at least its distance; and its return marker lies between `return_safe_radius_m + body_radius` and `interact_reach_m · 3` from it, on the camp side. The boss lies outside every `SAFE` cell, at least `safe_radius_m + 2·body_radius + cell_m` from every safe-zone source in the boss chamber.

---

## Implementation Notes

*Derived from GDD rule 11 ("Map structure") and rule 13a ("The story encounter"):*

- Town has no symbols and holds the region default camp: a CampSpot flagged `is_region_default`, at an ordinary café, never a secret base (Pillar 2, guardrail 6).
- The dungeon's first room holds the pre-dungeon CampSpot and, beyond it, the story encounter (rule 11's map table).
- The story encounter is `Static` with `start_on = confirm`, standing on the walkable cell **in front of** its closed checkpoint; a `confirm`-started Static symbol never makes contact, so it is **exempt** from the symbol-legal placement rule (its cell may be tagged `SAFE`).
- Telegraph (rule 13a): its walk-grid distance from the pre-dungeon CampSpot's safe-zone edge is at most `story_sight_m`, and the chase_visibility edge `R_e` in its direction from that edge is at least that distance — it is on screen from the camp.
- Its return marker lies between `return_safe_radius_m + body_radius` and `interact_reach_m · 3` from it, on the camp side.
- The boss (rule 13) sits outside every `SAFE` cell, at least `safe_radius_m + 2·body_radius + cell_m` from every safe-zone source in the boss chamber, so contact is always possible and never starts on arrival.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-076-permit-counter-telegraph-screenshot: the visual proof of the telegraph this story checks numerically (AC-30i)
- story-072-checkpoint-encounter-outcome: the generic encounter-outcome mechanism (AC-28c)

---

## Files

- `tools/ci/validate_maps.gd`
- `data/maps/map_town.tres`, `data/maps/map_dungeon.tres`, `data/maps/map_boss_chamber.tres`
- `tests/unit/overworld/data/town_dungeon_story_encounter_and_boss_placement_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic (Data validation)
**Required evidence**:
- `tests/unit/overworld/data/town_dungeon_story_encounter_and_boss_placement_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [x] Created and passing; evidence `production/qa/evidence/story-075-camps-checkpoints/`

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-038-contact-starts-encounter-once.md` (AC-13, Static `start_on`), `production/epics/sprite-camera-presentation/story-023-follow-camera-matches-the-formula.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-076-permit-counter-telegraph-screenshot.md`
