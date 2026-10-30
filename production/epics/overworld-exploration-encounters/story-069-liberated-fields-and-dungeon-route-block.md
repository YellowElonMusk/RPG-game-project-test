# Story 069: Liberated profile/kit fields resolve, and liberation blocks the dungeon route

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-017`, `TR-overworld-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine; ADR-0005: Sprite & Camera Presentation (`liberated_profile_id`/`liberated_kit_id` meaning)
**ADR Decision Summary**: Only the maps the last act can reach — the overworld segment and the Town — need both liberated fields; `validate_maps.gd` checks they resolve and that no walk-grid route reaches the dungeon or boss chamber once `paris_liberated` is set and the chapter step is in the last act.
**ADR Version**: ADR-0012 2026-10-23; ADR-0005 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: The route-block search reuses the bake-order rule for `AStarGrid2D` (`update()` once, then `set_blocked` only; a dirty grid returns `[]` silently, probed 4.7.2). Risk follows ADR-0005's row for the profile/kit fields (HIGH).

**Control Manifest Rules (this layer)**:
- Required: `tools/ci/validate_maps.gd` asserts every reference resolves, including `map_`/`enc_`/stage fields — source: ADR-0012 §3
- Forbidden: Never call `AStarGrid2D.update()` after the bake, or change `region`/`cell_size`/`offset` — source: ADR-0012 §2
- Guardrail: Overworld load: one single-pass bake plus one component-labelling pass, inside the fade — source: ADR-0012 Performance (Load Time)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-27e [D] (R17)** The overworld segment and the Town have both `liberated_profile_id` and `liberated_kit_id`, and each resolves. With `paris_liberated` set and the step in the last act (A or B), no walk-grid route from the segment reaches the dungeon or the boss chamber.

---

## Implementation Notes

*Derived from GDD rule 17 ("Only the maps the last act can reach need both fields"):*

- `validate_maps.gd` checks the overworld segment and Town `map_` records both name a `liberated_profile_id` and a `liberated_kit_id`, and that each resolves against the lighting-profile and set-kit catalogs.
- The dungeon and the boss chamber are closed behind the squad once the last act begins (rule 13), so they need **neither** field — the check does not require them there.
- With `paris_liberated` set and the ChapterFlow step in the last act (A or B), a walk-grid search from the segment finds no path to the dungeon or the boss chamber — this is the data-level proof that story-068's walk-home tape blocker (`set_blocked`) actually holds in the shipped map, not just in the integration fixture.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-068-walk-home-after-boss-victory: the runtime sequencing that sets `region_liberation_flag` and the tape blocker (AC-27d)

---

## Files

- `tools/ci/validate_maps.gd`
- `data/maps/map_overworld_segment.tres`, `data/maps/map_town.tres`
- `tests/unit/overworld/last_act_liberated_fields_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic (Data validation)
**Required evidence**:
- `tests/unit/overworld/last_act_liberated_fields_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-066-region-liberation-presentation-override-on-load.md`, `story-068-walk-home-after-boss-victory.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-070-checkpoint-opens-on-met-requirement.md`

## Completion Notes (2026-10-30)

- `MapValidator.validate_last_act()` runs in `validate_maps` (CI). Test: `tests/unit/overworld/last_act_liberated_fields_test.gd`.
- The last act is data: `ChapterSteps.last_act_from` (`step_walk_home_a`). Its maps are the segment and Town.
- Each last-act map must have a liberated profile (resolving under `data/presentation/profiles/`) and a kit (resolving through `SetKit.resolve`).
- With the region flag set and flag-closed exits taped, a walk-grid flood from every EntryPoint must reach no exit to a map outside the last act.
- The tape is `MapExit.closed_when_flag` / `closed_rect`. The segment's dungeon exit is taped over its trigger cells while `paris_liberated` is set. `OverworldMode` blocks the cells, shows the tape box and does not register the exit (story 068 uses this).
- Mutations checked: an empty or unresolved field, and removing the tape, each fail a test here.
