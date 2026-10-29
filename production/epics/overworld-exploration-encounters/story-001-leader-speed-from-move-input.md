# Story 001: The leader's displacement matches walk_speed times elapsed time at full tilt

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
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
**ADR Decision Summary**: ADR-0012 makes `GroundMover.step()` a pure static function that turns an input vector into ground-plane velocity on `ow_dt`; ADR-0003 is what supplies that vector — `machine.get_move_vector(self)` returns the deadzone-rescaled, diagonal-normalized stick/keyboard vector the mode reads every frame.
**ADR Version**: ADR-0012 2026-10-23; ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: ADR-0003 is post-cutoff risk (SDL3 gamepad driver landed in 4.5, dual focus in 4.6, keyboard/mouse device IDs in 4.7) — a binding-level claim needs checking against those changes. `GroundMover` itself touches no post-cutoff API; it is pure GDScript.

**Control Manifest Rules (this layer)**:
- Required: "Movement goes through the pure static `GroundMover.step(pos, input_vec, dt, grid, cfg, speed, blocked_mask)`... read input only from `machine.get_move_vector(self)`" — source: ADR-0012 §2
- Required: "All overworld logic steps on one clock `ow_dt = min(delta, dt_max)`, accumulated only in Exploring" — source: ADR-0012 §2
- Forbidden: "Never use a physics body, area, cast or collision shape in the Overworld, 2D or 3D" — source: ADR-0012 §2, §3

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-1a [L] (R1)** GIVEN `move` at full tilt for N frames, THEN the leader's displacement is `walk_speed · Σdt` (within 1e-4).

---

## Implementation Notes

*Derived from ADR-0012 Implementation Guidelines and GDD rule 1:*

This is the simplest movement contract in the system, and the one every other
movement story's test fixture builds on: a leader walking at full stick/key
deflection covers exactly `walk_speed` metres per second of `ow_dt`, with no
run button and no held-input modifier (GDD rule 1).

- Velocity is `input_vec.limit_length(1) × speed`, where `speed` is `cfg.walk_speed` for the leader (ADR-0012 §2, `GroundMover.step`).
- The leader reads its input only through `machine.get_move_vector(self)` (ADR-0003); `OverworldMode._process(delta)` computes `ow_dt = min(delta, dt_max)` and steps on that, only while Exploring.
- Expected displacement must be computed from `OverworldConfig.walk_speed` through the formula, never a literal, and the test must also run once with a non-default `walk_speed` (AC preamble, test harness notes).
- Use a `dt` that does not land `N · dt` on a clean threshold, per the harness's timing rule, even though this AC has no timed transition — keep the habit consistent with later timing-sensitive stories.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: partial-tilt and over-unity (diagonal) input magnitude scaling.
- Story 003: confirming that non-`move` actions never change leader speed.
- Story 004: wall collision, sliding and corner assist.

---

## Files

- `src/overworld/ground_mover.gd`
- `src/overworld/overworld_mode.gd`
- `src/overworld/overworld_config.gd`
- `tests/unit/overworld/ground_mover_speed_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/ground_mover_speed_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing; full suite green, 631/631 (tag ow001)

---

## Completion Notes

- `GroundMover.step()` implemented as a pure static function in
  `src/overworld/ground_mover.gd`, with `MoveResult` as a nested class
  (no separate file in ADR-0012's Key Interfaces). `velocity =
  input_vec.limit_length(1) * speed`; `pos` advances by `velocity * dt`.
  `grid`, `cfg` and `blocked_mask` are accepted per the ADR's declared
  signature but not yet read -- collision is story 004's scope.
- `grid` is typed `Object`, not `WalkGrid`: `walk_grid.gd` is story 004's
  file and does not exist yet. Narrow this parameter's type the same story
  that adds it.
- `OverworldConfig` (`src/overworld/overworld_config.gd`) is a minimal stub
  with only `walk_speed` (default 3.5, GDD Tuning Knobs), following the
  same precedent as `src/presentation/presentation_config.gd`. `validate()`
  exists per the ADR's declared surface but returns `[]`: every I1-I18
  invariant that reads `walk_speed` also reads a field this stub does not
  yet declare.
- `OverworldMode` (`src/overworld/overworld_mode.gd`) wires
  `machine.get_move_vector(self)` into `GroundMover.step()` on
  `ow_dt = min(delta, dt_max)`, satisfying the control manifest's movement
  rule. Flagged deviation: the leader's position is a private field, not
  `WorldState.party_pos` -- `world_state.gd` does not exist yet, and
  `GameRoot`'s `pre_setup` injector does not assign `world_state` or
  `presentation_settings` yet either (both are open TODOs in
  `src/game_state/game_root.gd` pending ADR-0008/0009). `dt_max` falls back
  to a local constant at the GDD default (0.10 s) until that injection
  lands.
- Test: `tests/unit/overworld/ground_mover_speed_test.gd`, two cases (AC-1a
  default config, and a non-default `walk_speed` per the formula-test
  harness rule), `N = 37` frames at `dt = 0.013 s` (not a clean threshold).

---

## Dependencies

- Depends on: None
- Unlocks: `production/epics/overworld-exploration-encounters/story-002-leader-speed-scales-with-move-magnitude.md`, `production/epics/overworld-exploration-encounters/story-003-only-move-changes-leader-speed.md`, `production/epics/overworld-exploration-encounters/story-004-wall-slide-and-corner-assist.md`
