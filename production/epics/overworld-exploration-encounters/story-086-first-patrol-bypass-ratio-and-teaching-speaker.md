# Story 086: The first-encounter map's teaching bypass is visibly easy, and its speaker stands before the first notice radius

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: `validate_maps.gd` checks that the first-encounter map's first patrol has a bypass ratio at or below `first_bypass_ratio_max` over its own section of the leg, and that the `optional_teach` speaker stands close enough to the critical path, before the first notice radius, to deliver the teaching beat.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: Shares story 083/085's `AStarGrid2D`/band machinery; no new engine surface.

**Control Manifest Rules (this layer)**:
- Required: "per leg and stage: the ordered bypass search, the pressure floor, the first-patrol ratio, density bands, the walk budget" — source: ADR-0012 §3
- Required: "`tools/ci/validate_maps.gd` … asserts every [D] criterion of the Overworld GDD" — source: ADR-0012 §3

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-31c [D] (R12, R16)** On the first-encounter map, the first patrol's section of the leg (rule 12: from the last cell before its band to the first cell after it, on `L_crit`) has `L_bypass / L_crit ≤ first_bypass_ratio_max`. The `optional_teach` speaker stands within `interact_reach_m · 2` of a critical-path cell before the first notice radius.

---

## Implementation Notes

*Derived from ADR-0012 §3 and GDD rules 12 ("First patrol") and 16 ("Clerks are optional: the teaching beat"):*

- Isolate the first-encounter map's first critical-path patrol. Its **section** of the leg is the run of `L_crit` cells from the last cell before its band to the first cell after it.
- Over that section only, require `L_bypass / L_crit ≤ first_bypass_ratio_max` — a **ceiling**, the opposite direction from the dungeon's pressure-floor check (story 085): here the bypass must read as visibly easy, not merely possible.
- Separately, locate the `optional_teach` marker. It must stand within `interact_reach_m · 2` of a cell on the critical path, and that cell must come **before** the first point within any notice radius along the path — mirroring the `faction_clue` ordering check (rule 16) but for the teaching speaker instead of the clue.
- Both checks run only on the map tagged as the faction's first-encounter map (the overworld segment, in MVP Paris).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The dungeon's pressure floor (story 085), which this ratio deliberately inverts.
- The `faction_clue` ordering and clearance check (AC-50, outside this range).
- The [VF] capture proof that the first patrol is actually on screen before the player can be noticed (story 087).

---

## Files

- `tools/ci/validate_maps.gd`
- `tests/unit/overworld/first_encounter_placement_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic (Config/Data validation)
**Required evidence**:
- `tests/unit/overworld/first_encounter_placement_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-083-bypass-lane-ordered-search.md`, `production/epics/overworld-exploration-encounters/story-085-dungeon-pressure-floor.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-087-patrol-visibility-before-the-notice-radius.md`

## Completion Notes (2026-10-30): the segment level-design pass

- `MapValidator.first_encounter_metrics()` and `check_first_encounter()` run in `validate_maps`. Test: `tests/unit/overworld/first_encounter_placement_test.gd`. The first-encounter map is the first chapter step's map holding a patrol (Paris: the segment, leg `segment_to_dungeon` from `from_town`).
- Measurements are arcs along `L_crit`; the path set is every cell on a tied shortest route.
- New knobs: `first_bypass_ratio_max` 1.1 and `first_patrol_clearance_m` 3.
- The tool `tools/level_review/first_encounter_report.gd` prints the numbers for level review.
- **Content change:**
  - The west Clerk's patrol moved from (9.5, 5.5)–(14.5, 5.5) to (14.5, 7.5)–(17.5, 7.5).
  - The `faction_clue` poster moved from (8.5, 12.5) to (10.5, 6.5), beside the row 7–9 wall on the path.
  - Old layout: first notice 3.4 m, first patrol 6.2 m, clue off the path, section ratio 1.43.
  - New layout: first notice 8.8 m, first patrol 10.8 m (≥ 10.5), clue at 5.8 m, the Café regular's teaching bark at 1.0 m, section ratio 1.0.
- The candidate (15.5, 7.5)–(15.5, 10.5) passed every rule but failed three of story 087's south walk-ins (0% visible behind the row-12 wall block), so it was rejected.
- Story 087's walk-ins were recaptured: 24 approaches, 0 failures. I opened the west Clerk's 225° and 270° captures myself; the Clerk is unoccluded in both.
- `validate_maps` is clean, and the suite passes 1149/1149.
