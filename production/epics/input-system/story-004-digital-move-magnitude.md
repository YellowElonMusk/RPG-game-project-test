# Story 004: A single key or d-pad direction gives magnitude 1, and a diagonal key pair gives length 1

> **Epic**: Input System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (§8, `get_move_vector()`)
**ADR Decision Summary**: The resolver composes `move_up/down/left/right` into a single move vector read through `get_move_vector()`. Digital sources contribute magnitude 1 per axis, and a digital diagonal is normalized so diagonal movement is never faster than straight movement.
**ADR Version**: ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: None beyond the shared ADR-0003 notes.

**Control Manifest Rules (this layer)**:
- Required: "**`InputResolver` (`RefCounted`) owns the binding table, held set, move vector and device state, with no scene-tree dependency.**"
- Required: "**A mode reads movement only through `machine.get_move_vector(self)`; discrete actions arrive only through `handle_action()`.**" (consumer side; the resolver's `get_move_vector()` is the source)
- Forbidden: "**Never use Godot's `InputMap`/`Input` singleton for gameplay actions** — it merges devices and can't express the GDD's per-axis arbitration rules"

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [ ] **AC-4** A single key or d-pad direction yields magnitude 1. Two diagonal keys (W+D) yield length 1 within tolerance.

---

## Implementation Notes

*Derived from ADR-0003 §8:*

- `get_move_vector()` composes `move_up/down/left/right` into a vector. Digital sources (keys, d-pad buttons) are magnitude 1 per axis. Normalize the digital diagonal to length 1 (GDD rule 6: "walking diagonally is never faster than walking straight"). Use 1e-6 tolerance (`EPS_V`; `is_equal_approx` or gdUnit4 `is_equal_approx(expected, Vector2(1e-6, 1e-6))`).
- **Move vector sign convention (pinned).** `move_right` → (+1, 0), `move_left` → (−1, 0), `move_up` → (0, −1), `move_down` → (0, +1) (y-down, matching raw `JOY_AXIS_LEFT_Y` and `Input.get_vector`). *Ruling 2026-10-23, to be recorded in ADR-0003 §8 by technical-director; ADR-0012 owner to confirm.*
- Cover arrows, WASD and d-pad, parametrized over the four directions and the four diagonals.
- Normalize only when the digital vector's length is above 1. Story 006's arbitration runs per axis first, and normalization is the last step.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: the stick deadzone rescale.
- Story 006: opposite-direction cancellation and stick/d-pad arbitration.

---

## Files

- `src/input/input_resolver.gd`
- `tests/unit/input/input_move_vector_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE; sign covered by the pinned convention). The developer implements against these — do not invent new test cases during implementation.*

**AC-4** — digital magnitude 1, diagonal length 1.

```
Test: a single digital direction has magnitude 1
Given: R with DEFAULT
When:  hold one of W, A, S, D, the four arrows or the four d-pad buttons (parametrized)
Then:  get_move_vector() equals the convention's unit vector within EPS_V
Edge cases: none
```

```
Test: a diagonal pair is normalized to length 1
Given: R
When:  hold W+D (and, parametrized, the other three WASD diagonals, the arrow diagonals and the d-pad diagonals)
Then:  length == 1 within EPS_V, and the direction equals (±1, ±1).normalized() within EPS_V
Edge cases:
  - key W plus d-pad right (mixed sources) is also length 1
  - releasing one key of the pair leaves the single unit vector
```

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/input/input_move_vector_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/input-system/story-001-default-bindings-press-release.md`
- Unlocks:
  - `production/epics/input-system/story-005-radial-deadzone.md`
  - `production/epics/input-system/story-006-axis-arbitration.md`
  - `production/epics/input-system/story-018-menu-repeat-timing.md`
