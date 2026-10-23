# Epic: Input System

> **Layer**: Foundation
> **GDD**: design/gdd/input-system.md
> **Architecture Module**: Input System (`InputResolver`, the `bindings_` record, the device tracker)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories input-system`

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

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/input-system.md verified (the [VS] remap criteria excepted)
- Logic and Integration stories have passing tests in the test root
- A manual pad check on Xbox, PlayStation, Nintendo and Steam Deck hardware is logged for the named `pad_style` values (verification item)
