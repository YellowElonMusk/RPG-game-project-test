# Story 005: The radial deadzone rescale matches the `stick_output` formula, including the edge, the clamp and the diagonal cases

> **Epic**: Input System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (§4 `InputConfig.deadzone`, §8)
**ADR Decision Summary**: The stick is rescaled radially from `InputConfig.deadzone` (a project config, not a catalog record), applied to the vector's magnitude and clamped to 1. Every formula value comes from `InputConfig`, and tests compute expected values from the config.
**ADR Version**: ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: None beyond the shared ADR-0003 notes.

**Control Manifest Rules (this layer)**:
- Required: "**Bindings are a catalog record** (`bindings_` prefix); **tuning values** (deadzone, repeat timing, `pointer_switch_px`, pad-style patterns) are a project config (`InputConfig`), not a catalog record"
- Required (ADR-0003 Implementation Guidelines, not in the manifest): "Every formula value (deadzone, repeat timing, thresholds, pointer distance) comes from `InputConfig`; tests compute expected values from the config, and each formula test also runs with a non-default config."
- Guardrail: "**Input**: one dictionary lookup per device event, negligible per `tick`; the binding table compiles once at boot in microseconds"

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [ ] **AC-5** Deadzone cases, expected values from the formula: raw at exactly `deadzone` gives 0; raw at `deadzone + ε` gives magnitude at most ε / (1 − deadzone); a diagonal raw input keeps its direction; raw (0.60, 0) gives the formula value; raw magnitude above 1 is clamped to 1. The deadzone applies to the vector's magnitude, not per axis.

---

## Implementation Notes

*Derived from ADR-0003 §4, §8 and the GDD Formulas:*

- **Formula.** `stick_output = 0 if |raw| < deadzone, else raw / |raw| × min(1, (|raw| − deadzone) / (1 − deadzone))`. At exactly `|raw| == deadzone` this yields 0 from both branches, so there is no jump at the edge. A static `stick_output(raw: Vector2, deadzone: float) -> Vector2` helper on `InputResolver` is suggested.
- **Radial, not per axis.** Compute on the `Vector2` length. A test with raw (0.15, 0.15) (length ≈ 0.212 > 0.20) must give a non-zero output, which a per-axis deadzone would zero.
- **Stick input path.** The stick reaches the vector from `InputEventJoypadMotion` on `left_x`/`left_y`. Keep the latest raw value per pad per axis, so story 022 can clear it on disconnect.
- **Expected values.** Every expected value is computed from `config.deadzone` in the test. Run the whole file again with `NON_DEFAULT` (story 001's shared constant; `deadzone = 0.25`). The GDD example (0.60, 0) → (0.50, 0) holds only at 0.20. Derive it, don't hardcode it. ε is pinned to 0.01 by the QA spec.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: combining the rescaled stick with digital sources.
- Story 020: the menu stick threshold.
- Story 025: the re-centre latch after focus return.

---

## Files

- `src/input/input_resolver.gd` (static `stick_output` helper, per-pad raw axis store)
- `tests/unit/input/input_deadzone_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE; ε pinned). The developer implements against these — do not invent new test cases during implementation.*

**AC-5** — radial deadzone rescale per the `stick_output` formula.

```
Test: stick_output matches the formula at the five AC points
Given: cfg ∈ {DEFAULT, NON_DEFAULT}, d = cfg.deadzone, and the expected value computed in the test from the formula
When:  feed pad_axis left_x/left_y for each raw value and read get_move_vector()
Then:
  - raw (d, 0) gives Vector2.ZERO
  - raw (d + 0.01, 0) gives magnitude > 0 and <= 0.01 / (1 − d) + EPS_V
  - raw (0.6, 0.6) × k (diagonal past the deadzone) gives output.normalized() equal to raw.normalized() within EPS_V
  - raw (0.60, 0) gives the formula value: (0.50, 0) at DEFAULT and the derived value at NON_DEFAULT
  - raw (1, 1) (|raw| ≈ 1.414) gives magnitude 1 within EPS_V
Edge cases:
  - the radial check: raw (0.15, 0.15) (length > 0.20) is non-zero at DEFAULT, which a per-axis deadzone would zero
  - raw just under d (d − 1e-3) gives ZERO
  - a static stick_output(raw, d) matches the vector path for the same inputs
```

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/input/input_deadzone_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/input-system/story-004-digital-move-magnitude.md`
- Unlocks:
  - `production/epics/input-system/story-006-axis-arbitration.md`
  - `production/epics/input-system/story-012-active-device-changed.md`
  - `production/epics/input-system/story-020-menu-stick-threshold.md`
  - `production/epics/input-system/story-025-focus-lost-and-gained.md`
