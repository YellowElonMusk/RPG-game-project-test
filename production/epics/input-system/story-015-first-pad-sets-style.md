# Story 015: With two pads, the first pad's input sets `pad_style` and the second pad's input fires nothing

> **Epic**: Input System
> **Status**: Complete (2026-10-30)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (§8: "The first pad to send meaningful input becomes the active pad")
**ADR Decision Summary**: With several pads connected, the first pad to send meaningful input becomes the active pad and sets `pad_style`; later input from another pad still emits its actions but is a second input of the same kind and fires no `active_device_changed`.
**ADR Version**: ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Multi-pad device IDs under SDL3 (4.5+) are unverified on hardware; the synthetic test uses devices 0 and 1.

**Control Manifest Rules (this layer)**:
- Required: "**`InputResolver` (`RefCounted`) owns the binding table, held set, move vector and device state, with no scene-tree dependency.**"
- Required: "**Bindings are a catalog record** (`bindings_` prefix); **tuning values** (... pad-style patterns) are a project config (`InputConfig`)"
- Forbidden: "**Never use `event.device == 0` to mean mouse/keyboard**"

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [ ] **AC-26** With two pads connected, pad A (`xbox`) then pad B (`playstation`) send meaningful input: exactly one `active_device_changed(gamepad, xbox)` fires, and `pad_style` does not change on pad B's input (the first pad to send input sets the style; a second input of the same kind fires nothing, AC-11).

---

## Implementation Notes

*Derived from ADR-0003 §8:*

- **Setup.** Connect pad A (device 0, `"Xbox Series X Controller"`) and pad B (device 1, `"DualSense Wireless Controller"`) through `on_joy_connection`. Then feed a south press on A, and then on B.
- **Assertions.** Assert the recorder holds exactly one `active_device_changed` with args `(GAMEPAD, &"xbox")`, and that `pad_style == &"xbox"` after B's input.
- **Active pad.** The active pad stays A until the kind switches to keyboard_mouse and back. B's input still emits its actions (GDD rule 10: "Any connected gamepad controls the game"), but it does not become the active pad. This matters for story 022, where only the active pad's disconnect emits `device_lost`. Assert that B's `pressed(confirm)` is emitted (two `pressed(confirm)` in total, per the AC-19/AC-27 ruling).
- **Re-election (pinned, recommended reading adopted at QL-STORY-READY 2026-10-23).** The ADR does not say whether a switch back to gamepad through pad B re-elects B. The GDD says "the first pad to send meaningful input becomes the active one". The pinned reading is **per switch**: after a keyboard_mouse interval, the first pad to send meaningful input becomes the active pad again and sets `pad_style` (so pad B then emits `(GAMEPAD, &"playstation")`). *GDD owner to confirm;* record the reading in the Completion Notes. Story 023 relies on it.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 014: the name → style mapping.
- Stories 022, 023: active vs non-active pad disconnects.

---

## Files

- `src/input/input_resolver.gd` (active-pad election)
- `tests/unit/input/input_pad_style_test.gd` (shared with story 014)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE; re-election reading pinned). The developer implements against these — do not invent new test cases during implementation.*

**AC-26** — the first pad sets the style; the second pad fires no device change.

```
Test: the first pad sets the style; the second fires no device change
Given: R; on_joy_connection(0, true, "Xbox Series X Controller"); on_joy_connection(1, true, "DualSense Wireless Controller")
When:  pad south on device 0, then pad south on device 1
Then:  rec has exactly one active_device_changed, with args (GAMEPAD, &"xbox"); pad_style == &"xbox" after device 1's press; two pressed(confirm) (per the ruling)
Edge cases:
  - device 1's stick past the deadzone also fires nothing
  - recommended reading, if adopted: after a key press, pad 1 sending input becomes active and emits (GAMEPAD, &"playstation")
```

The re-election edge case is asserted: the per-switch reading is pinned in this story.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/input/input_pad_style_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (2026-10-30; tests/unit/input 240/240, single-dir run, tag sin3)

---

## Dependencies

- Depends on:
  - `production/epics/input-system/story-013-no-device-change.md`
  - `production/epics/input-system/story-014-pad-style-from-joy-name.md`
- Unlocks: `production/epics/input-system/story-023-non-active-pad-lost.md`

## Completion Notes

*2026-10-30, implementation (autonomous run, tag sin3).*

- **Files**: `src/input/input_resolver.gd` (`_note_meaningful()`: the first pad after a switch to gamepad becomes the active pad and sets the style; a switch to keyboard_mouse clears the active pad and keeps `pad_style`); `tests/unit/input/input_pad_style_test.gd` (story 015 section).
- **Tests**: one active_device_changed(GAMEPAD, xbox) for pads A then B, style stays xbox, two pressed(confirm); B's stick fires nothing; per-switch re-election after a key press gives (GAMEPAD, playstation) and active_pad 1.
- **Reading recorded**: per-switch re-election (pinned at QL-STORY-READY). The GDD owner still needs to confirm it. Clearing the active pad on the switch to keyboard_mouse also means a pad disconnect while keyboard_mouse is active emits no device_lost (story 022).
