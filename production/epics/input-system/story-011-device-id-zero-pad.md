# Story 011: A gamepad reporting device ID 0 makes the active device `gamepad`, and a key press makes it `keyboard_mouse` through the keyboard device-ID constant

> **Epic**: Input System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (Implementation Guidelines: device identity; §8)
**ADR Decision Summary**: Device kind is classified by event type first, with `InputEvent.DEVICE_ID_KEYBOARD`/`DEVICE_ID_MOUSE` (4.7) as the confirming identity. Device 0 is a valid gamepad ID and never means keyboard or mouse.
**ADR Version**: ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: `InputEvent.DEVICE_ID_KEYBOARD` / `DEVICE_ID_MOUSE` are post-cutoff (4.7). Verified on 4.7.2: `InputEventKey.new()` defaults to 16 and `InputEventMouseButton.new()` to 32.

**Control Manifest Rules (this layer)**:
- Forbidden: "**Never use `event.device == 0` to mean mouse/keyboard** — since 4.7 they no longer report device `0`"
- Required: "**`InputResolver` (`RefCounted`) owns the binding table, held set, move vector and device state, with no scene-tree dependency.**"
- Guardrail: one dictionary lookup per device event.

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [ ] **AC-13** A gamepad reporting device ID 0 makes the active device `gamepad`. A key press makes it `keyboard_mouse`, identified by the keyboard device-ID constant.

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines (device identity), §8:*

- **Classify by event type first.** `InputEventKey` and `InputEventMouse*` are keyboard_mouse, and `InputEventJoypad*` is gamepad. `DEVICE_ID_KEYBOARD`/`DEVICE_ID_MOUSE` are the confirming identity. **Never** use `event.device == 0` to mean keyboard or mouse.
- **Initial state.** The game starts in `keyboard_mouse` (GDD States and Transitions). `enum DeviceKind { KEYBOARD_MOUSE, GAMEPAD }` and the `active_device` getter land here.
- **The device-0 case.** Start in `keyboard_mouse`, feed a south-button `InputEventJoypadButton` with `device = 0`, and expect `gamepad`. Then feed an `InputEventKey` and assert that its `device == InputEvent.DEVICE_ID_KEYBOARD` and the kind returns to `keyboard_mouse`.
- **The device-0 regression guard.** Also feed a key event stamped `device = 0`. It must still classify as keyboard by type, which guards against a device-0 check sneaking in.
- The `active_device_changed` emission rules are in story 012. This story asserts the `active_device` getter.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 012: `active_device_changed` emission.
- Story 014: `pad_style`.

---

## Files

- `src/input/input_resolver.gd` (device-kind classification and the `active_device` getter)
- `tests/unit/input/input_device_identity_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

**AC-13** — device 0 is a gamepad; a key restores keyboard_mouse by the keyboard device-ID constant.

```
Test: a device-0 pad sets gamepad; a key restores keyboard_mouse
Given: R (initial active_device == KEYBOARD_MOUSE)
When:  feed pad_button(device = 0, JOY_BUTTON_A, pressed), then key(KEY_ENTER)
Then:  active_device == GAMEPAD after the pad; the key event's device == InputEvent.DEVICE_ID_KEYBOARD and active_device == KEYBOARD_MOUSE after it
Edge cases:
  - a key event stamped device = 0 still classifies as keyboard (the regression guard)
  - pad_axis(device = 0) past the deadzone gives GAMEPAD
  - a mouse button whose device == DEVICE_ID_MOUSE gives KEYBOARD_MOUSE
```

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/input/input_device_identity_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/input-system/story-001-default-bindings-press-release.md`
- Unlocks: `production/epics/input-system/story-012-active-device-changed.md`
