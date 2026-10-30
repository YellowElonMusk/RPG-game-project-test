# Story 064: Clutter markers with a symbol_id are visible from the patrol they liberate

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-010`, `TR-overworld-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine; ADR-0005: Sprite & Camera Presentation (`R_vis` derives from the camera's resolved footprint)
**ADR Decision Summary**: `validate_maps.gd` asserts every clutter marker that names a `symbol_id` lies within `R_vis` of a vertex of that symbol's patrol, and that the symbol is active at every reachable stage where the marker is active — otherwise the win could never show on screen before the boss falls.
**ADR Version**: ADR-0012 2026-10-23; ADR-0005 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `R_vis` is computed from the shipped camera's footprint per the `chase_visibility` formula (I14); this check validates against that resolved value, not a placeholder. Risk follows ADR-0005's row (HIGH).

**Control Manifest Rules (this layer)**:
- Required: `tools/ci/validate_maps.gd` ... asserts every [D] criterion of the Overworld GDD, including payoff tells within `R_vis` and clue/teaching-beat ordering — source: ADR-0012 §3
- Forbidden: Never store a scene path on `MapData` — source: ADR-0012 (Alternative 5)
- Guardrail: Overworld load: one single-pass bake plus one component-labelling pass, inside the fade — source: ADR-0012 Performance (Load Time)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-26c [D] (R9)** Every clutter marker that names a `symbol_id` lies within `R_vis` of at least one vertex of that symbol's patrol, and that symbol is active at every reachable stage where the marker is active.

---

## Implementation Notes

*Derived from GDD rule 9 ("Placement"):*

- A marker that names a `symbol_id` must lie within `R_vis` (Formulas, `chase_visibility`) of at least one vertex of that symbol's patrol path, so winning the fight shows its result.
- Contact can happen anywhere along a chase, so a marker may still be off-screen at the reveal — that case is handled by the off-screen sting plus the payoff card (rule 7a, AC-21d), not by this placement rule.
- The symbol must also be active at every stage where its marker is active, or the marker could not be liberated before the boss falls — both are checked in CI, per-map, per-symbol.
- `R_vis` is `min(R_near, R_far, R_side)` from the `chase_visibility` formula: the smallest guaranteed on-screen distance from the leader, in any direction, at the shipped camera.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-065-stage-visual-capture-saturation-and-contrast: capture-measured stage visuals (AC-27)

---

## Files

- `tools/ci/validate_maps.gd`
- `data/maps/map_town.tres`, `data/maps/map_overworld_segment.tres`, `data/maps/map_dungeon.tres`
- `tests/unit/overworld/clutter_placement_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic (Data validation)
**Required evidence**:
- `tests/unit/overworld/clutter_placement_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-020-patrol-loop-and-pingpong-traversal.md` (patrol path authoring), `story-058-marker-activation-slots-by-stage-and-cap.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-065-stage-visual-capture-saturation-and-contrast.md`

## Completion Notes (2026-10-30)

- `MapValidator.check_clutter_placement()` runs in `validate_maps`: each gag with a `liberate_symbol` must lie within `R_vis` of one of that symbol's patrol vertices.
- `R_vis` is the new `ChaseVisibility.r_vis()`: the minimum edge over every aspect at the shipped camera (5.23 m at 12 m; 4.99 at 11.5 m, matching the GDD).
- "Active at every stage the marker is": symbols carry no stage gate, so a placed symbol is active at every stage until region liberation, which frees the marker too. A missing symbol is story 078's error.
- The shipped queue is 2.83 m from the east Clerk's first vertex. The test moves it to just inside, then just outside, `R_vis`.
