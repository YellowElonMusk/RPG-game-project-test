# Story 013: No `active_device_changed` fires for stick drift inside the deadzone, mouse movement under `pointer_switch_px`, or a second input of the active kind

> **Epic**: Input System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (§8)
**ADR Decision Summary**: `active_device_changed` fires only on a change of kind caused by meaningful input; stick drift inside the deadzone, pointer movement below `pointer_switch_px`, and further input of the already-active kind are not changes.
**ADR Version**: ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: None beyond the shared ADR-0003 notes.

**Control Manifest Rules (this layer)**:
- Required: "**Bindings are a catalog record** (`bindings_` prefix); **tuning values** (deadzone, repeat timing, `pointer_switch_px`, pad-style patterns) are a project config (`InputConfig`), not a catalog record"
- Required: "**`InputResolver` (`RefCounted`) owns the binding table, held set, move vector and device state, with no scene-tree dependency.**"
- Guardrail: one dictionary lookup per device event.

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [ ] **AC-11** No `active_device_changed` fires for: stick movement inside the deadzone; cumulative mouse movement below `pointer_switch_px`; a second input from the already-active kind.

---

## Implementation Notes

*Derived from ADR-0003 §8:*

- **Stick drift.** Use raw values whose length is strictly below `config.deadzone` (e.g. `deadzone − 1e-3`). Include a diagonal drift whose per-axis values are each under the deadzone and whose length is also under it. **Starting state (pinned):** the stick-drift case starts in the initial `keyboard_mouse` state and asserts `active_device == KEYBOARD_MOUSE` at the end.
- **Mouse.** Use `pointer_switch_px − 1` px total, accumulated over several motion events, to prove accumulation and not per-event checks. **Starting state (pinned):** start with a pad press, mark, then feed the motion. Assert `active_device == GAMEPAD` at the end. (From the initial `keyboard_mouse` state the case would pass vacuously.)
- **Second input.** In `gamepad`, a second pad button emits nothing. In `keyboard_mouse`, a second key emits nothing. Both cases are recorded from after the initial switch.
- Run once with `NON_DEFAULT` (deadzone, `pointer_switch_px`).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 012: the positive switch cases.
- Story 015: a second pad of the same kind.

---

## Files

- `tests/unit/input/input_active_device_test.gd` (shared with story 012)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, fix applied: non-trivial starting states). The developer implements against these — do not invent new test cases during implementation.*

**AC-11** — no device change for drift, sub-threshold mouse movement, or a second input of the active kind.

```
Test: stick drift inside the deadzone does not switch
Given: R (keyboard_mouse), cfg ∈ {DEFAULT, NON_DEFAULT}
When:  pad_axis left_x at raw cfg.deadzone − 1e-3; then diagonal (0.13, 0.13) at DEFAULT (length < 0.20); NON_DEFAULT uses a diagonal scaled to length deadzone − 1e-3
Then:  no active_device_changed; active_device == KEYBOARD_MOUSE
Edge cases: none
```

```
Test: mouse movement under pointer_switch_px does not switch
Given: R, pad south pressed, mark
When:  4 motion events summing to cfg.pointer_switch_px − 1
Then:  rec.since(mark) has no active_device_changed; active_device == GAMEPAD
Edge cases: none
```

```
Test: a second input of the active kind does not switch
Given: (a) R after pad south (gamepad), mark; (b) R after a key press, mark
When:  (a) pad east; (b) key Esc, plus a mouse click
Then:  rec.since(mark) has no active_device_changed
Edge cases: none
```

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/input/input_active_device_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/input-system/story-012-active-device-changed.md`
- Unlocks: `production/epics/input-system/story-015-first-pad-sets-style.md`
