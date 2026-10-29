# Story 085: The dungeon's pressure floor — at least half the symbols' bands cross the shortest critical path

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
**ADR Decision Summary**: `validate_maps.gd` counts, per reachable stage, how many of the dungeon's symbols have a notice band crossing the shortest (unbanded) critical path, and checks the bypass-to-critical length ratio against `bypass_ratio_min`, so avoiding Clerks always takes route-reading rather than a free walk.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: Reuses the ordered search's `AStarGrid2D` configuration (pinned, deterministic) from story 083; no new engine surface.

**Control Manifest Rules (this layer)**:
- Required: "per leg and stage: the ordered bypass search, the pressure floor, the first-patrol ratio, density bands, the walk budget" — source: ADR-0012 §3
- Required: "`tools/ci/validate_maps.gd` … asserts every [D] criterion of the Overworld GDD" — source: ADR-0012 §3

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-31b [D] (R12, pressure floor)** On the dungeon, at every reachable stage, at least ⌈N_sym/2⌉ symbols' bands cross the leg's `L_crit` path (no bands applied, checkpoints handled as in the ordered search), and `L_bypass ≥ bypass_ratio_min · L_crit`.

---

## Implementation Notes

*Derived from ADR-0012 §3 and GDD rule 12 ("Pressure floor (dungeon)", "Pressure floor tie-break"):*

- `L_crit` here is the shortest critical-path route with **no** patrol bands applied, but with checkpoints handled exactly as in the ordered search (open once their fight-free source is reachable earlier on the leg).
- For each active symbol, test whether any cell of its notice band (`symbol_chase_m + cell_m/√2` margin around its active patrol segments) lies on that `L_crit` path. Require at least `⌈N_sym/2⌉` symbols to cross it.
- **Tie-break.** When several shortest paths tie in length, take the band count over **all** of them, and require the floor to hold on **each** tied path, not just one.
- Cross-check `L_bypass(leg, stage) ≥ bypass_ratio_min · L_crit(leg, stage)` using story 083's `L_bypass` output for the same leg and stage.
- This check runs only on the dungeon, at every reachable stage.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The ordered search that produces `L_bypass` itself (story 083).
- The first-encounter map's **ceiling** on its first patrol's bypass ratio, which is the opposite-direction check (story 086).

---

## Files

- `tools/ci/validate_maps.gd`
- `tests/unit/overworld/data/dungeon_pressure_floor_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic (Config/Data validation)
**Required evidence**:
- `tests/unit/overworld/data/dungeon_pressure_floor_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-083-bypass-lane-ordered-search.md`, `production/epics/overworld-exploration-encounters/story-082-patrol-legality-at-every-reachable-stage.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-086-first-patrol-bypass-ratio-and-teaching-speaker.md`
