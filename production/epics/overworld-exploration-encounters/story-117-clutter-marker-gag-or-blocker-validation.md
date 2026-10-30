# Story 117: Every active clutter marker either responds or blocks a route

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0001: Content Data Storage (amended by ADR-0012)
**ADR Decision Summary**: ADR-0012 routes every per-map data criterion through `tools/ci/validate_maps.gd`; ADR-0001 fixes the record vocabulary (`gag` is an `Interactable` kind) this check validates against.
**ADR Version**: ADR-0012 2026-10-23; ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Pure data validation; no engine surface. Risk inherited from ADR-0001.

**Control Manifest Rules (this layer)**:
- Required: "`tools/ci/validate_maps.gd` runs after `validate-content.gd`, runs `ContentBootstrap.run()` first, loads and bakes every map, and asserts every [D] criterion of the Overworld GDD" (ADR-0012 §3).
- Guardrail: none.

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-49 [D] (R16)** For every shipped map at every reachable stage, every active clutter marker is either a `gag` interactable with a response or a route-blocker on the walk grid.

---

## Implementation Notes

*Derived from ADR-0012 and GDD rule 16:*

- Rule 16's guardrail: "Every active clutter marker either responds to `confirm` or blocks a route" (Player Fantasy guardrail 4). Purely decorative clutter is set dressing, not a clutter marker, and is exempt from this check.
- "Active" means `marker_activation`'s `visible(m)` is true for the map's current stage (the formula at GDD Formulas § `marker_activation`): a candidate within its kind's cap, not liberated, and the map not region-liberated.
- A marker passes this check if either: it is a `gag` kind with a `response` set (`line`, `change` or `clue`), **or** it is a route-blocker occupying blocked cells on the baked `WalkGrid` (a closed checkpoint, a queue, tape).
- Run over every reachable stage per map (derived from the ChapterFlow step list, test plan O-04, not hand-listed), and follow the O-04 denominator guard: assert the expected population first, so an empty population reports **NOT ASSESSED**, never a pass.
- A failing fixture must name the map, marker and stage.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 118 (`story-118-gag-response-behavior.md`): that each gag *response type* behaves correctly once a marker has one — this story only checks that every active marker has *some* valid response or is a blocker.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/overworld/clutter_response_check.gd` (new: the AC-49 check)
- `src/overworld/map_validator.gd` (`validate_catalog()` runs it)
- `tools/ci/validate_maps.gd` (doc comment only)
- `tests/unit/overworld/data/clutter_marker_validation_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/overworld/data/clutter_marker_validation_test.gd` — must exist and pass.

**Status**: [x] Created and passing (9/9, 2026-10-30); `validate_maps.gd` on shipped data: 0 errors

---

## Dependencies

- Depends on: `story-058-marker-activation-slots-by-stage-and-cap.md` (AC-24, `marker_activation` formula)
- Unlocks: `production/epics/overworld-exploration-encounters/story-118-gag-response-behavior.md`

---

## Completion Notes

**Completed**: 2026-10-30
**Criteria**: 1/1 passing (AC-49)
**Deviations**:
- The check lives in a new pure static class `ClutterResponseCheck` called from `MapValidator.validate_catalog()` (the pattern of `BeaconJunctions` / `PayoffRules`), not inline in `tools/ci/validate_maps.gd`, which only gained a doc line.
- Interpretations (no GDD text pins them): a clutter marker is a `GagInteractable` with a `clutter_kind` or a liberation link, excluding decree gags and liberated-set content; `CheckpointMarker`s are out of scope (they have their own interaction). "Has a response" = non-empty `text`, plus a `rumour_id` for `clue`. "Blocker" = a `blocked_rect` covering at least one baked-walkable cell. A Victory's liberation is not assumed (worst case); a set `liberation_flag` or region liberation deactivates.
**Test Evidence**: `tests/unit/overworld/data/clutter_marker_validation_test.gd` (9 tests): shipped maps clean with the O-04 NOT ASSESSED guard; stages derived from the step list; empty step list assesses nothing; a silent marker named with map/marker/stage; blocker passes; off-grid rect blocks nothing; per-response content; cap and region liberation deactivate.
