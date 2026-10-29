# Story 103: Every map's active symbol count lies within its density band at every reachable stage

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
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

- [ ] **AC-41 [D] (`symbol_density`)** At every reachable stage, each map's `N_sym` lies within `[N_min, N_max]`, with `N_min` at least 1 on every map other than Town and the boss chamber. Town has 0, and the boss chamber holds the boss only. Coverage is reported, not gated.

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
- `tests/unit/overworld/data/symbol_density_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic (Config/Data validation)
**Required evidence**:
- `tests/unit/overworld/data/symbol_density_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-082-patrol-legality-at-every-reachable-stage.md`
- Unlocks: None further in this epic
