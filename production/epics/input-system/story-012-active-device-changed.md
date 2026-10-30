# Story 012: A key-then-pad press, a stick past the deadzone, a mouse click and `pointer_switch_px` of mouse movement each emit exactly one `active_device_changed` of the right kind

> **Epic**: Input System
> **Status**: Complete (2026-10-30)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (§8); ADR-0008: UI Framework (§4, consumer: `PromptFacade` forwards kind and style)
**ADR Decision Summary**: The resolver tracks the active device kind and emits `active_device_changed(kind, pad_style)` only on a change of kind, at the meaningful input that caused it. Pointer movement counts only once its cumulative distance reaches `InputConfig.pointer_switch_px`.
**ADR Version**: ADR-0003 2026-10-21; ADR-0008 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: The SDL3 event shape for stick and trigger motion (4.5+) is post-cutoff; synthetic `InputEventJoypadMotion` is verified to construct and feed.

**Control Manifest Rules (this layer)**:
- Required: "**Bindings are a catalog record** (`bindings_` prefix); **tuning values** (deadzone, repeat timing, `pointer_switch_px`, pad-style patterns) are a project config (`InputConfig`), not a catalog record"
- Required: "**The resolver reference never leaves `GameStateMachine` and `UiService`.** Widgets (HUD prompt glyphs) reach the active device, pad style and glyphs only through `UiContext.prompts` (`PromptFacade` ...)"
- Forbidden: "**Never use `event.device == 0` to mean mouse/keyboard**"

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [x] **AC-10** Separate tests, each emitting exactly one `active_device_changed` with the expected kind: key press, then pad button (gamepad); stick past the deadzone (gamepad); mouse click (keyboard_mouse); cumulative mouse movement reaching `pointer_switch_px` (keyboard_mouse).

---

## Implementation Notes

*Derived from ADR-0003 §8:*

- **Signature.** `active_device_changed(kind: DeviceKind, pad_style: StringName)`, with `enum DeviceKind { KEYBOARD_MOUSE, GAMEPAD }`. Emit only on a **change** of kind, at the event that caused it. For keyboard_mouse, emit with the current `pad_style` unchanged (style is set in story 014). This story asserts only `kind`.
- **Meaningful inputs:** a key press; a mouse click; cumulative mouse motion reaching `config.pointer_switch_px`; a pad button press; a stick or trigger past the deadzone (after story 005's rescale gives a non-zero output).
- **Starting states (pinned).** The game starts in `keyboard_mouse`, so the gamepad cases need no setup beyond what the AC names. The two keyboard_mouse cases each start with a pad press first, then a mark, then assert exactly one emission in `rec.since(mark)`.
- **Pointer distance.** It is the sum of `|relative|` of `InputEventMouseMotion` since the last non-mouse input, compared `>= pointer_switch_px` with the value from config. Repeat with `NON_DEFAULT` (`pointer_switch_px = 12`).
- **First active pad.** The first pad to send meaningful input becomes the active pad, so record its device ID. Stories 015 and 022 use it.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 013: inputs that must not switch.
- Story 014: the `pad_style` value.
- Story 017: the pointer counter reset on a switch.

---

## Files

- `src/input/input_resolver.gd`
- `tests/unit/input/input_active_device_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

**AC-10** — each meaningful input switches the device with exactly one signal.

```
Test: each meaningful input switches the device with exactly one signal (4 separate tests)
Given: a fresh R per case, with cfg ∈ {DEFAULT, NON_DEFAULT}
When:
  (a) key Enter, then pad south;
  (b) pad_axis left_x at raw cfg.deadzone + 0.05;
  (c) pad south, mark, then mouse LEFT press;
  (d) pad south, mark, then mouse_motion events whose |relative| sums to exactly cfg.pointer_switch_px (e.g. 3 events)
Then:  (a) no signal after the key, then exactly one active_device_changed(GAMEPAD, _); (b) one (GAMEPAD, _); (c) and (d) exactly one (KEYBOARD_MOUSE, _) in rec.since(mark)
Edge cases:
  - (d): further motion after the switch emits nothing more
  - the kind is asserted only; the pad_style argument is story 014's
  - (b) with a trigger axis past the deadzone is optional (not in the AC)
```

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/input/input_active_device_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (2026-10-30)

---

## Dependencies

- Depends on:
  - `production/epics/input-system/story-005-radial-deadzone.md`
  - `production/epics/input-system/story-011-device-id-zero-pad.md`
- Unlocks:
  - `production/epics/input-system/story-013-no-device-change.md`
  - `production/epics/input-system/story-014-pad-style-from-joy-name.md`
  - `production/epics/input-system/story-016-keyboard-and-pad-same-frame.md`
  - `production/epics/input-system/story-017-pointer-distance-reset.md`
  - `production/epics/input-system/story-022-active-pad-lost.md`

## Completion Notes

*2026-10-30, implementation (autonomous run, tag sin2).*

- **Files**: `src/input/input_resolver.gd` (`_note_meaningful()` emits `active_device_changed(kind, pad_style)` once per change, at the causing event and before its action signals; meaningful inputs: key press, any mouse button press, cumulative motion >= `pointer_switch_px`, pad button press, stick (whole-stick `stick_output()` non-zero) or trigger past the deadzone; `active_pad` getter records the first pad.); `tests/unit/input/input_active_device_test.gd`; `tests/unit/input/input_test_support.gd` (Recorder filters)
- **Tests**: 7 cases, most x DEFAULT/NON_DEFAULT. Input dir 193/193 (single-dir run; full suite run by main session).
- **Deviations**: `pad_style` is `&"generic"` until story 014. Existing exact-sequence tests now filter `active_device_changed` via the new `Recorder.discrete_since()`.
