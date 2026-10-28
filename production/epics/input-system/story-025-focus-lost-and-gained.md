# Story 025: Focus loss emits `released` before `focus_lost`, pad input is ignored while unfocused, and a key still held after `focus_gained` needs a fresh press

> **Epic**: Input System
> **Status**: Deferred (2026-10-24): controller polish, not needed for a playable build; build before release
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-28 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-004` (primary); the folded shell work also serves `TR-input-003` and `TR-input-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (§2 shell, §5 `ui_*` strip, §8, §9)
**ADR Decision Summary**: Focus loss releases every held action before `focus_lost()`, pad input is dropped while unfocused, and keys still down at focus return need a fresh press. A thin `InputSystem` node (not an autoload) is the only script touching engine input: it strips `ui_*` device bindings, forwards `_input` to the resolver without consuming events, ticks it, and maps focus notifications and `joy_connection_changed`.
**ADR Version**: ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `NOTIFICATION_APPLICATION_FOCUS_OUT/IN` is NOT SOURCEABLE and its real OS delivery is unverified on 4.7.2 (epic risk; the fallback is a window-focus poll). The spike verified `InputMap.action_erase_events()` plus `Input.parse_input_event()` driving native focus (item 2) and the `input_devices/joypads/ignore_joypad_on_unfocused_application` setting (item 3). `ui_select` as a built-in name is still open — confirm it exists on 4.7.2 before the strip list relies on it.

**Control Manifest Rules (this layer)**:
- Required: "**`device_lost()`/`focus_lost()` fire only after every held action's `action_released`**"
- Required: "**`get_move_vector()` returns `Vector2.ZERO` while the window is unfocused**"
- Required: "**`project.godot` sets `input_devices/joypads/ignore_joypad_on_unfocused_application = true`**"
- Required: "**Built-in `ui_*` navigation actions have their device bindings erased in `InputSystem._enter_tree()`**, before any `Control` can grab focus"
- Forbidden: "**No script other than `InputSystem` may override `_input`/`_unhandled_input` to read gameplay keys, or poll `Input.is_action_*`**"

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [ ] **AC-17** Focus is lost while an action is held: `released` is emitted, then `focus_lost`. Pad input while unfocused emits nothing. After `focus_gained`, a key still physically held emits nothing until it is pressed again.
- [ ] **T-SHELL** (folded, ADR-0003 §2, §5, §9, Migration Plan step 2 items 2–3; no GDD AC): the `InputSystem` shell strips the `ui_*` device bindings, forwards events without consuming them, ignores `InputEventAction`, and maps focus notifications and joypad connections onto the resolver.

---

## Implementation Notes

*Derived from ADR-0003 §2, §5, §8, §9:*

- **`set_window_focused(false)`.** Release every held action, emitting `action_released` for each. Then emit `focus_lost()`. While unfocused, drop every `InputEventJoypad*`. `get_move_vector()` returns `Vector2.ZERO`.
- **`set_window_focused(true)`.** Emit `focus_gained()` (exactly once). A key still physically down produces only echo events (ignored, story 002) and its release, which must emit nothing because the action is not held. It counts again only on a fresh non-echo press.
- **Axes after focus return.** "Every axis must return inside the deadzone before it counts". Set a per-axis re-centre latch on focus loss and clear it when that axis reads inside the deadzone. A stick held through focus return gives `Vector2.ZERO` and no menu step until re-centred.
- **Keyboard while unfocused (documented reading).** The AC does not say whether keyboard input is dropped while unfocused. The OS normally doesn't deliver it, so treat any received key as normal input.
- **Move vector sign convention (pinned).** `move_right` → (+1, 0), `move_up` → (0, −1) (y-down). *Ruling 2026-10-23, to be recorded in ADR-0003 §8 by technical-director; ADR-0012 owner to confirm.*
- **Folded work, T-SHELL.** `InputSystem` (`extends Node`, `process_mode = PROCESS_MODE_ALWAYS`, a child of `GameRoot/Services`, not an autoload):
  - **`setup(resolver: InputResolver) -> void` is the injection seam (pinned).** Game-state-scene-flow's boot story calls it from `GameRoot._ready()`; that story needs a cross-reference to this seam;
  - `_enter_tree()` calls `InputMap.action_erase_events()` on `ui_accept`, `ui_select`, `ui_cancel`, `ui_up`, `ui_down`, `ui_left`, `ui_right`, `ui_focus_next`, `ui_focus_prev`, `ui_page_up`, `ui_page_down`, `ui_home`, `ui_end`, keeping `ui_text_*`;
  - `_input(event)` forwards to `feed_event`, skips `InputEventAction`, and never calls `set_input_as_handled()`;
  - `_process(delta)` calls `tick(delta)`;
  - `_notification()` maps `NOTIFICATION_APPLICATION_FOCUS_OUT/IN` to `set_window_focused()`;
  - `Input.joy_connection_changed` connects to a handler `_on_joy_connection_changed(device, connected)` that calls `on_joy_connection(device, connected, Input.get_joy_name(device))`;
  - `project.godot` sets `input_devices/joypads/ignore_joypad_on_unfocused_application = true`.
- **T-SHELL integration test.** It calls `setup(R)`, `node._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)` / `_IN` and `_on_joy_connection_changed(...)` directly, so the mapping is automated; only real OS delivery is manual. It must restore `InputMap` in teardown (`InputMap.load_from_project_settings()`) and `auto_free` the node.
- **Manual verification (deferred, logged in `production/qa/evidence/`).** Real `NOTIFICATION_APPLICATION_FOCUS_OUT/IN` delivery on a 4.7.2 build (alt-tab with a pad held) is checked by hand and logged in `production/qa/evidence/`. It is not part of this story's automated done gate. If it fails, the window-focus poll fallback in the shell (`DisplayServer.window_is_focused()` per `_process`, NOT SOURCEABLE; verify) is a follow-up, recorded in the Completion Notes.
- **Not in this story.** Constructing `InputSystem` under `GameRoot`, calling `setup()` and binding the resolver is `production/epics/game-state-scene-flow/` (ADR-0003 Migration step 4).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `production/epics/game-state-scene-flow/`: `GameRoot` construction, `setup()` call, `bind_action_source()`, the fallback on `FAILED`.
- Story 024: `device_restored` semantics (the shell only forwards).
- Story 021 / UI Framework epic: `ui_*` re-injection.

---

## Files

- `src/input/input_resolver.gd` (focus gate, re-press latch, per-axis re-centre latches)
- `src/input/input_system.gd` (`InputSystem` node: the shell, folded; `setup(resolver)` seam)
- `project.godot` (`input_devices/joypads/ignore_joypad_on_unfocused_application = true`)
- `tests/unit/input/input_focus_test.gd`
- `tests/integration/input/input_system_shell_test.gd` (folded T-SHELL)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, fixes applied: `InputSystem.setup(resolver)` seam, direct `_notification` and joy-handler calls in T-SHELL, OS delivery deferred). The developer implements against these — do not invent new test cases during implementation.*

**AC-17** — focus loss, unfocused pad input, and a fresh press after focus return.

```
Test: focus loss releases every held action before focus_lost
Given: R; Enter and Shift held, and the stick raw (1, 0) on pad 0
When:  set_window_focused(false)
Then:  rec.since(mark) == [released(confirm), released(fast_forward), focus_lost()] (the releases in any order, both before focus_lost); get_move_vector() == ZERO
Edge cases: none
```

```
Test: pad input while unfocused emits nothing
Given: R unfocused; mark
When:  pad south press and release, left_x at raw 1.0, then tick through repeat_delay
Then:  rec.since(mark) has no entries (no action, nav, held or active_device_changed); get_move_vector() == ZERO
Edge cases:
  - keyboard input while unfocused is processed normally (documented reading)
```

```
Test: a key still held after focus return needs a fresh press
Given: R; Enter held; set_window_focused(false); set_window_focused(true); mark
When:  feed 3 Enter echo events, tick(DT) ×3, feed the Enter release, then a fresh Enter press
Then:  rec.since(mark) == [pressed(confirm)], appearing only at the fresh press, with no held or released before it
Edge cases:
  - the pad south button held through the cycle: its release emits nothing, and a fresh press emits pressed
  - stick re-centre latch: left_x held at raw 1.0 through focus return gives ZERO and no nav until a value inside the deadzone is fed, then raw 1.0 counts again
  - focus_gained is emitted exactly once
```

**T-SHELL** — the shell wiring (integration).

```
Test (integration, tests/integration/input/input_system_shell_test.gd): the shell wiring
Given: an InputSystem node (auto_free), with setup(R) and R's recorder; teardown calls InputMap.load_from_project_settings()
When:  the node enters the tree; feed an InputEventAction(&"ui_accept") into _input; call _notification(FOCUS_OUT/IN); call _on_joy_connection_changed(0, true)
Then:
  - ui_accept, ui_select, ui_cancel, ui_up, ui_down, ui_left, ui_right, ui_focus_next, ui_focus_prev, ui_page_up, ui_page_down, ui_home and ui_end have 0 events, and ui_text_backspace keeps its events
  - ProjectSettings "input_devices/joypads/ignore_joypad_on_unfocused_application" == true
  - the InputEventAction produces no resolver signal
  - focus_lost then focus_gained are recorded
  - device_restored is recorded
Edge cases:
  - _input never calls set_input_as_handled: an InputEventKey forwarded through the shell is still unhandled (viewport check)
  - process_mode == PROCESS_MODE_ALWAYS
DEFERRED: real NOTIFICATION_APPLICATION_FOCUS_OUT/IN delivery on 4.7.2 (alt-tab with a pad held), logged to production/qa/evidence/; on failure the window-focus poll fallback is a follow-up
```

**Manual verification (deferred, logged in `production/qa/evidence/`):**
- Setup: a 4.7.2 build with a pad connected; hold pad south (or Shift) in a screen that shows held state.
- Verify: alt-tab away and back; observe `released` then `focus_lost` on leaving, no pad input while away, `focus_gained` on return, and that the still-held key needs a fresh press.
- Pass condition: the observed order matches AC-17; log the result (and, on failure, the poll-fallback follow-up) in `production/qa/evidence/`.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic (plus a folded integration test)
**Required evidence**:
- Logic: `tests/unit/input/input_focus_test.gd` — must exist and pass. Gate level: BLOCKING.
- Integration: `tests/integration/input/input_system_shell_test.gd` — must exist and pass. Gate level: BLOCKING.
- Manual (deferred, not part of the done gate): focus-notification delivery log in `production/qa/evidence/`.

**Status**: [x] Created and passing (2026-10-28: input_focus_test.gd + input_system_shell_test.gd, 16 cases; full suite 407/407, exit 0). Manual focus-delivery check still DEFERRED.

---

## Dependencies

- Depends on:
  - `production/epics/input-system/story-001-default-bindings-press-release.md`
  - `production/epics/input-system/story-002-one-pressed-per-press-no-echo.md`
  - `production/epics/input-system/story-005-radial-deadzone.md`
  - `production/epics/input-system/story-022-active-pad-lost.md`
- Unlocks: None in this epic (the game-state-scene-flow boot story consumes the `setup(resolver)` seam)

---

## Completion Notes

*2026-10-28, implementation (autonomous run).*

- **Files**: the focus gate, re-press latch and per-axis re-centre latches in `src/input/input_resolver.gd`; `src/input/input_system.gd` (`InputSystem` shell node with the `setup(resolver)` seam, `PROCESS_MODE_ALWAYS`, `ui_*` device bindings stripped in `_enter_tree()`, events forwarded unconsumed); `project.godot` (`input_devices/joypads/ignore_joypad_on_unfocused_application=true`); `tests/unit/input/input_focus_test.gd`; `tests/integration/input/input_system_shell_test.gd`.
- **Tests**: 16 new cases; full suite 407/407, exit 0.
- **Not yet done**: the manual check that real `NOTIFICATION_APPLICATION_FOCUS_OUT/IN` events arrive on a 4.7.2 build (alt-tab with a pad held) is still owed, with its log in `production/qa/evidence/`. If they don't arrive, the `DisplayServer.window_is_focused()` poll fallback becomes a follow-up.
- **Wiring owed to game-state-scene-flow 035**: `GameRoot` must construct this node under `Services` and call `setup(resolver)`.
