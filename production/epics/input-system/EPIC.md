# Epic: Input System

> **Layer**: Foundation
> **GDD**: design/gdd/input-system.md
> **Architecture Module**: Input System (`InputResolver`, the `bindings_` record, the device tracker)
> **Status**: Ready
> **Stories**: 26 (25 Ready, 1 Blocked on a UI Framework epic) — see the table below

## Overview

Input turns keyboard, mouse and gamepad events into the game's eight named actions,
plus the derived `nav_*` menu steps. It tracks which device the player is using, so
prompts always match. The core is a pure `InputResolver` with its own binding table
(ADR-0003), so every rule is testable headlessly with synthetic events. It knows
nothing about modes: Game State routes the actions.

**What it implements (from the GDD and ADR-0003):**
- **Actions and bindings.** `move` (as a vector), `confirm`, `cancel`, `menu`, `inspect` (a toggle), `page_left`/`page_right`, and `fast_forward` (a tap latch in replays and Dialogue; nothing is ever held). Default bindings are the validated `bindings_default` catalog record. Godot's built-in `ui_*` actions are stripped of key and pad bindings and re-injected after routing.
- **Press semantics.** Exactly one `pressed` per physical press, no OS key-repeat echoes, `held` and `released` events, a radial deadzone rescale.
- **Menu repeat.** `repeat_delay`/`repeat_interval` on an injectable clock. Steps are reported as `nav_up/down/left/right`, and during a hitch every due step fires in order. The UI re-injects each step as the matching `ui_*` action, so native focus and AccessKit see real focus changes.
- **Devices.** Active device kind and `pad_style` (`xbox`/`playstation`/`nintendo`/`generic`; the Steam Deck and the Steam Virtual Gamepad report `xbox`) through `active_device_changed`. Keyboard and mouse are identified by event type or `DEVICE_ID_*` (4.7), never device 0. The `pointer_switch_px` threshold. `device_lost`/`device_restored`/`focus_lost`/`focus_gained` broadcasts, with held actions released before loss.
- **Overrides hook only.** The player-override layer and its interface to Save/Load are in scope. Actual persistence lands with Save/Load (ADR-0009), and the remap screen and the Vertical Slice player settings (deadzone, repeat timings, Nintendo swap) are not part of this epic.

**Build order.** After `content-catalog` (it needs the `bindings_` record). It can run in
parallel with `game-state-scene-flow` Step 1, which uses a synthetic `ActionSource`.
Only the `GameRoot._ready()` wiring needs the real resolver.

**Risks.**
- **Pad names on real hardware.** Named `pad_style` detection under SDL3 needs hardware verification. The synthetic AC-12 covers the logic only.
- **Focus notification.** `NOTIFICATION_APPLICATION_FOCUS_OUT` is unverified on 4.7.2. If it fails, the fallback is a window-focus poll.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0003: Input System | Pure `InputResolver` with its own binding table; `ui_*` stripped and re-injected; `bindings_` record; SDL3 pad style | MEDIUM |
| ADR-0008: UI Framework | Pointer → focus sync (4.6 dual focus), `nav_*` re-injection into native focus | MEDIUM |
| ADR-0009: Save/Load & Settings | Player overrides persist through the settings participant (hook only in this epic) | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-input-001 | 8-action set with positional pad names; default bindings are a validated Content Data record; overrides persist via Save/Load | ADR-0003, ADR-0009 §7 ✅ |
| TR-input-002 | Radial deadzone rescale and menu-repeat timing from data, injectable clock | ADR-0003 ✅ |
| TR-input-003 | Keyboard and mouse identified by event type or `DEVICE_ID_*`, never device 0 | ADR-0003 ✅ |
| TR-input-004 | `device_lost`/`device_restored`/`focus_lost`/`focus_gained`; held actions released before lost; pad input ignored while unfocused | ADR-0003 ✅ |
| TR-input-005 | Active device kind and `active_device_changed(kind, pad_style)` under SDL3 | ADR-0003, ADR-0008 §4 ✅ |
| TR-input-006 | Devices → actions only; no modes; never depends on Game State; raw pointer to UI | ADR-0003, ADR-0008 §5–§6 ✅ |
| TR-input-007 | One `pressed` per physical press; no key-repeat echoes | ADR-0003 ✅ |
| TR-input-008 | Menu steps as derived `nav_*` actions | ADR-0003 ✅ |
| TR-input-009 | Hover moves focus only after `pointer_switch_px` | ADR-0003, ADR-0008 §6 ✅ |

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Every default binding, keyboard and gamepad, emits `pressed` on press and `released` on release](story-001-default-bindings-press-release.md) | Logic | Ready | ADR-0003 |
| 002 | [One `pressed` per physical press, `held` every tick, and no second `pressed` from OS key-repeat echoes](story-002-one-pressed-per-press-no-echo.md) | Logic | Ready | ADR-0003 |
| 003 | [Bindings validation errors on a missing keyboard or gamepad binding and a double-bound key; the valid default set reports zero](story-003-bindings-validation.md) | Logic | Ready | ADR-0003, ADR-0004 |
| 004 | [A single key or d-pad direction gives magnitude 1, and a diagonal key pair gives length 1](story-004-digital-move-magnitude.md) | Logic | Ready | ADR-0003 |
| 005 | [The radial deadzone rescale matches the `stick_output` formula](story-005-radial-deadzone.md) | Logic | Ready | ADR-0003 |
| 006 | [Opposite directions cancel on an axis, the larger stick or d-pad magnitude wins, and the d-pad wins a tie](story-006-axis-arbitration.md) | Logic | Ready | ADR-0003 |
| 007 | [`confirm` and `cancel` pressed in the same frame are both emitted, in input order](story-007-same-frame-order.md) | Logic | Ready | ADR-0003 |
| 008 | [An action held on two devices is released only once, at the second device's release](story-008-two-device-hold-release.md) | Logic | Ready | ADR-0003 |
| 009 | [Left click, right click and the wheel emit raw `pointer_confirm`, `pointer_cancel` and opposite-sign wheel steps](story-009-raw-pointer-events.md) | Logic | Ready | ADR-0003, ADR-0008 |
| 010 | [No pointer event ever produces a `move` action](story-010-no-pointer-move.md) | Logic | Ready | ADR-0003 |
| 011 | [A gamepad reporting device ID 0 makes the active device `gamepad`; a key press makes it `keyboard_mouse`](story-011-device-id-zero-pad.md) | Logic | Ready | ADR-0003 |
| 012 | [Each meaningful input emits exactly one `active_device_changed` of the right kind](story-012-active-device-changed.md) | Logic | Ready | ADR-0003, ADR-0008 |
| 013 | [No `active_device_changed` for stick drift, sub-threshold mouse movement, or a second input of the active kind](story-013-no-device-change.md) | Logic | Ready | ADR-0003 |
| 014 | [Synthetic joy names map to `xbox`, `playstation`, `nintendo`, `xbox` (Steam), and `generic` otherwise](story-014-pad-style-from-joy-name.md) | Logic | Ready | ADR-0003, ADR-0008 |
| 015 | [With two pads, the first pad's input sets `pad_style` and the second pad's input fires nothing](story-015-first-pad-sets-style.md) | Logic | Ready | ADR-0003 |
| 016 | [The same action on keyboard and pad in one frame emits two `pressed`; the later event's kind is active](story-016-keyboard-and-pad-same-frame.md) | Logic | Ready | ADR-0003 |
| 017 | [The pointer distance restarts from zero after a switch to gamepad](story-017-pointer-distance-reset.md) | Logic | Ready | ADR-0003 |
| 018 | [A held direction steps exactly at `step_time(k)` on a fixed tick, catches up in order, and stops on release](story-018-menu-repeat-timing.md) | Logic | Ready | ADR-0003 |
| 019 | [Changing the held direction mid-repeat fires one immediate step and restarts from `repeat_delay`](story-019-direction-change-restart.md) | Logic | Ready | ADR-0003 |
| 020 | [A stick just under `menu_stick_threshold` gives no menu step; just over gives one](story-020-menu-stick-threshold.md) | Logic | Ready | ADR-0003, ADR-0008 |
| 021 | [Each menu step is one `nav_*` `pressed`, re-injected by the UI as the matching `ui_*` action](story-021-nav-pressed-only-reinjection.md) | Logic | Blocked (UI Framework epic: UiNavigator, ADR-0008 §3) | ADR-0003, ADR-0008 |
| 022 | [The active pad disconnecting while `fast_forward` is held emits `released(fast_forward)` then `device_lost`](story-022-active-pad-lost.md) | Logic | Ready | ADR-0003 |
| 023 | [A non-active pad disconnecting emits no `device_lost`; its held actions release only if no other device holds them](story-023-non-active-pad-lost.md) | Logic | Ready | ADR-0003 |
| 024 | [A pad reconnecting emits `device_restored`, also while unfocused](story-024-device-restored.md) | Logic | Ready | ADR-0003 |
| 025 | [Focus loss releases before `focus_lost`, pad input is ignored while unfocused, held keys need a fresh press (+ `InputSystem` shell)](story-025-focus-lost-and-gained.md) | Logic (+ integration) | Ready | ADR-0003 |
| 026 | [An invalid player override is discarded, defaults stay active, one notice fires; the next load fires none](story-026-invalid-override-discarded.md) | Logic | Ready | ADR-0003, ADR-0009 |

**Not covered by a story here:**
- **AC-23** (Dialogue `fast_forward` tap latch) and **AC-24** (`inspect` toggle and hover rule text) test consumer state, not Input. They are verified by the Dialogue, Turn Battle and UI Framework epics. Input's part (one `pressed` per tap, nothing held) is proven by story 002.
- **TR-input-009** (hover moves focus only after `pointer_switch_px`) is the UI Framework's `PointerFocusSync` and is verified by the UI Framework epic (ADR-0008 §6). Input only supplies `pointer_position` (story 009).

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/input-system.md verified (the [VS] remap criteria excepted)
- Logic and Integration stories have passing tests in the test root
- A manual pad check on Xbox, PlayStation, Nintendo and Steam Deck hardware is logged for the named `pad_style` values (verification item)
