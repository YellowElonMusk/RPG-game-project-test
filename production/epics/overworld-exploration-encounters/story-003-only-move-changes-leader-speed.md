# Story 003: No action besides move changes the leader's speed

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-29)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine; ADR-0003: Input System
**ADR Decision Summary**: `OverworldMode._process(delta)` reads movement **only** through `machine.get_move_vector(self)`; discrete actions (`confirm`, `cancel`, `menu`) arrive only through `handle_action()` and never touch `GroundMover`. ADR-0003 fixes `move_*` as binding-side sub-actions that are never emitted as discrete actions, so there is no path by which `confirm`/`cancel`/`menu` could leak into the move vector.
**ADR Version**: ADR-0012 2026-10-23; ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Risk sits in ADR-0003's action-map plumbing (4.5–4.7 input changes), not in anything this story's own code touches directly.

**Control Manifest Rules (this layer)**:
- Required: "A mode reads movement only through `machine.get_move_vector(self)`; discrete actions arrive only through `handle_action()`. Modes and overlays must never reference the Input System or connect to its signals directly." — source: ADR-0002 Implementation Guidelines, ADR-0003
- Required: "Movement goes through the pure static `GroundMover.step(...)`... read input only from `machine.get_move_vector(self)`" — source: ADR-0012 §2

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-1c [L] (R1)** No input action other than `move` changes the leader's speed. The actions tested are `confirm`, `cancel` and `menu`, held and pressed.

---

## Implementation Notes

*Derived from ADR-0012 Implementation Guidelines and GDD rule 1:*

GDD rule 1 states there is "no run button, held or toggled" — this AC is the
negative-space proof of that: nothing other than the `move` vector may ever
scale the leader's speed, however the other actions are driven.

- Drive the fixture's synthetic action source (test harness) with `confirm`, `cancel` and `menu`, each both as a discrete press and held across multiple frames, while `move` stays at a fixed non-zero magnitude.
- Assert the leader's speed (derived from `MoveResult.distance_moved / dt`) is unchanged by any of those three actions, in any combination or order.
- `OverworldMode._process(delta)` must not branch on those actions before computing `velocity`; they are consumed by `handle_action()`, a separate call path from the movement step (ADR-0002 Implementation Guidelines).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001, 002: the `move` vector's own effect on speed.
- Story 004: collision, wall-slide and corner assist.
- Stories 011–016: what `confirm` actually does through `probe()`.

---

## Files

- `src/overworld/overworld_mode.gd`
- `src/overworld/ground_mover.gd`
- `tests/unit/overworld/ground_mover_speed_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/ground_mover_speed_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing

---

## Completion Notes

- `OverworldMode.handle_action()` was already a pure fall-through (`return false`)
  that never touches `GroundMover` or `_leader_pos`, and `_process()` never
  branches on an action -- AC-1c held from story 001's stub onward. This story
  adds the proof: `get_last_distance_moved()` (backed by a new private
  `_last_distance_moved` field, set from each step's `MoveResult`) so a test can
  read this frame's speed through the real call path instead of reaching into
  `_leader_pos`, plus doc comments on `handle_action()`/`_process()` naming
  AC-1c explicitly.
- Tests drive a real `OverworldMode` wired to a real `GameStateMachine`
  (`GameStateFixtures.make_machine_in_overworld()`, with a bound
  `SyntheticActionSource` only to supply the fixed move vector) through
  `mode.handle_action()` directly, not by calling `GroundMover.step()` or
  going through the machine's own action-source dispatch --
  `confirm`/`cancel`/`menu` as discrete press/release, held across
  `_N_FRAMES` frames, and in overlapping combinations/orders, while the move
  vector stays fixed. Added to the existing `ground_mover_speed_test.gd` per
  the story's own Files list rather than a new file.
- **Deviation, flagged**: routing `menu` through the full machine's bound
  `SyntheticActionSource` (as the Implementation Notes' "drive the fixture's
  synthetic action source" literally reads) fails, not because of a bug in
  this story's code, but because `GameStateMachine._on_source_action_pressed()`
  intercepts `menu` *before* dispatch and opens the pause overlay itself
  (game-state-scene-flow stories 024/025, already shipped) -- the overlay then
  takes input ownership and `get_move_vector()` correctly returns `ZERO`, an
  intentional pause-on-menu behavior this story does not own. Calling
  `handle_action()` directly isolates exactly the call path AC-1c does own
  (whether `OverworldMode` itself ever lets a discrete action reach
  `GroundMover`) without conflating it with that other system. Watched the
  unfixed version fail first (`distance 0.0 != ~0.0455` for `menu`) before
  applying this fix, confirming the test was exercising a real path.
- No deviations from the ADRs otherwise. No production logic changed besides
  the new read-only getter and comments.

---

- Status synced 2026-10-30 from commit 781291c.

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-001-leader-speed-from-move-input.md`
- Unlocks: None
