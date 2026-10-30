# Story 024: A pad reconnecting emits `device_restored`, also while unfocused

> **Epic**: Input System
> **Status**: Complete (2026-10-30)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (§8: "`device_restored()` fires for any pad reconnecting, focused or not")
**ADR Decision Summary**: Any pad connection reported through `on_joy_connection(device, true, joy_name)` emits `device_restored()`, whether or not the window is focused; while unfocused, that pad's input is still ignored.
**ADR Version**: ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: `Input.joy_connection_changed` exists on 4.7.2; `input_devices/joypads/ignore_joypad_on_unfocused_application` exists (default `false`) (spike item 3).

**Control Manifest Rules (this layer)**:
- Required: "**`InputResolver` (`RefCounted`) owns the binding table ... Driven only through `feed_event()`, `tick()`, `set_window_focused()` and `on_joy_connection()`**"
- Required: "**`project.godot` sets `input_devices/joypads/ignore_joypad_on_unfocused_application = true`**"
- Guardrail: negligible work per event.

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [ ] **AC-16** A pad reconnects: `device_restored` is emitted, including while unfocused.

---

## Implementation Notes

*Derived from ADR-0003 §8:*

- **When it fires (pinned, QL-STORY-READY 2026-10-23).** `on_joy_connection(device, true, joy_name)` emits `device_restored()` for **any** pad connection, including a non-active pad and the first connection at boot. This is the adopted reading of ADR-0003 §8's "any pad reconnecting": the receiver (Game State) only cares while its device-lost Menu is up, so an extra signal at boot is harmless. The call also stores the joy name for story 014.
- **Unfocused case.** Call `set_window_focused(false)` first. `device_restored` still fires, and that pad's input is then ignored until focus returns (story 025). The second QA test's "nothing from the press" clause needs the unfocused pad-drop gate; if story 025 has not landed, implement the minimal gate here (`set_window_focused(false)` stores the flag and `feed_event` drops `InputEventJoypad*` while it is set) and let story 025 add the releases, `focus_*` signals and latches on top.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 025: the focus gate itself and the shell wiring of `joy_connection_changed`.
- `production/epics/game-state-scene-flow/`: closing the device-lost Menu on `device_restored`.

---

## Files

- `src/input/input_resolver.gd`
- `tests/unit/input/input_device_connection_test.gd` (shared with stories 022 and 023)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE; first-connection reading recorded as decided). The developer implements against these — do not invent new test cases during implementation.*

**AC-16** — a reconnect emits `device_restored`, also while unfocused.

```
Test: a reconnect emits device_restored
Given: R; pad 0 connected, active, then disconnected; mark
When:  on_joy_connection(0, true, xbox name)
Then:  rec.since(mark) == [device_restored()]
Edge cases:
  - a non-active pad reconnecting also emits it
  - the first connection at boot emits it (adopted reading)
```

```
Test: device_restored fires while unfocused, and the pad's input is then ignored
Given: R; set_window_focused(false); mark
When:  on_joy_connection(1, true, name), then pad south on device 1
Then:  rec.since(mark) == [device_restored()], with nothing from the press
Edge cases: none
```

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/input/input_device_connection_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (2026-10-30; tests/unit/input 240/240, single-dir run, tag sin3)

---

## Dependencies

- Depends on: `production/epics/input-system/story-022-active-pad-lost.md`
- Unlocks: None

## Completion Notes

*2026-10-30, implementation (autonomous run, tag sin3).*

- **Files**: `src/input/input_resolver.gd` (connection stores the joy name and emits device_restored for any pad; the unfocused pad-drop gate already came from story 025); `tests/unit/input/input_device_connection_test.gd` (story 024 section).
- **Tests**: reconnect gives [device_restored]; boot and non-active connections also emit it; while unfocused, device_restored fires and the pad's south press emits nothing.
- **Deviations**: none.
