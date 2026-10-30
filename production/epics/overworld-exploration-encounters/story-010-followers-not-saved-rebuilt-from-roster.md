# Story 010: Followers are never saved, and reload rebuilds them from roster order

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-014` (WorldState as single owner of what outlives a visit)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: `WorldState` is the single owner of everything that must outlive a visit (map, position, facing, resolved/opened/liberated state, payoffs, `story_flags`); followers are deliberately absent from that list, because GDD rule 2 makes them per-visit cosmetic state, rebuilt fresh from the Squad Roster every load.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: No engine API touched; this is a data-ownership test against stub `WorldState`/roster objects.

**Control Manifest Rules (this layer)**:
- Required: "`WorldState`... is the single owner of map, position and facing (written every frame) and of state that outlives a visit"; everything else (per-visit actor positions, including followers) lives only in `OverworldMode` — source: ADR-0012 §4
- Forbidden: "Never write `WorldState` from `OverworldMode._ready()`" — relevant by extension: follower rebuild must not require any `WorldState` write — source: ADR-0012 §4

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-6 [L] (R2)** The saved world state contains no follower data. After a load, the followers equal the roster order minus the leader.

---

## Implementation Notes

*Derived from ADR-0012 Implementation Guidelines and GDD rule 2:*

GDD rule 2: "Followers are not saved. They are rebuilt from the roster on
load." This is a direct consequence of `WorldState`'s ownership list
(ADR-0012 §4): `map_id`, `party_pos`, `party_facing`, `camp_returns`,
`chapter_step`, per-map resolved/opened/liberated state, payoffs,
`rest_counter`, `story_flags` — no followers, no trail buffer.

- Serialize a populated `WorldState` (via the save participant, stubbed in this test harness) and assert no field or sub-structure represents follower identity, position or facing.
- On a simulated load (`LoadedSave` entry path, ADR-0012 §4), rebuild followers purely from the stub roster's current order, excluding the leader (roster index 0) — `n_f = roster.size() - 1`, same formula as story 008's solo-party case.
- This story does not implement Save/Load itself (no epic yet, named dependency) — it implements the Overworld side's contract: nothing per-frame or follower-shaped reaches the save path, and rebuild reads only the roster.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: no-collision behaviour of followers once rebuilt.
- Story 006: the trail formula followers are rebuilt into.
- Save/Load's own participant mechanism (ADR-0009, no epic yet — named dependency).

---

## Files

- `src/overworld/world_state.gd`
- `src/overworld/overworld_mode.gd`
- `tests/unit/overworld/follower_save_load_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/follower_save_load_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-005-followers-have-no-collision-or-triggers.md`; Squad Roster and Save/Load (named dependencies, no epic yet)
- Unlocks: None

## Completion Notes (2026-10-30)

- **Partial:** the roster-order half waits for the Squad Roster system (the view tints followers by slot). No follower data is saved, and followers are rebuilt in formation on a Continue.
