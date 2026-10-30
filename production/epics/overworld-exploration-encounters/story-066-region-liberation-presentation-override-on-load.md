# Story 066: Region-liberation presentation override applies on load, before reveal

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-010`, `TR-overworld-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine; ADR-0005: Sprite & Camera Presentation (lighting profile / set-kit resolution)
**ADR Decision Summary**: Once `region_liberation_flag` is set, a Paris map's next load resolves the liberated profile and kit, and deactivates every symbol, before the stage enters the tree — the stage value itself is unchanged.
**ADR Version**: ADR-0012 2026-10-23; ADR-0005 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No new runtime API; the lighting-profile swap reuses the same resolve-before-tree-entry path as every other stage, so no additional engine risk beyond ADR-0005's own row (HIGH).

**Control Manifest Rules (this layer)**:
- Required: `OverworldMode._ready()` builds only per-visit state, in order: `MapData` + stage + liberation → scene → bake → markers → actors → `stage.profile_id` before tree — source: ADR-0012 §4
- Forbidden: Never write `WorldState` from `OverworldMode._ready()` — source: ADR-0012 §4
- Guardrail: Overworld load: one single-pass bake plus one component-labelling pass, inside the fade — source: ADR-0012 Performance (Load Time)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-27b [L] (R13, R17)** GIVEN `region_liberation_flag` set, WHEN each Paris map loads, THEN, before the first revealed frame:
  - every clutter marker is treated as liberated, including those of a higher stage;
  - the stage value is unchanged;
  - the lighting profile is the map's `liberated_profile_id` and the set kit is `liberated_kit_id`;
  - civilian density and the ambience bed equal stage 1's;
  - **every** symbol is inactive, beaten or not, and the mairie-queue civilians, at least one grumbler and one "Bureaucratia had a point" item are active.

---

## Implementation Notes

*Derived from GDD rule 17 ("the presentation override") and rule 9 ("Region liberation is evaluated on every load"):*

- Rule 17: the stage value is **kept** (rule 8), but the presentation layer reverses it: lighting profile → the map's `liberated_profile_id`; set kit → `liberated_kit_id` (every faction set-dressing addition removed, skyline landmark restored); civilian density and ambience bed → stage 1's.
- Rule 9: "region liberation is evaluated on every load, not stored as a list of marker IDs" — while the flag is set, every clutter marker and decree gag on that map is treated as liberated, **including markers a later stage would add**, and every symbol on that map is inactive, beaten or not.
- Rule 13: the liberated kit keeps at least one grumbler NPC and one "Bureaucratia had a point" item (a queue-number machine someone keeps using) — the scene does not celebrate.
- ADR-0012 §7: the lighting profile is resolved before the stage enters the tree, so this override must land in that same resolve step, not as a later correction.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-065-stage-visual-capture-saturation-and-contrast: the non-liberated gradient this overrides (AC-27)
- story-067-liberated-paris-screenshots-golden-hour: the visual capture of this override (AC-27c)
- story-068-walk-home-after-boss-victory: the sequence that sets `region_liberation_flag` (AC-27d)

---

## Files

- `src/overworld/overworld_mode.gd` (`_ready` stage + liberation resolution, step 1 and step 7)
- `src/data/records/map_data.gd`
- `src/data/records/occupation_stage_data.gd`
- `tests/unit/overworld/region_liberation_presentation_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/region_liberation_presentation_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-053-occupation-stage-formula.md` (`occupation_stage`), `story-059-liberated-set-persists-across-respawn-and-stage.md`, `story-065-stage-visual-capture-saturation-and-contrast.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-067-liberated-paris-screenshots-golden-hour.md`, `story-068-walk-home-after-boss-victory.md`

## Completion Notes (2026-10-30)

- Test: `tests/unit/overworld/region_liberation_presentation_test.gd`.
- `OverworldMode._resolve_presentation()` runs at the map-entry commit (before the reveal), right after the stage. It sets `presentation_profile_id`, `set_kit_id`, `civilian_density` and `ambience_bed_id`:
  - From the stage's `occupation_stage` record.
  - Once liberated: the map's liberated profile and kit, with stage 1's density and ambience bed.
  - The profile falls back to `overworld` when unset.
  - The kit is applied to the map (`SetKit.removes_faction_dressing` hides the `faction_dressing` group). The profile is written to a `DioramaStage` when the map has one. The placeholder maps have none, and `PresentationDirector` is not wired into GameRoot yet.
- New data:
  - `SetKit` resource with `kit_paris_occupied` and `kit_paris_liberated`.
  - Lighting profile `overworld_liberated` (golden hour).
  - The stage records now carry profile, kit and ambience IDs.
- Liberated-set content uses `liberated_role` on `NpcSpawn` / `GagInteractable`. Town has two `mairie_queue` civilians, a `grumbler` and the `had_a_point` ticket machine. Their lines need rule-18 narrative sign-off (AC-51).
- Civilian density and ambience beds are resolved values only; no civilian spawner or audio exists yet.
- Mutations checked: stage-N density when liberated, the liberated profile ignored, NPCs not gated, and the kit not applied each fail a test here.
