# Story 081: A MapExit re-fires only after the leader leaves and re-enters its rectangle

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: An exit fires only when the leader's centre **enters** its rectangle from outside; a leader placed inside one by a load must leave it first, and a held `move` across a map change cannot immediately cross back.
**ADR Version**: ADR-0012 2026-10-23; ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No new runtime API; per-frame order (Edge Cases) checks exits right after moving the leader, enter-edge only. Risk follows ADR-0003's row (HIGH) since the test drives held `move` input across a map change.

**Control Manifest Rules (this layer)**:
- Required: Per-frame order (Exploring): move the leader → check map exits (enter-edge only) → step symbols → swept contact → interaction — source: ADR-0012 §5, Edge Cases
- Forbidden: Never write `WorldState` from `OverworldMode._ready()` — source: ADR-0012 §4
- Guardrail: Overworld load: one single-pass bake plus one component-labelling pass, inside the fade — source: ADR-0012 Performance (Load Time)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-30g [L] (R11, map exits)** GIVEN a leader placed inside a MapExit rectangle by a load, THEN no exit fires until the leader has left the rectangle and entered it again. GIVEN a `move` held for `ceil(2/dt)` frames across a map change, THEN the leader does not cross back.

---

## Implementation Notes

*Derived from GDD rule 11 ("Map exits") and the Edge Cases per-frame order:*

- "Crossing a `MapExit` rectangle requests a fade to the target map's `EntryPoint`... An exit fires only when the leader's centre **enters** its rectangle from outside. A leader placed inside one (by a load) must leave it first."
- Per-frame order: exits are checked right after moving the leader, enter-edge only — this story implements the "was outside last frame, is inside this frame" edge tracking that makes "enter" meaningful across a load.
- The held-`move`-across-a-map-change case exercises story-080's EntryPoint clearance together with this enter-edge tracking: even with input held toward the exit the leader just used, the leader cannot be "inside" that exit on arrival (by construction) and therefore cannot immediately re-trigger it.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-080-entry-point-exit-clearance: the data-level EntryPoint/MapExit geometry this relies on (AC-30f)

---

## Files

- `src/overworld/overworld_mode.gd` (exit enter-edge tracking)
- `src/overworld/walk_grid.gd`
- `tests/unit/overworld/map_exit_reentry_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/map_exit_reentry_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-080-entry-point-exit-clearance.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-082-patrol-legality-at-every-reachable-stage.md` (rule 12 patrol-legality and bypass checks)

## Completion Notes (2026-10-30)

- The exits were already edge-triggered (`_check_exits` fires only from outside to inside); this story adds the evidence test.
- A real GameRoot drives a move held for `ceil(2/dt)` frames through the Town → segment change; no exit fires on the far side.
- Mutation checked: a level-triggered exit fails a test here.
