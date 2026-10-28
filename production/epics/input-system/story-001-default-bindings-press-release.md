# Story 001: Every default binding, keyboard and gamepad, emits `pressed` on press and `released` on release

> **Epic**: Input System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-28 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-001`, `TR-input-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (§1, §3, §4, §8)
**ADR Decision Summary**: A pure `InputResolver` (`RefCounted`) owns its own binding table, compiled once from the validated `bindings_default` catalog record (`"action:device:input"` triples). Keyboard matches on `physical_keycode`, pads on positional `JoyButton`/`JoyAxis`; Godot's `InputMap` is never used for gameplay actions.
**ADR Version**: ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: The `physical_keycode` / `OS.find_keycode_from_string()` token resolution is NOT SOURCEABLE in the engine reference. SDL3 positional `JoyButton` mapping (`JOY_BUTTON_A` = south) is relied on. Verified on 4.7.2 headless (2026-10-21, spike item 1): synthetic `InputEventKey`, `InputEventJoypadButton` (`device = 0`), `InputEventJoypadMotion` and `InputEventMouseButton` construct and feed into a `RefCounted`; `InputEventKey.new()` defaults `device` to `DEVICE_ID_KEYBOARD` (16) and `InputEventMouseButton.new()` to `DEVICE_ID_MOUSE` (32).

**Control Manifest Rules (this layer)**:
- Required: "**`InputResolver` (`RefCounted`) owns the binding table, held set, move vector and device state, with no scene-tree dependency.** Driven only through `feed_event()`, `tick()`, `set_window_focused()` and `on_joy_connection()`"
- Required: "**The binding table is the resolver's own dictionary, matched by `physical_keycode` / `JoyButton` / `JoyAxis` / `MouseButton`**, never `InputMap`"
- Required: "**Bindings are a catalog record** (`bindings_` prefix); **tuning values** (deadzone, repeat timing, `pointer_switch_px`, pad-style patterns) are a project config (`InputConfig`), not a catalog record"
- Forbidden: "**Never use Godot's `InputMap`/`Input` singleton for gameplay actions**"
- Guardrail: "**Input**: one dictionary lookup per device event, negligible per `tick`; the binding table compiles once at boot in microseconds"

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [ ] **AC-1** Parametrized over every default binding (all 8 actions, keyboard and gamepad): press emits `pressed` for that action, release emits `released`.

**Pinned reading (QL-STORY-READY, 2026-10-23):** For each of the 7 discrete actions (`confirm`, `cancel`, `menu`, `inspect`, `page_left`, `page_right`, `fast_forward`), each default triple's press emits exactly one `action_pressed(action)` and its release exactly one `action_released(action)`. For each `move_*` triple, the press makes `get_move_vector()` equal that direction's unit vector (sign convention below, within 1e-6), the release returns it to `Vector2.ZERO`, and no `action_pressed`/`action_released` with a `move_*` name is ever emitted. (`nav_*` may be emitted. That is story 018's concern and is not asserted here.)

---

## Implementation Notes

*Derived from ADR-0003 §1, §3, §4, §8 and Key Interfaces:*

- **Resolver shape.** `InputResolver` must extend `RefCounted` and must never call `Input`, `InputMap`, `get_tree()`, `Time` or `Engine`, or reference an autoload. Events, time, focus and joypad connections enter only through `feed_event(event)`, `tick(delta)`, `set_window_focused(focused)` and `on_joy_connection(device, connected, joy_name)`. Declare every signal from Key Interfaces now, including `action_held`, `focus_*`, `device_*`, `active_device_changed`, `pointer_*`, `wheel_step` and `binding_override_discarded`, so later stories add behaviour, not surface. The constructor is `_init(bindings: InputBindings, config: InputConfig)`. It satisfies ADR-0002's `ActionSource` directly (`action_pressed`, `action_released`, `focus_lost`, `device_lost`, `get_move_vector()`), with no adapter.
- **Record class.** The record class is `InputBindings` (`class_name InputBindings`) at `src/data/records/input_bindings.gd`, as ADR-0003 Key Interfaces declares (ruling 2026-10-23). Create it here only if content-catalog story 002 has not; content-catalog story 002 still plans `input_bindings_data.gd` and must be edited to match.
- **Binding table.** The binding table is the resolver's own dictionary, compiled once in `_init` from `bindings.bindings` (`PackedStringArray` of `"action:device:input"` triples):
  - keyboard is matched by **`physical_keycode`** (never `keycode`), with key tokens resolved through `OS.find_keycode_from_string()`;
  - gamepad buttons are matched by `JoyButton`, through a fixed positional token vocabulary in code: `south`, `east`, `west`, `north`, `start`, `back`, `left_shoulder`, `right_shoulder`, `dpad_*`;
  - axes are matched by `JoyAxis` (`left_x±`, `left_y±`);
  - mouse buttons are matched by `MouseButton`.

  The token→engine mapping is engine glue, not tuning. Never use `InputMap`.
- **Default bindings file.** `bindings_default.tres` encodes GDD rule 1 exactly:
  - `confirm`: Enter, Space, Z / south;
  - `cancel`: Esc, Backspace, X / east;
  - `menu`: Tab, M / start;
  - `inspect`: I, Q / north;
  - `page_left` / `page_right`: 1 / 3 and left/right shoulder;
  - `fast_forward`: Shift / west;
  - `move_up/down/left/right`: WASD, arrows, d-pad and `left_x±`/`left_y±`.

  Mouse never appears in the record.
- **Discrete actions only.** `move_*` are binding-side sub-actions, never emitted as discrete actions (ADR-0003 §8). The AC's "all 8 actions" for `move` is asserted through `get_move_vector()` becoming that direction's unit vector and then zero again, per the pinned reading above.
- **Move vector sign convention (pinned).** `move_right` → (+1, 0), `move_left` → (−1, 0), `move_up` → (0, −1), `move_down` → (0, +1). This is Godot's y-down convention, the same as raw `JOY_AXIS_LEFT_Y` (negative = up) and `Input.get_vector`. *Ruling 2026-10-23, to be recorded in ADR-0003 §8 by technical-director; ADR-0012 owner to confirm.*
- **Axis press and release (for the binding test).** Press = `pad_axis(0, axis, ±1.0)`, release = `pad_axis(0, axis, 0.0)`.
- **Edges only in this story.** `action_pressed(action)` fires on edges. Keep the per-action held set keyed by (action → set of source keys) from the start, because stories 008 and 016 rely on it. Action names come only from `InputActions` constants. There are no string literals outside that file and the bindings data.
- **Tests build the record in code.** Build an `InputBindings` record in the test from the `bindings_default.tres` triples, loaded with `CACHE_MODE_IGNORE`. Never go through the `ContentCatalog` autoload. ADR-0003 Risks: "the resolver is built from a record constructed in the tests". Parametrize with gdUnit4 `test_parameters` over every triple.
- **Literal event fixture (no circular test).** `tests/unit/input/fixtures/default_binding_events.gd` holds a constant table mapping each default triple to a **hand-written engine literal**, for example `"confirm:key:Enter" → KEY_ENTER`, `"confirm:pad:south" → JOY_BUTTON_A`, `"move_up:pad_axis:left_y-" → [JOY_AXIS_LEFT_Y, -1.0]`. Test events are built **from these literals, never from the token parser**, so a token that resolves to `KEY_NONE` fails the test. The table's row count must equal the record's triple count, which catches a triple that was added to the data with no test row.
- **`InputConfig` defaults.** Declared defaults equal the GDD: `deadzone` 0.20, `repeat_delay` 0.40, `repeat_interval` 0.08, `menu_stick_threshold` 0.60, `pointer_switch_px` 8, plus `pad_style_patterns`. `data/config/input_config.tres` holds the same values. It is a project config, not a catalog record.
- **Shared test support.** `tests/unit/input/input_test_support.gd` provides, for every later story:
  - a signal recorder `rec` (ordered `[signal, args]` log connected to every resolver signal; `rec.since(mark)` returns the entries after a mark);
  - event factories `key(physical_keycode, pressed, echo)`, `pad_button(device, JoyButton, pressed)`, `pad_axis(device, JoyAxis, value)`, `mouse_button(...)`, `mouse_motion(relative)`;
  - `make_config(overrides: Dictionary) -> InputConfig`;
  - `default_bindings()` (the record from `bindings_default.tres`, `CACHE_MODE_IGNORE`);
  - constants `DEFAULT` = `InputConfig.new()`; `NON_DEFAULT` = `make_config({deadzone = 0.25, repeat_delay = 0.30, repeat_interval = 0.07, menu_stick_threshold = 0.50, pointer_switch_px = 12})` (every value inside the GDD's Tuning Knob range; every "runs once with a non-default config" clause in this epic means this constant — declare it once, never pick values per test); `EPS_V` = 1e-6; `EPS_T` = 1e-9 s; `DT` = 1.0 / 60.0 (expected tick indices are computed as integers n with `n * DT`, never as running float sums).
- **Spike item 1 regression.** `tests/unit/input/input_synthetic_events_test.gd` pins the synthetic-event defaults listed under Engine Notes (ADR-0003 Migration Plan step 2, item 1).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `held` per tick, echo suppression.
- Story 003: bindings validation and the fallback bindings.
- Stories 004–006: move vector magnitude, deadzone, per-axis arbitration.
- Story 018: `nav_*` menu steps.
- Story 025: the `InputSystem` shell node.

---

## Files

- `src/input/input_actions.gd` (`class_name InputActions`, `StringName` constants)
- `src/input/input_resolver.gd` (`class_name InputResolver extends RefCounted`: skeleton, binding-table compile, `feed_event`, `tick`, edge signals)
- `src/input/input_config.gd` (`class_name InputConfig extends Resource`)
- `data/config/input_config.tres`
- `data/bindings/bindings_default.tres` (the GDD rule 1 table as triples)
- `src/data/records/input_bindings.gd` (`class_name InputBindings`), only if content-catalog story 002 has not created it
- `tests/unit/input/input_test_support.gd`
- `tests/unit/input/fixtures/default_binding_events.gd`
- `tests/unit/input/input_default_bindings_test.gd`
- `tests/unit/input/input_synthetic_events_test.gd` (spike item 1 regression)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, fixes applied: pinned `move` reading, axis press/release, literal event fixture, sign convention). The developer implements against these — do not invent new test cases during implementation.*

**AC-1** — every default binding emits `pressed` on press and `released` on release.

```
Test: every default discrete binding emits one pressed and one released
Given: R built from the default bindings with DEFAULT, and rec attached
When:  for each discrete-action triple (parametrized), feed its press event, then its release event
Then:  rec holds exactly [action_pressed(a), action_released(a)] for that triple's action a, and nothing else with a discrete-action name
Edge cases:
  - every keyboard triple uses physical_keycode, and keycode is left at KEY_NONE, so matching on keycode fails
  - each JoyButton triple is fed with device = 0 and again with device = 1
  - the row count of default_binding_events equals bindings.size()
```

```
Test: every default move binding drives the vector, never a discrete action
Given: R with DEFAULT
When:  for each move_* triple (keys, d-pad, left_x±, left_y±), feed its press, read get_move_vector(), then feed its release
Then:  the vector equals the direction's unit vector within EPS_V after the press and Vector2.ZERO after the release; rec has no action_pressed or action_released whose name starts with "move_"
Edge cases:
  - axis triples at raw ±1.0 give exactly ±1 after the rescale
  - run once with NON_DEFAULT (the deadzone has no effect at raw 1.0)
```

```
Test: synthetic event defaults (spike item 1 regression)
Given: none
When:  construct InputEventKey.new() and InputEventMouseButton.new()
Then:  device == InputEvent.DEVICE_ID_KEYBOARD (16) and InputEvent.DEVICE_ID_MOUSE (32) respectively, and an InputEventJoypadButton with device = 0 feeds into R without error
Edge cases: none
```

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/input/input_default_bindings_test.gd` and `tests/unit/input/input_synthetic_events_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (2026-10-28: 57 input tests; full suite 375/375, exit 0)

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-001-install-gdunit4.md` (gdUnit4 and `tests/unit/`); `production/epics/content-catalog/story-002-load-one-of-each-type.md` (the `bindings` record type, `&"bindings"`/`bindings_`/`bindings` in the type table, and the record script)
- Unlocks (and, through them, every later input story):
  - `production/epics/input-system/story-002-one-pressed-per-press-no-echo.md`
  - `production/epics/input-system/story-003-bindings-validation.md`
  - `production/epics/input-system/story-004-digital-move-magnitude.md`
  - `production/epics/input-system/story-007-same-frame-order.md`
  - `production/epics/input-system/story-008-two-device-hold-release.md`
  - `production/epics/input-system/story-009-raw-pointer-events.md`
  - `production/epics/input-system/story-011-device-id-zero-pad.md`
  - `production/epics/input-system/story-025-focus-lost-and-gained.md`
  - `production/epics/input-system/story-026-invalid-override-discarded.md`

---

## Completion Notes

*2026-10-28, implementation (autonomous run).*

- **Files**: `src/input/{input_actions,input_config,input_resolver}.gd`, `data/config/input_config.tres`, `data/bindings/bindings_default.tres`, `tests/unit/input/{input_test_support,input_default_bindings_test,input_synthetic_events_test}.gd`, `tests/unit/input/fixtures/default_binding_events.gd`. `src/data/records/input_bindings.gd` already existed (content-catalog 002) and was reused unchanged.
- **Record shape**: the existing `InputBindings.bindings` is `Array[Dictionary]` of `{action, device, input}`, not the `PackedStringArray` of `"action:device:input"` strings the story text assumed. The resolver compiles from the dictionaries; test parameter keys still use the `action:device:input` spelling. Owed to technical-director: ADR-0003 Key Interfaces wording.
- **Tests**: 54 parametrized binding cases plus row-count parity (`input_default_bindings_test.gd`) and 3 synthetic-event regressions; full suite 375/375, exit 0. Remaining warning: gdUnit4 requires the parametrized argument to be named `test_parameters`, so GDScript's "unused parameter" warning on it is expected.
- **Forbidden-API audit**: `input_resolver.gd` has no `Input.`, `InputMap`, `get_tree`, `Time.` or `Engine.` references; every Key Interfaces signal is declared.
