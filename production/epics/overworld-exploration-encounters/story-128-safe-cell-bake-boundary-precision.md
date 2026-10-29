# Story 128: SAFE cell tagging is precise at the 0.01 m boundary

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-29)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: — (not yet implemented)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: ADR-0012's `WalkGrid.bake()` rasterises `SAFE` cells conservatively from EntryPoints, MapExits, CampSpots and return markers; this story proves the boundary is exact, not just "roughly conservative."
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Pure geometry over the baked grid; no engine surface beyond the already-probed `TileMapLayer` read at bake.

**Control Manifest Rules (this layer)**:
- Required: "Bake the `WalkGrid` once at map load from the map scene's hidden, collision-disabled `WalkLayer`..., tag `SAFE` conservatively, then free the layer" (control manifest, ADR-0012 §2).
- Guardrail: none.

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-56 [L] (rule 0, SAFE bake)** GIVEN a cell whose nearest point lies 0.01 m inside `safe_radius_m` of an EntryPoint while its centre lies outside, THEN it is tagged `SAFE`; a cell 0.01 m outside is not. The same holds for a MapExit rectangle (nearest point to the rectangle) and a CampSpot at `safe_radius_m`, and for return markers at `return_safe_radius_m`.

---

## Implementation Notes

*Derived from GDD rule 0 ("Safe zone") and ADR-0012 §2's bake order:*

- Rule 0's definition: "Every cell whose **nearest point** lies within `safe_radius_m` of an EntryPoint, a MapExit trigger rectangle or a CampSpot, or within the smaller `return_safe_radius_m` of a checkpoint or story-encounter **return marker**... Safe cells are tagged `SAFE` when the walk grid is baked. Rasterising is conservative, so a cell any part of which is in range counts."
- The test is specifically about the boundary: use the cell's **nearest point** to the source (EntryPoint, MapExit rectangle, CampSpot or return marker), not its centre, and assert at ±0.01 m either side of the radius:
  - a cell whose nearest point is 0.01 m **inside** `safe_radius_m` (even if its centre is outside) is tagged `SAFE`;
  - a cell whose nearest point is 0.01 m **outside** is not tagged `SAFE`.
- Repeat the same boundary test for all four source types: EntryPoint (point, `safe_radius_m`), MapExit (rectangle — nearest point to the rectangle, `safe_radius_m`), CampSpot (point, `safe_radius_m`), and return markers (point, the smaller `return_safe_radius_m`).
- This is a fixture-grid [L] test (ADR-0012 Guidelines: "Test fixtures that build a `TileSet` in code must add the source to the `TileSet` before setting custom data" — a probed Godot gotcha to respect in the fixture).
- Per the Timing/Test rule, assert at exact ±0.01 m offsets from the radius, not from literals recomputed ad hoc — read `safe_radius_m` and `return_safe_radius_m` from `OverworldConfig`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Patrol legality relative to `SAFE` cells (AC-30h, outside this writer's range) — this story only checks the bake's boundary precision, not how symbols treat `SAFE` cells afterward.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/overworld/walk_grid.gd` (`SAFE` rasterisation boundary)
- `tests/unit/overworld/walk_grid_safe_bake_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/overworld/walk_grid_safe_bake_test.gd` — must exist and pass.

**Status**: [x] Created and passing; evidence `production/qa/evidence/story-075-camps-checkpoints/`

---

## Dependencies

- Depends on: `story-017-zone-rate-zero-on-every-mvp-map.md` (AC-8, `WalkGrid` data validation foundation)
- Unlocks: None
