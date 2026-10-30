# Story 074: Every MapExit, critical-path leg and ChapterFlow step reference resolves

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-012`, `TR-overworld-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: `validate_maps.gd` asserts every `MapExit` names a reciprocal exit, every critical-path leg names an existing end, and every ChapterFlow step names an existing `{map_id, leg_id}` pair — the reference-integrity floor the bypass and placement checks build on.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Pure reference-resolution pass over loaded records; no post-cutoff API touched.

**Control Manifest Rules (this layer)**:
- Required: Critical-path legs end at an exit, a symbol or a camp, and each ChapterFlow step names `{map_id, leg_id}` — source: ADR-0012 §3 (`MapData.critical_path`)
- Forbidden: Never store a scene path on `MapData` — source: ADR-0012 (Alternative 5)
- Guardrail: Overworld load: one single-pass bake plus one component-labelling pass, inside the fade — source: ADR-0012 Performance (Load Time)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-30a [D] (R11, rule 0)** For every shipped map, every MapExit target exists with a reciprocal exit. Every `critical_path` leg names an existing EntryPoint and an existing MapExit, story-encounter or boss `symbol_id`, or CampSpot. Every ChapterFlow step names an existing `{map_id, leg_id}`.

---

## Implementation Notes

*Derived from GDD rule 0 ("Critical path") and rule 11 ("Map structure"):*

- Rule 0: a leg is `{id, from: EntryPoint id, to: MapExit id | symbol_id | CampSpot id}`; the `to` exits are the map's **required exits**.
- Every `MapExit` names a target `map_` ID and a target entry `marker_id` (ADR-0012 §3 marker table) — `validate_maps.gd` checks the target exists and that it points back (a reciprocal exit on the far map).
- Every ChapterFlow step names the `{map_id, leg_id}` it sends the player along (rule 0), so "the current leg" is always known — this check is the floor every downstream leg-aware check (bypass search, pressure floor, walk budget) depends on.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-075-town-dungeon-story-encounter-and-boss-placement: placement rules for specific maps/symbols (AC-30b)
- story-080-entry-point-exit-clearance: EntryPoint-to-exit geometry, not reference existence (AC-30f)

---

## Files

- `tools/ci/validate_maps.gd`
- `data/maps/*`
- `tests/unit/overworld/data/map_exit_and_leg_reference_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic (Data validation)
**Required evidence**:
- `tests/unit/overworld/data/map_exit_and_leg_reference_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: None
- Unlocks: `production/epics/overworld-exploration-encounters/story-075-town-dungeon-story-encounter-and-boss-placement.md`, `story-080-entry-point-exit-clearance.md`

## Progress Notes (2026-10-30)

- Done: reciprocal exits (`MapValidator.validate_maps`) and leg references (`MapValidator.validate_legs`). `MapData.critical_path` is now `Array[CriticalPathLeg]` (`{id, from_entry, to}`); the four Paris records carry seven legs.
- **Blocked:** "every ChapterFlow step names an existing `{map_id, leg_id}`". No step list exists (`chapter_flow.gd` TODO(dialogue-quests)); `tools/ci/validate_maps.gd` prints NOT ASSESSED for it on every run.
- **Unblocked 2026-10-30:** `ChapterStep` / `ChapterSteps` (ADR-0012 §8 interim step list) and `data/chapters/chapter_paris_steps.tres` (seven steps, leave Town to the walk home; the first sets `permits_mandatory`). `MapValidator.validate_steps()` checks every step names an existing map and leg; `validate_maps` no longer prints NOT ASSESSED.
