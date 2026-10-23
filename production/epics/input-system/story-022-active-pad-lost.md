# Story 022: The active pad disconnecting while `fast_forward` is held emits `released(fast_forward)` and then `device_lost`

> **Epic**: Input System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (§1 `on_joy_connection`, §8: "`device_lost()` fires only for the active pad, after its held actions are released")
**ADR Decision Summary**: On a pad disconnect the resolver releases every action that pad alone was holding, clears its stick and repeat state, and only then — and only for the active pad — emits `device_lost()`.
**ADR Version**: ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: `Input.joy_connection_changed` exists on 4.7.2 (spike item 3); its timing on a real unplug is unverified.

**Control Manifest Rules (this layer)**:
- Required: "**`device_lost()`/`focus_lost()` fire only after every held action's `action_released`**"
- Required: "**`InputResolver` (`RefCounted`) owns the binding table ... Driven only through `feed_event()`, `tick()`, `set_window_focused()` and `on_joy_connection()`**"
- Forbidden: "**Never make Input an autoload** — it holds mutable state"

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [ ] **AC-14** The active pad disconnects while `fast_forward` is held: `released(fast_forward)` is emitted, then `device_lost`.

---

## Implementation Notes

*Derived from ADR-0003 §1, §8 and the GDD States table:*

- **Disconnect handling.** In `on_joy_connection(device, false, _)`:
  - remove every held-set source belonging to `device`, emitting `action_released` for each action whose set becomes empty;
  - zero that pad's stick axes, so `get_move_vector()` drops its contribution;
  - clear its repeat state;
  - then, **only if `device` is the active pad**, emit `device_lost()`.
- **Signal order on an active-pad disconnect (pinned, QL-STORY-READY 2026-10-23).** Every `action_released` (in hold order), then `device_lost()`, then `active_device_changed(KEYBOARD_MOUSE, <unchanged pad_style>)`. The active pad is cleared, and `active_device == KEYBOARD_MOUSE`. This follows the GDD States row "Active: gamepad → Active: keyboard_mouse, plus `device_lost`", keeping the AC-14 adjacency of `released` and `device_lost`. Consumers (Game State, PromptFacade) must not depend on the third signal arriving before `device_lost`.
- **Assertion order.** Assert on the recorder: `released(fast_forward)` precedes `device_lost`. Also hold `confirm` and a stick direction, and check every release precedes the signal.
- Game State's response to `device_lost` (opening the Menu) is tested in the Game State GDD, not here.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 023: a non-active pad disconnecting.
- Story 024: reconnect and `device_restored`.
- Story 025: the shell's `joy_connection_changed` wiring.
- `production/epics/game-state-scene-flow/`: the Menu opening on `device_lost`.

---

## Files

- `src/input/input_resolver.gd`
- `tests/unit/input/input_device_connection_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, fix applied: post-loss signal order pinned). The developer implements against these — do not invent new test cases during implementation.*

**AC-14** — releases precede `device_lost`, then the kind change.

```
Test: releases precede device_lost, then the kind change
Given: R; on_joy_connection(0, true, xbox name); pad west held on device 0 (active pad)
When:  on_joy_connection(0, false, "")
Then:  rec.since(mark) == [released(fast_forward), device_lost(), active_device_changed(KEYBOARD_MOUSE, &"xbox")]
Edge cases:
  - with west, south and left stick (raw 1, 0) all held: both released entries come before device_lost, and a device_lost handler reads get_move_vector() == ZERO
  - fast_forward also held on Shift: no released(fast_forward); device_lost is still emitted
  - repeat state cleared: no nav_* after the disconnect while ticking
```

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/input/input_device_connection_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on:
  - `production/epics/input-system/story-008-two-device-hold-release.md`
  - `production/epics/input-system/story-012-active-device-changed.md`
- Unlocks:
  - `production/epics/input-system/story-023-non-active-pad-lost.md`
  - `production/epics/input-system/story-024-device-restored.md`
  - `production/epics/input-system/story-025-focus-lost-and-gained.md`
