# Story 103: Every map's active symbol count lies within its density band at every reachable stage

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
**ADR Decision Summary**: `validate_maps.gd` computes `N_min`/`N_max` from each map's walkable-cell count and map-type density band, and asserts every reachable stage's active symbol count falls inside it, with the Town pinned to 0 and the boss chamber to the boss alone.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: Pure arithmetic over the baked `WalkGrid`'s walkable-cell count (`W`); no new engine surface beyond the bake itself.

**Control Manifest Rules (this layer)**:
- Required: "per leg and stage: … density bands …" — source: ADR-0012 §3
- Required: "`tools/ci/validate_maps.gd` … asserts every [D] criterion of the Overworld GDD" — source: ADR-0012 §3

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-41 [D] (`symbol_density`)** At every reachable stage, each map's `N_sym` lies within `[N_min, N_max]`, with `N_min` at least 1 on every map other than Town and the boss chamber. Town has 0, and the boss chamber holds the boss only. Coverage is reported, not gated.

---

## Implementation Notes

*Derived from ADR-0012 §3 and GDD Formulas ("symbol_density"):*

- `N_min = round_half_up(W / D_max(type))`, `N_max = round_half_up(W / D_min(type))`, where `D_min`/`D_max` come from the map's type band (overworld 150/250, dungeon 80/120). `N_min` is raised to 1 whenever rounding would give 0, on every map except Town.
- Require `N_min ≤ N_sym(stage) ≤ N_max` for every reachable stage. Town must hold exactly 0 non-boss, non-story symbols; the boss chamber must hold the boss and no other symbol.
- Compute `coverage = Σ_j (π·r_c² + 2·r_c·L_patrol,j) / (W · cell_m²)` with `r_c = symbol_chase_m + body_radius`, and **report** it per map — it is never a gate. The bypass and pressure checks (stories 083, 085) are the real gates.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The bypass lane and pressure-floor checks that actually gate playability (stories 083, 085).

---

## Files

- `tools/ci/validate_maps.gd`
- `tests/unit/overworld/symbol_density_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic (Config/Data validation)
**Required evidence**:
- `tests/unit/overworld/symbol_density_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-082-patrol-legality-at-every-reachable-stage.md`
- Unlocks: None further in this epic

## Blocked Notes (2026-10-30)

- Built the check (a `MapData.density_type` of "overworld" or "dungeon", W counted from the baked grid, `N_min = max(1, round(W/D_max))`, `N_max = round(W/D_min)`, coverage reported) and ran it on the shipped maps.
- Segment: W 291, 2 symbols in [1, 2], passes.
- **Dungeon: W 670 needs 6–8 patrolling symbols; it has 2 (the first-room and hall Clerks; the Counter is the story encounter and is not counted).**
- Fixing it is a level-design pass on `tools/maps/build_paris_dungeon_maps.gd`: four to six more Clerks, re-proved against the bypass/pressure validators (stories 083/085), recaptured for story 087's walk-ins, with the tests that count dungeon symbols updated. The alternative is a design call that the dungeon band (80/120 cells per symbol) is too dense for this layout. The code was reverted, not committed, so CI stays green; reapply it with the content.

## Completion Notes (2026-10-30): the dungeon level-design pass

- `MapValidator.check_density()` runs in `validate_maps` and prints each banded map's coverage, which is reported, not gated. `MapData.density_type` is new: "overworld" on the segment, "dungeon" on the dungeon. Town and the boss chamber have no band.
- The dungeon now holds 6 patrolling Clerks, up from 2 (W 670, band [6, 8]). The segment holds 2 (W 291, band [1, 2]).
- **Placement:** four new Clerks in `build_paris_dungeon_maps.gd`:
  - hall south-west (11.5, 17.5)–(11.5, 19.5)
  - hall south far-west (7.5, 16.5)–(9.5, 16.5)
  - hall north (13.5, 8.5)–(15.5, 8.5)
  - hall north-west (5.5, 1.5)–(7.5, 1.5)
- **How they were found:**
  - A search kept only placements that leave the validators clean: bypass lane via the west gap, a pressure floor of now 3 of 6 bands, and safe zones.
  - Story 087's walk-ins then rejected two earlier picks. One sat in the 4.3 m wall shadow the north-facing camera can't see behind. One sat south of the east gap, where a leader walking south through the gap has it at the frame's near edge, out of shot.
  - South-half Clerks therefore stand under the long hall wall, which no approach crosses from the north.
- Story 087 recaptured: 46 approaches, 0 failures. I opened the new Clerks' captures myself. The north-west Clerk sits close to the frame's top edge on its 270° approach: visible, but flag it for art review.
- `dungeon_pressure_floor_test.gd` was updated for six Clerks ("fewer than 3 of 6").
