# Story 110: Every leg's junction nodes cover its real branch points

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time. TR-016 names "beacon junction coverage" explicitly among `validate_maps.gd`'s CI checks.)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0001: Content Data Storage (amended by ADR-0012)
**ADR Decision Summary**: ADR-0012 puts every per-map data criterion, including junction coverage, through `tools/ci/validate_maps.gd`; ADR-0001 fixes that map records carry no file paths and are validated against the generic reference pass.
**ADR Version**: ADR-0012 2026-10-23; ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Pure data validation over `MapData` and the baked `WalkGrid`; no new engine surface. Inherits ADR-0001's HIGH knowledge risk rating rather than any engine call this story makes itself.

**Control Manifest Rules (this layer)**:
- Required: "`tools/ci/validate_maps.gd` runs after `validate-content.gd`, runs `ContentBootstrap.run()` first, loads and bakes every map, and asserts every [D] criterion of the Overworld GDD" (ADR-0012 §3).
- Required: "Records never contain file paths; tuning comes from `OverworldConfig` or records, validated by `OverworldConfig.validate()`" (ADR-0012 §9).
- Guardrail: none (load-time/CI check, not a per-frame budget).

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-45f [D] (R19, junction coverage)** Every leg's junction nodes include its start EntryPoint, one node per room it crosses, and every critical-path cell where the walk grid branches toward a different required or optional end. Every leg ends in a beacon, and I18 holds.

---

## Implementation Notes

*Derived from ADR-0012 and GDD rule 19:*

Rule 19's "Junctions" clause is the authoring contract this story enforces: a level designer cannot leave a choice point on a leg unmarked. The check runs over the leg's `L_crit` (and, where defined, `L_bypass`) path at every reachable stage, since a stage raise can change which cells are blocked and therefore which cells branch.

- Junction nodes for a leg must include: its start EntryPoint; one node per room the leg crosses; and every cell of the leg's `L_crit` or `L_bypass` path where the walk grid branches toward a different required or optional end, at every reachable stage that leg is loadable at.
- "Reachable stages" are derived from the ChapterFlow step list, never hand-listed (test plan O-04, consistent with AC-23b).
- Every leg must end in a beacon (rule 19: the last beacon marks the leg's end — an exit, the story encounter, the boss or the café camp).
- Invariant I18 (`beacon_h_m ≥ wall_h_max + 0.5`) must hold, so a banner physically clears into the camera's view; this is a load-time invariant checked by `OverworldConfig.validate()`, not a per-map authoring check, but this AC asserts it holds for the shipped config.
- Follow the test plan's O-04 denominator guard: assert the expected map/leg population first; an empty population is **NOT ASSESSED**, never a pass.
- Each failing-fixture case (a branch cell with no junction node, a leg with no end beacon) must name the map, leg and cell, per ADR-0012's validator convention.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 109 (`story-109-beacon-chain-walkin-capture.md`): the on-screen *visual* guarantee from each junction node — this story only validates junction *placement*.
- Story 112 (`story-112-leg-beacon-chain-and-objective-line.md`): which beacons in the chain are lit for the current leg.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/overworld/beacon_junctions.gd` (new: coverage + leg-end beacon check)
- `src/overworld/junction_node.gd` (new marker: `marker_id`, `leg_id`)
- `src/overworld/waypoint_beacon.gd` (new marker: `marker_id`, `leg_id`, `order`)
- `src/overworld/overworld_map.gd` (`junction_nodes(leg_id)`, `beacons(leg_id)`; both in `marker_ids()`)
- `src/overworld/overworld_config.gd` (`junction_cover_m` 1.5 m)
- `src/overworld/map_validator.gd` (`validate_catalog()` runs `BeaconJunctions.check`)
- `tools/ci/validate_maps.gd` (doc only; the check runs through `validate_catalog()`)
- `data/maps/paris_{town,segment,dungeon,boss_chamber}_placeholder.tscn` (one end beacon per leg; two dungeon junction nodes)
- `tests/unit/overworld/data/beacon_junction_coverage_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/overworld/data/beacon_junction_coverage_test.gd` — must exist and pass.

**Status**: [x] Created and passing (10/10; full suite 1180/1180, 2026-10-30)

---

## Dependencies

- Depends on: `story-074-map-exit-and-critical-path-reference-integrity.md` (map leg / critical-path record validation, AC-30a)
- Unlocks: `production/epics/overworld-exploration-encounters/story-109-beacon-chain-walkin-capture.md`, `production/epics/overworld-exploration-encounters/story-112-leg-beacon-chain-and-objective-line.md`, `production/epics/overworld-exploration-encounters/story-135-level-review-walkin-tool.md`

---

## Completion Notes

**Completed**: 2026-10-30 (awaiting /story-done)

- Junction nodes and beacons are scene markers (`JunctionNode`, `WaypointBeacon`), not record fields, so `map_` records gain nothing and carry no paths (ADR-0012 §9). A leg's start EntryPoint is its implicit first junction node.
- Reachable configurations come from the step list: accumulated `flags_on_enter` per step naming the leg, plus `region_liberation_flag` from `last_act_from` on (same convention as `validate_last_act`). They give the stage (`OccupationStage.compute`) and which flag-closed exits are taped (blocked, and no longer an end).
- Rooms = walk-grid components with every checkpoint closed. Branch cell toward each other end = the deepest `L_crit` path cell that also lies on a shortest route to that end.
- Shipped authoring: one end beacon per leg (7); dungeon `dungeon_to_boss` needed two junction nodes (counter fork, beyond the boom). Other legs branch only at their EntryPoint.
- **Deviations**: new knob `OverworldConfig.junction_cover_m` (1.5 m; not yet in the GDD Tuning Knobs table, for game-designer). `L_bypass` paths are not yet checked (TODO; bypass lanes are single-configuration in `BypassSearch`).
- For story 112: `OverworldMap.beacons(leg_id)` returns the chain sorted by `WaypointBeacon.order`; the last is on the leg end.
