# Story 054: A flag set mid-visit leaves the stage and active markers unchanged until the next load

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: The stage is computed only when a map loads; a flag set during a visit takes effect only on that map's next load, so clutter never pops in on screen.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: Pure state-timing logic; no engine API involved.

**Control Manifest Rules (this layer)**:
- Required: Stage and marker activation computed only in `OverworldMode._ready()`, on load — ADR-0012 §3, §4
- Forbidden: Never recompute stage or re-run marker activation mid-visit on a flag change
- Guardrail: n/a

---

## Acceptance Criteria

- [x] **AC-23 [L] (R8)** GIVEN a flag set mid-visit, THEN the stage and the active markers are unchanged until that map's next load.

---

## Implementation Notes

*Derived from GDD rule 8 ("When it applies") and ADR-0012 §4 (`OverworldMode._ready()` build order):*

- Load a map at some stage, record its `stage_stored` and the set of active markers (from `marker_activation`'s `visible(m)`).
- Set a stage-raising flag **while still on that map** (simulating a ChapterFlow step change mid-visit); assert both the stage and the active-marker set are byte-for-byte unchanged for the remainder of the visit — no marker pops in, no clutter changes, no lighting profile swap.
- Trigger a map reload (the same map, via a `MapExit` round trip or an explicit reload); assert the stage and active markers now reflect the new flag, computed fresh by `_ready()`'s stage-plus-liberation step (ADR-0012 §4, step 1).
- This story only needs the **timing** guarantee (unchanged until reload); the formula's own correctness is story 053's scope, and this fixture should reuse that formula rather than re-deriving it.

---

## Out of Scope

- `story-053-occupation-stage-formula.md`: the formula itself.
- Marker-activation cap/ordering mechanics: covered elsewhere in this epic (`marker_activation` formula stories).

---

## Files

- `src/overworld/overworld_mode.gd`
- `src/overworld/world_state.gd`
- `tests/unit/overworld/stage_change_waits_for_load_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/stage_change_waits_for_load_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `story-053-occupation-stage-formula.md`
- Unlocks: None

## Completion Notes (2026-10-30)

- Stage-gated markers (`min_stage`) arrive with story 058; today the stage itself is what waits for the next load.
