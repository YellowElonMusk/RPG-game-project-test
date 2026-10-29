# Story 086: The first-encounter map's teaching bypass is visibly easy, and its speaker stands before the first notice radius

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
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

- [ ] **AC-31c [D] (R12, R16)** On the first-encounter map, the first patrol's section of the leg (rule 12: from the last cell before its band to the first cell after it, on `L_crit`) has `L_bypass / L_crit ≤ first_bypass_ratio_max`. The `optional_teach` speaker stands within `interact_reach_m · 2` of a critical-path cell before the first notice radius.

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
- `tests/unit/overworld/data/first_patrol_teaching_bypass_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic (Config/Data validation)
**Required evidence**:
- `tests/unit/overworld/data/first_patrol_teaching_bypass_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-083-bypass-lane-ordered-search.md`, `production/epics/overworld-exploration-encounters/story-085-dungeon-pressure-floor.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-087-patrol-visibility-before-the-notice-radius.md`
