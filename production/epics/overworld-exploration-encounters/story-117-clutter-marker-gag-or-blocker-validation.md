# Story 117: Every active clutter marker either responds or blocks a route

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: — (not yet implemented)

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

- [ ] **AC-49 [D] (R16)** For every shipped map at every reachable stage, every active clutter marker is either a `gag` interactable with a response or a route-blocker on the walk grid.

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

- `tools/ci/validate_maps.gd` (clutter marker response-or-blocker check)
- `tests/unit/overworld/data/clutter_marker_validation_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/overworld/data/clutter_marker_validation_test.gd` — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-058-marker-activation-slots-by-stage-and-cap.md` (AC-24, `marker_activation` formula)
- Unlocks: `production/epics/overworld-exploration-encounters/story-118-gag-response-behavior.md`
