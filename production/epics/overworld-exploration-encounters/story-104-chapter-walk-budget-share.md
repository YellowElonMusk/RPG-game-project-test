# Story 104: The chapter's planned walk share stays under `walk_share_max`

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: `validate_maps.gd` sums each critical-path leg's maximum bypass-lane length over its reachable stages, weighted by how many ChapterFlow steps name it, and asserts the resulting walk share stays under `walk_share_max`.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: Pure arithmetic over story 083's `L_bypass` output and the ChapterFlow step-list data; no new engine surface.

**Control Manifest Rules (this layer)**:
- Required: "per leg and stage: … the walk budget (with `passes` counted from the ChapterFlow step list)" — source: ADR-0012 §3
- Required: "`tools/ci/validate_maps.gd` … asserts every [D] criterion of the Overworld GDD" — source: ADR-0012 §3

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-42 [D] (`chapter_walk_budget`)** `walk_share` ≤ `walk_share_max`, where each leg's length is its `L_bypass` maximum over reachable stages and `passes(leg)` is counted from the ChapterFlow step list. A fixture step list that names a leg twice doubles that leg's term.

---

## Implementation Notes

*Derived from ADR-0012 §3 and GDD Formulas ("chapter_walk_budget"):*

- `T_walk = k_tort · Σ_legs max_stage L_bypass(leg, stage) · passes(leg) / walk_speed`; `walk_share = T_walk / T_chapter`. Require `walk_share ≤ walk_share_max`.
- Each leg's length term is `L_bypass(leg, stage)`'s **maximum** over the map's reachable stages (story 083's output) — never `L_crit`, since the budget models the route an avoiding player actually walks.
- `passes(leg)` must be **counted from the ChapterFlow step list data**, never typed by hand in the fixture. Prove this with a fixture step list that names one leg twice and assert its term in `T_walk` doubles accordingly.
- Cross-check against the GDD's own worked example (rev 4 chain, 310 m total, `k_tort` 1.4 at 3.5 m/s → ≈4% of the chapter) as a sanity bound, not as the literal fixture.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `L_bypass` computation itself (story 083) and the dungeon pressure floor (story 085).
- The real playtest share measurement against this planning budget (AC-48, outside this range).

---

## Files

- `tools/ci/validate_maps.gd`
- `tests/unit/overworld/chapter_walk_budget_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic (Config/Data validation)
**Required evidence**:
- `tests/unit/overworld/chapter_walk_budget_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-083-bypass-lane-ordered-search.md`, `production/epics/overworld-exploration-encounters/story-085-dungeon-pressure-floor.md`
- Unlocks: None further in this epic

## Completion Notes (2026-10-30)

- `WalkBudget.compute()` sums each step's leg `L_bypass`, so passes are counted from the step list. It runs in `validate_maps`.
- `L_bypass` comes from the new `BypassSearch.bypass_length()`: the same banded search as rule 12, through the story encounter's split (counter, boom depth, beyond), and `L_crit` on the boss map.
- New knobs: `k_tort` 1.4; `t_chapter_s` 2700 (the low end of 45–60 min, so the share is not flattered); `walk_share_max` 0.15.
- Shipped placeholder chapter: about 25 s of walking, a share of 0.9%. The placeholder maps are far smaller than the GDD example's (310 m), and Town's café leg is 0 m because the segment EntryPoint sits inside the café's safe zone.
- The shipped-data test failed first: the split computed its "beyond" cells after opening the boom, so the dungeon's boss leg measured INF. Fixed to match `check()`.
