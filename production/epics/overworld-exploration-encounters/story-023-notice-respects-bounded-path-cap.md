# Story 023: A leader behind a fence past notice_path_cap_m is never noticed

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: The notice test's last, most expensive check is a bounded uniform-cost (Dijkstra-style) search over symbol-legal cells, stopping at path length `notice_path_cap_m`; a leader the search cannot reach within that cap is never noticed, however close it is in a straight line.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: The bounded search is pure GDScript over a fixture grid; it does not call `AStarGrid2D` (that is reserved for Chasing/Returning per ADR-0012 §5), so no engine-pinning concern applies here.

**Control Manifest Rules (this layer)**:
- Required: "Symbol AI lives in the pure `SymbolBrain` (sub-states, notice with cheap checks first then a bounded uniform-cost search...)" — source: ADR-0012 §5
- Guardrail: "Overworld symbol stepping + notice searches + repaths: ≤ 2.0 ms per frame at p99" — source: ADR-0012 Performance, Overworld GDD AC-46

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-9d [L] (R5, reachability)** GIVEN the leader within the notice radius but behind a fence with no path within `notice_path_cap_m`, THEN no notice on any frame over 10 s.

---

## Implementation Notes

*Derived from ADR-0012 §5 and GDD rule 5's notice test, check 4:*

GDD rule 5: "a **bounded search** (uniform-cost, Dijkstra-style, over
symbol-legal cells with √2 diagonal steps, stopping at path length
`notice_path_cap_m`) reaches the leader's chase target with `path_dist` ≤
`notice_path_cap_m`. The search never explores beyond the cap, so its cost is
bounded inside a component... A Clerk never notices a leader it could not
reach, such as one on the far side of a fence."

- Fixture: a symbol and a leader within straight-line `symbol_chase_m` of each other, but separated by a fence whose only route around exceeds `notice_path_cap_m` (default 4.5 m, safe range 4.3–5.0).
- Step the brain for 10 s of simulated `ow_dt` (covering many frames at the default and at `dt_max`) and assert notice never fires on any frame — the search budget (checks 1–3 already pass in this fixture) is exhausted by check 4 every time.
- The leader and symbol remain in the **same** symbol-legal component in this fixture (the fence creates a long detour, not a disconnection) — that distinguishes this from the component-rejection check (AC-9h, outside this batch), which is a different, cheaper, earlier check.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 022: the front/rear radius check (check 1), assumed to pass in this fixture.
- Story 025: the `SAFE`-cell check (check 2), assumed to pass here.
- AC-9h/9k (outside this batch): the component-rejection check (check 3) and the cached-waypoint/per-symbol-cache behaviour of the bounded search.

---

## Files

- `src/overworld/symbol_brain.gd`
- `src/overworld/walk_grid.gd`
- `tests/unit/overworld/symbol_brain_notice_path_cap_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/symbol_brain_notice_path_cap_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-020-patrol-loop-and-pingpong-traversal.md`
- Unlocks: None
