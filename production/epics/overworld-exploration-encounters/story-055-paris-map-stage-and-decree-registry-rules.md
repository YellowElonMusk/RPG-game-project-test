# Story 055: Paris map records set correct base stages and decree-gag registry rules

> **Epic**: Overworld Exploration & Encounters
> **Status**: In Progress (2026-10-30): base stages and the segment stage table done; occupation-stage records (density, caps) and decree-gag registry rules not built
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-009`, `TR-overworld-016`, `TR-overworld-019`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: `MapData` carries `base_stage` and `stage_table`; `occupation_stage` never decreases, and `validate_maps.gd` asserts every stage-raising flag is scheduled strictly ahead of any map load it affects and names a decree gag at every usable EntryPoint of the map it raises.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: `validate_maps.gd` runs `ContentBootstrap.run()` then loads and bakes every map headlessly (ADR-0012 §3). The walk-grid reachability search it runs for this AC follows the same bake-order rule as runtime pathing: `AStarGrid2D.update()` once, then only `set_point_solid`/`set_blocked` — a dirty grid returns `[]` silently (probed, 4.7.2).

**Control Manifest Rules (this layer)**:
- Required: `tools/ci/validate_maps.gd` runs after `validate-content.gd`, runs `ContentBootstrap.run()` first, loads and bakes every map, and asserts every [D] criterion of the Overworld GDD — source: ADR-0012 §3
- Forbidden: Never store a scene path on `MapData` — breaks Content Data Rule 3 — source: ADR-0012 (Alternative 5)
- Guardrail: Overworld load: one single-pass bake plus one component-labelling pass, inside the fade — source: ADR-0012 Performance (Load Time)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-23b [D] (R8, R18)** Paris `map_` records have `base_stage` Town 1, overworld segment 1 and dungeon 3. Civilian density is non-increasing across stages 1–3, and caps are non-decreasing (I13). Maps with no `base_stage` report no stage. For every stage-raising flag in the registry:
  - its trigger is a ChapterFlow step change, and **never** a player Victory, a map entry or another squad action;
  - it is set on a step **before** every step in which any map it raises can be loaded, and a walk-grid search from the chapter's start over every map reachable before that step finds no route into a raised map (for `permits_mandatory`, set on the opening step, the check is trivially met);
  - it names a decree gag at **every** EntryPoint of each raised map that any MapExit targets, each resolving to a `decree_gag` marker.

  The overworld segment's reachable stages, derived from the step list, are exactly {2}.

  Every flag that any map, checkpoint, marker or Dialogue reads appears in the registry.

---

## Implementation Notes

*Derived from ADR-0012 Implementation Guidelines and GDD rule 8:*

This criterion has four independent parts, each failing with its own named error:
- base-stage values per map (`map_town` 1, `map_overworld_segment` 1, `map_dungeon` 3), plus the "no `base_stage` → no stage reported" case for camp interiors and the boss chamber;
- civilian density non-increasing and caps non-decreasing across stages 1–3 (I13), read from the `occupation_stage` faction × stage records;
- for every stage-raising entry in the rule-18 interim flag registry: its trigger is a ChapterFlow step change, never a player Victory, a map entry or another squad action against the faction (Pillar 2); it is scheduled strictly before any step that can load the map it raises; and a walk-grid search from the chapter's start proves no earlier route reaches that map (`permits_mandatory`, scheduled on the opening step, trivially passes);
- every usable EntryPoint of a raised map — every EntryPoint any MapExit targets — carries a `decree_gag` marker for that flag.

Also compute the overworld segment's reachable-stage set from the ChapterFlow step list per the `occupation_stage` formula's "reachable stages" definition, and assert it is exactly `{2}` — no stage-1 content is authored for it.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-056-decree-gag-stage-eligibility: runtime decree-gag eligibility, cap exemption and route-blocking exemption (AC-23c)
- story-058-marker-activation-slots-by-stage-and-cap: the `marker_activation` formula itself (AC-24)

---

## Files

- `tools/ci/validate_maps.gd`
- `data/maps/map_town.tres`, `data/maps/map_overworld_segment.tres`, `data/maps/map_dungeon.tres`
- `data/occupation_stages/ostage_bureaucratia_*.tres`
- `tests/unit/overworld/data/paris_map_stage_and_registry_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic (Data validation)
**Required evidence**:
- `tests/unit/overworld/data/paris_map_stage_and_registry_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-053-occupation-stage-formula.md` (the `occupation_stage` formula), `production/epics/overworld-exploration-encounters/story-054-stage-change-waits-for-next-load.md` (stage applies only on load)
- Unlocks: `production/epics/overworld-exploration-encounters/story-056-decree-gag-stage-eligibility.md`, `story-057-new-game-permits-mandatory-timing.md`
