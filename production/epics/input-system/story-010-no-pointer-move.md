# Story 010: No pointer event ever produces a `move` action

> **Epic**: Input System
> **Status**: Complete (2026-10-30)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (§8: "No pointer event ever affects `move` (AC-21)")
**ADR Decision Summary**: Pointer events feed only the raw pointer signals and `pointer_position`; they never touch the move vector or the derived `nav_*` steps (no click-to-move).
**ADR Version**: ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: None beyond the shared ADR-0003 notes.

**Control Manifest Rules (this layer)**:
- Required: "**`action_pressed`/`action_released` fire on edges ... `nav_*` are derived actions, never bound directly**"
- Required: "**The binding table is the resolver's own dictionary, matched by `physical_keycode` / `JoyButton` / `JoyAxis` / `MouseButton`**, never `InputMap`"
- Guardrail: one dictionary lookup per device event.

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [x] **AC-21** No pointer event ever produces a `move` action (no click-to-move).

---

## Implementation Notes

*Derived from ADR-0003 §8:*

- Feed every mouse event kind: motion with large `relative`, all `MouseButton`s including wheel left/right, and press and release. Assert `get_move_vector() == Vector2.ZERO` after each, and that no `action_pressed` for any `move_*` or `nav_*` ever fires. `nav_*` is derived from `move`, so a pointer must not produce menu steps either.
- Also assert while a key holds `move_right`: pointer events leave the vector at exactly `(1, 0)`, and the `nav_right` step count equals story 018's computed count for that hold.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 009: the pointer signals themselves.
- Story 018: the `nav_*` repeat schedule.

---

## Files

- `tests/unit/input/input_pointer_test.gd` (shared with story 009)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

**AC-21** — no pointer event affects `move` or `nav_*`.

```
Test: no pointer event affects move or nav
Given: R with DEFAULT
When:  feed, parametrized:
  - mouse_motion with relative (500, −500);
  - press and release of every MouseButton (LEFT, RIGHT, MIDDLE, WHEEL_UP/DOWN/LEFT/RIGHT, XBUTTON1/2);
  - tick through 2 × repeat_delay
Then:  get_move_vector() == ZERO after every event; rec has no action_pressed whose name starts with "move_" or "nav_"
Edge cases:
  - with D held, every pointer event leaves the vector exactly (1, 0), and the nav_right step count equals story 018's count for that hold
```

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/input/input_pointer_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (2026-10-30)

---

## Dependencies

- Depends on:
  - `production/epics/input-system/story-009-raw-pointer-events.md`
  - `production/epics/input-system/story-018-menu-repeat-timing.md` (the QA edge case compares the `nav_right` count with story 018's schedule)
- Unlocks: None

## Completion Notes

*2026-10-30, implementation (autonomous run, tag sin2).*

- **Files**: `src/input/input_resolver.gd` (No new code needed: mouse events never reach the binding table or the menu-direction derivation, so AC-21 already held; tests added to prove it.); `tests/unit/input/input_pointer_test.gd`; `tests/unit/input/input_test_support.gd` (Recorder filters)
- **Tests**: 2 parametrized cases x DEFAULT/NON_DEFAULT: every mouse event kind leaves the vector at ZERO and emits no action; with move_right held the vector stays (1, 0) and the nav_right count equals the story-018 step count. Input dir 193/193 (single-dir run; full suite run by main session).
- **Deviations**: The nav_right count relies on the menu-repeat stream added for story 020 (story 018 itself is not closed).
