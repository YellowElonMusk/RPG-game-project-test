# Story 073: Every checkpoint has exactly one resolving requirement, reachable fight-free on the critical path

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-011`, `TR-overworld-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: `validate_maps.gd` runs a fixed-point search over each critical-path leg's reachable cells, opening a checkpoint only once its fight-free `obtained_at` source has already been reached earlier on the same leg, and asserts every checkpoint's single requirement resolves.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: The fixed-point reachability search follows the same `AStarGrid2D` bake-order rule as runtime pathing (`update()` once; a dirty grid returns `[]` silently, probed 4.7.2), though this check runs as its own graph walk over the baked walk grid, not through `get_id_path`.

**Control Manifest Rules (this layer)**:
- Required: `tools/ci/validate_maps.gd` asserts, per leg and stage, the ordered bypass search and reference resolution — source: ADR-0012 §3
- Forbidden: Never store a scene path on `MapData` — source: ADR-0012 (Alternative 5)
- Guardrail: Overworld load: one single-pass bake plus one component-labelling pass, inside the fade — source: ADR-0012 Performance (Load Time)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-29 [D] (R10, rule 0)** Every checkpoint has exactly one requirement (an item or a flag), never XP, level or currency, and every requirement names an `obtained_at` source that resolves. On every critical-path leg, at every reachable stage, a fixed-point search over the leg's cells succeeds when it opens a checkpoint only after reaching that checkpoint's fight-free source earlier on the leg; `victory_payoff` sources never count. No critical-path checkpoint has the `encounter` outcome except the region's story encounter. Every return marker is a safe-zone source (with `return_safe_radius_m`), so it lies in a `SAFE` cell, and no return marker lies inside a MapExit rectangle. Here "the leg's cells" are the cells reachable from the leg's start, and a chapter-step flag source counts as reached when it is set on or before the leg's step.

---

## Implementation Notes

*Derived from GDD rule 10 ("No grind blocks", "On the critical path") and rule 0 ("Requirement source"):*

- Every checkpoint has exactly **one** requirement — an item ID or a story flag, never XP, level or currency (rule 10, "No grind blocks").
- Every requirement's `obtained_at` source (rule 0: a `pickup`, a gag `change`, an NPC line, a chapter-step flag, or a `victory_payoff`) must resolve, and `victory_payoff` sources never count as critical-path sources (rule 10).
- The fixed-point search over each critical-path leg's reachable cells opens a checkpoint only once its **fight-free** `obtained_at` source has already been reached earlier on the same leg — proving every critical-path requirement can be met whatever fights the player has avoided.
- No critical-path checkpoint has the `encounter` outcome except the region's story encounter (rule 13a).
- Every return marker is a safe-zone source (`return_safe_radius_m`), lying in a `SAFE` cell, and never inside a MapExit rectangle.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-070/071/072 (checkpoint runtime behavior): the open/redirect/encounter mechanisms this story's search validates against

---

## Files

- `tools/ci/validate_maps.gd`
- `data/maps/*`
- `tests/unit/overworld/data/checkpoint_requirement_and_reachability_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic (Data validation)
**Required evidence**:
- `tests/unit/overworld/data/checkpoint_requirement_and_reachability_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-070-checkpoint-opens-on-met-requirement.md`, `story-071-checkpoint-redirect-and-queue-failure.md`, `story-072-checkpoint-encounter-outcome.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-074-map-exit-and-critical-path-reference-integrity.md`
