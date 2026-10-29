# Story 082: Every symbol's patrol sweep and resume point are symbol-legal at every reachable stage

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
**ADR Decision Summary**: `tools/ci/validate_maps.gd` loads and bakes every shipped map headlessly and asserts every `[D]` criterion of the GDD, including that patrol geometry never lands on a cell a symbol cannot legally occupy.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: The bake behind `WalkGrid.is_symbol_legal()` relies on the hidden `WalkLayer` `TileMapLayer` (`collision_enabled = false`, probed to create 0 physics objects) and on `GridMap`/`TileMapLayer` collision defaults being overridden (both default to collision **on**, probed on 4.7.2 — checked by `AC-30e`, story 079). This story only consumes the resulting `WalkGrid`; it reads no physics state.

**Control Manifest Rules (this layer)**:
- Required: "`tools/ci/validate_maps.gd` runs in CI after `validate-content.gd`. It runs `ContentBootstrap.run()` first, loads every map scene headlessly, bakes it, and asserts every [D] criterion of the Overworld GDD" — source: ADR-0012 §3
- Required: "placement: EntryPoints clear of MapExit rectangles; patrol segments clear of safe zones and symbol-legal at every reachable stage" — source: ADR-0012 §3
- Forbidden: "Never use a physics body, area, cast or collision shape in the Overworld, 2D or 3D … `validate_maps.gd` enforces it" — source: ADR-0012 §2, §3

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-30h [D] (R5, patrol legality)** For every symbol, at every reachable stage where it is active, every cell its patrol segments sweep (± `body_radius`) and its patrol origin are symbol-legal.

---

## Implementation Notes

*Derived from ADR-0012 §3 and GDD rule 5 ("Patrol legality", "No route"):*

- For each `EncounterSymbol` marker, walk its patrol polyline (the closing segment of a `loop` path included) and rasterise every cell within `body_radius` of any point on any segment, plus the patrol's origin cell.
- A symbol is "active" at a stage when `marker_activation`'s `visible(m)` holds for its marker at that stage (rule 8); the stages to check are the map's **reachable stages** (the CI-derived set from `occupation_stage`, rule 8 / Formulas), never a blind 1–3 sweep.
- Check every such cell against `WalkGrid.is_symbol_legal(cell)` (walkable and not `SAFE`) under that stage's baked blocker state. A failure names the `map_id`, `symbol_id`, the stage and the offending cell.
- This is the data-side half of rule 5's "No route" edge case: a resume point that cannot be reached is the runtime symptom of exactly this data error, so this check is what keeps it from shipping.
- Patrol-vs-safe-zone clearance (segments outside `safe_radius_m` of an EntryPoint/MapExit/CampSpot) is a separate CI check (rule 12, Edge Cases) — do not duplicate it here; this story only asserts legality, never the safe-zone margin.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Patrol-vs-safe-zone clearance and the `SAFE` bake itself (AC-56, story 128).
- The ordered bypass search that treats patrol bands as blocked (story 083).

---

## Files

- `tools/ci/validate_maps.gd`
- `tests/unit/overworld/data/patrol_legality_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic (Config/Data validation)
**Required evidence**:
- `tests/unit/overworld/data/patrol_legality_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-073-checkpoint-requirement-and-critical-path-reachability.md` (the `validate_maps.gd` CI harness and its first `[D]` criterion), `story-128-safe-cell-bake-boundary-precision.md` (the `SAFE` bake that `is_symbol_legal` reads)
- Unlocks: `production/epics/overworld-exploration-encounters/story-083-bypass-lane-ordered-search.md`
