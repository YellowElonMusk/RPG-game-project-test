# Story 002: Leader speed scales with move magnitude, and keyboard diagonals never exceed full speed

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
**ADR Decision Summary**: `GroundMover.step()` takes `velocity = input_vec.limit_length(1) × speed`, so any input magnitude above 1 (a diagonal keyboard vector before normalising) clamps to full speed, and any magnitude below 1 (partial stick tilt) scales speed down proportionally. ADR-0003's `get_move_vector()` already diagonal-normalizes and deadzone-rescales before the Overworld ever sees the vector.
**ADR Version**: ADR-0012 2026-10-23; ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Same ADR-0003 risk as story 001 — the stick-output and diagonal-normalization path crosses the 4.5–4.7 input changes the model's training data does not cover.

**Control Manifest Rules (this layer)**:
- Required: "Movement goes through the pure static `GroundMover.step(pos, input_vec, dt, grid, cfg, speed, blocked_mask)`... read input only from `machine.get_move_vector(self)`" — source: ADR-0012 §2
- Forbidden: "Never use a physics body, area, cast or collision shape in the Overworld, 2D or 3D" — source: ADR-0012 §2, §3

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-1b [L] (R1)** GIVEN `move` at magnitude 0.5, THEN speed is `0.5 · walk_speed`. GIVEN magnitude 1.4 (a diagonal keyboard vector before normalising), THEN speed is `walk_speed`.

---

## Implementation Notes

*Derived from ADR-0012 Implementation Guidelines and GDD rule 1:*

GDD rule 1 fixes one speed with no run button: "a stick's partial tilt walks
proportionally slower and keyboard input always gives full speed." The clamp
that makes keyboard diagonals behave is `limit_length(1)` inside
`GroundMover.step`, applied **after** `get_move_vector()` has already done its
own diagonal normalization — this AC exercises the GroundMover clamp directly
with a pre-normalization magnitude of 1.4 to prove the two layers compose
correctly rather than double-scaling.

- `velocity = input_vec.limit_length(1) × speed` (ADR-0012 §2, step 1).
- Test both ends: magnitude 0.5 (linear scaling) and magnitude 1.4 (clamp to 1.0, i.e. full `walk_speed`).
- Expected values come from `OverworldConfig.walk_speed` through the formula; run the test once more against a non-default `walk_speed`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: full-tilt displacement over time.
- Story 003: non-`move` actions never affecting speed.
- Story 004: collision, wall-slide and corner assist.

---

## Files

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

**Status**: [x] Passing — 6/6 test cases in file (4 new for this story), full suite 635/635 green

---

## Completion Notes

`GroundMover.step()` already implemented `velocity = input_vec.limit_length(1.0) * speed`
in story 001, so AC-1b held with no behavior change: `limit_length(1.0)` is a
no-op below magnitude 1 (linear scaling) and clamps to length 1 above it (full
`speed`). This story added the missing tests exercising both ends directly —
`test_partial_tilt_speed_scales_linearly_with_magnitude` (0.5) and
`test_magnitude_above_one_clamps_to_full_walk_speed` (1.4), each also run once
against a non-default `walk_speed` per the formula-test harness rule — and a
doc-comment note on `GroundMover.step()` tying the clamp to story 002 and
explaining why it composes with ADR-0003's diagonal normalization rather than
double-scaling. No change to `src/input/input_resolver.gd` was needed or made.

---

- Status synced 2026-10-30 from commit d4e502e.

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-001-leader-speed-from-move-input.md`
- Unlocks: None
