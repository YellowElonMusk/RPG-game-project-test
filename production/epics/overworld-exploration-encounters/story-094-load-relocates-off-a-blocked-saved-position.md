# Story 094: A reload moves the leader off a position a new blocker has covered

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: On a `LoadedSave` entry, a saved position that now lies in a blocked cell is relocated to the nearest walkable cell by breadth-first search within 5 m, falling back to the map's first EntryPoint.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: Pure graph BFS over `WalkGrid`; no physics or rendering surface involved.

**Control Manifest Rules (this layer)**:
- Required: "Entry paths: … `LoadedSave` → saved position, **no respawn**, relocate a now-blocked position by BFS (≤ 5 m, else first EntryPoint)" — source: ADR-0012 §4

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-35b [L] (R15, Edge Cases)** GIVEN a save whose position now lies in a cell blocked by a newly active blocker, THEN on load the leader is at the nearest walkable cell. If none is within 5 m, the leader is at the first EntryPoint.

---

## Implementation Notes

*Derived from ADR-0012 §4 and GDD rule 15, Edge Cases ("If a stage raise activates a blocker on the saved position"):*

- Fixture: save a position, then activate a blocker over that cell before load (for example, a stage-raise flag that lands a queue or checkpoint there).
- On load, if `world_state.party_pos` resolves to a blocked cell, search outward by breadth-first search over the walk grid for the nearest walkable cell, capped at 5 m.
- If none is found within 5 m, place the leader at the map's first `EntryPoint` instead.
- This is distinct from `on_map_reenter` respawn: a `LoadedSave` entry never applies respawn (ADR-0012 §4 entry-path table) — this relocation is purely about the saved cell having become illegal, not about resetting the visit.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The frame-by-frame `WorldState` write contract this relocation reads from (story 093).
- The rest of the save/load round trip (story 095).

---

## Files

- `src/overworld/world_state.gd`
- `tests/unit/overworld/continue_relocates_off_blockers_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/continue_relocates_off_blockers_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-093-world-state-writes-only-position-and-events.md`
- Unlocks: None further in this epic

## Completion Notes (2026-10-30)

- `OverworldMode._relocate_off_blockers()` runs on a Continue that lands on the saved position, not on a camp's return EntryPoint.
- Blockers (closed checkpoints, standing clutter, tape) are in place by the map-entry commit, so the check runs there during a transition, or at once outside one.
- A blocked saved cell moves the leader to the nearest walkable cell centre within 5 m, or else to the map's first EntryPoint. The followers re-form there.
- Mutation checked: disabling the relocation fails a test here.
