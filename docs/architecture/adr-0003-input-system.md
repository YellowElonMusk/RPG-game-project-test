# ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration

## Status
Accepted — amended by ADR-0008 (§4: `InputResolver` gains the read-only `get_bindings(action, device_kind) -> PackedStringArray`; `UiService`, not each overlay, grabs focus on an overlay's behalf; Accepted 2026-10-22, amendment in effect, annotation only) and ADR-0009 (§7: `InputResolver` gains a capture mode, reached only through ADR-0008's `InputCapture` facade, and `InputBindingsValidator` gains a static `validate_bindings(triples)`; Accepted 2026-10-22, amendment in effect, annotation only)

## Date
2026-10-21

## Last Verified
2026-10-21

## Decision Makers
User (autonomous mode — decisions logged in `production/session-logs/decision-log.md`), Claude (orchestrating session), reviewed by godot-specialist and technical-director (TD-ADR)

## Summary
The Input System needs a concrete Godot mechanism for turning keyboard, mouse and gamepad events into the GDD's eight actions. It also has to track the active device, respect window focus and disconnects, and keep its bindings as validated data. On top of that it must satisfy ADR-0002's `ActionSource` contract without becoming a mutable autoload. Decided: a pure `RefCounted` `InputResolver` that is fed raw `InputEvent`s and a clock by a thin `InputSystem` node under `GameRoot`. It resolves actions from its own binding table, which is compiled from a validated `bindings_` catalog record, and does not use Godot's `InputMap`. Godot's built-in `ui_*` actions are stripped of device bindings, so menus move only through routed actions, which the UI then re-injects.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Input |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH — post-LLM-cutoff version; Input changed in 4.5 (SDL3 gamepad driver), 4.6 (dual focus) and 4.7 (keyboard/mouse device IDs) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`, `modules/input.md`, `modules/ui.md` |
| **Post-Cutoff APIs Used** | `InputEvent.DEVICE_ID_KEYBOARD` / `DEVICE_ID_MOUSE` (4.7, sourced: `modules/input.md`, `breaking-changes.md`). The SDL3 gamepad backend (4.5, sourced) is relied on for positional `JoyButton` mapping. 4.6 dual focus (sourced) shapes the GUI rule. **NOT SOURCEABLE** (not in `docs/engine-reference/godot/**`, pre-cutoff by training but unverified on this pin): `Input.parse_input_event()` with an `InputEventAction` driving GUI focus and `Button` presses; `InputMap.action_erase_events()` on built-in `ui_*` actions; `Input.joy_connection_changed`; `Input.get_joy_name()` / `get_joy_info()` contents under SDL3; `NOTIFICATION_APPLICATION_FOCUS_OUT/IN`; the "ignore joypad on unfocused application" project setting (GDD Open Question 4); `OS.find_keycode_from_string()`; `InputEventKey.physical_keycode` |
| **Verification Required** | Items (1)–(3) were **empirically verified on 4.7.2.stable, headless, 2026-10-21**, in a godot-specialist spike in the session scratchpad, outside the project. (1) Synthetic `InputEventKey`, `InputEventJoypadButton` (`device = 0`), `InputEventJoypadMotion` and `InputEventMouseButton` construct and feed into a `RefCounted`. `InputEventKey.new()` defaults `device` to `DEVICE_ID_KEYBOARD` (= 16) and `InputEventMouseButton.new()` to `DEVICE_ID_MOUSE` (= 32), so test events need no manual stamping. (2) After `InputMap.action_erase_events()` on `ui_down`/`ui_accept` (0 events left; `ui_text_backspace` kept its 2), an `InputEventAction` passed to `Input.parse_input_event()` moved keyboard focus between two `Button`s, and `ui_accept` press+release fired the focused `Button`'s `pressed`. Every injected `InputEventAction` **did reach a sibling `Node._input()`**, so the resolver's "ignore `InputEventAction`" rule is load-bearing. A synthetic mouse click both pressed a `Button` and reached `_input()`, so never consuming events leaves the native mouse GUI intact. (3) The setting exists: `input_devices/joypads/ignore_joypad_on_unfocused_application` (bool, default `false`). `Input.joy_connection_changed` exists; `get_joy_name()`/`get_joy_info()` return empty with no pad, without error. **Still open:** (4) what `get_joy_name()` returns for real Xbox, PlayStation and Nintendo pads under SDL3. This needs hardware; `generic` is the safe fallback. Also not individually verified: `ui_select` as a built-in action name in 4.7 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Content Data Definitions storage format) — **Accepted**: the bindings record follows its `Resource`/`.tres`, ID and validation rules. ADR-0002 (Game State & Scene Flow) — **Accepted** 2026-10-22: defines the `ActionSource` contract this ADR satisfies, the `GameRoot`/`Services` layout Input lives in, and the ban on modes touching Input. ADR-0004 (Content Boot Ordering) — **Accepted** 2026-10-22: provides `ContentBootstrap` and `ContentCatalog.register_record_validator()`, through which the bindings validator is registered before validation runs. ADR-0003 cannot be Accepted before ADR-0002 and ADR-0004 |
| **Enables** | UI Framework work past the battle HUD (prompt glyphs, focus sync, routed-then-injected navigation); Overworld Exploration & Encounters (`move` via `GameStateMachine.get_move_vector`); Save/Load & Settings ADR (player binding overrides, Vertical Slice) |
| **Blocks** | Input System epic (all stories); Overworld Exploration & Encounters epic (one of its 3 prerequisite ADRs); any UI story that adds keyboard/gamepad menu navigation |
| **Ordering Note** | The boot-ordering change this ADR needs (catalog load moved from the autoload's `_ready()` into a composition-root `ContentBootstrap`, plus `register_record_validator()`) is its own decision in ADR-0004, which amends ADR-0001 and ADR-0002. This ADR only adds one line to `ContentBootstrap`'s registration list (§6) |

## Context

### Problem Statement
`design/gdd/input-system.md` specifies *what* Input does: eight actions (seven names plus the `move` vector), positional gamepad naming, a radial deadzone, menu repeat timing, active-device tracking with pad style, focus and disconnect behavior, data-driven validated bindings, and no knowledge of modes. ADR-0002 has since fixed the consumer side: Game State is the only consumer of discrete actions and movement, through an `ActionSource` contract (`action_pressed`, `action_released`, `focus_lost`, `device_lost`, `get_move_vector()`). This ADR has to decide:

1. **Where events are captured and resolved**: Godot's `InputMap` plus the `Input` singleton, or the project's own resolver.
2. **Where the bindings live and how they are validated** so that a bad bindings file stops the game at boot (GDD Edge Cases, Content Data rule 8).
3. **How Godot's own GUI keyboard navigation coexists with routing.** Native `Control` focus navigation reads the built-in `ui_*` actions directly from devices, which would bypass Game State's input lock.
4. **What the concrete API is.** `architecture.md` lists a proposed surface for this ADR to confirm or change.

### Constraints
- **Registry stances (ADR-0002, Accepted):** `mutable_autoload_singleton` is forbidden; `mode_direct_input_access` is forbidden; the `action_source` contract is registered. **ADR-0001:** bindings are a catalog record, so they hold IDs and plain values only, never `Resource` references.
- **GDD rule 2:** Input has no dependency on Game State, and never decides whether an action is used.
- **GDD Acceptance Criteria harness:** synthetic device events (including a gamepad that reports device ID 0), an injectable clock with a fixed tick, a recorder, and no consumer attached. Expected values come from the config, never literals.
- **GDD rule 11 / Godot 4.7:** keyboard and mouse are identified by `DEVICE_ID_KEYBOARD` / `DEVICE_ID_MOUSE`, never by device 0.
- **Godot 4.6 dual focus:** mouse hover focus and keyboard/gamepad focus are separate; `grab_focus()` sets only keyboard/gamepad focus (`modules/ui.md`).
- **Turn-based, menu-heavy game:** event-driven, single-threaded, no per-frame simulation (`architecture.md` Data Flow).

### Requirements
- TR-input-001: 8-action set with positional pad names; default bindings are a validated Content Data record; player overrides persist via Save/Load.
- TR-input-002: radial deadzone rescale and menu-repeat timing, all thresholds from data, with an injectable clock.
- TR-input-003: keyboard and mouse identified by event type or `InputEvent.DEVICE_ID_*`, never by device 0.
- TR-input-004: `device_lost`, `device_restored`, `focus_lost`, `focus_gained`; held actions released before "lost"; pad input ignored while unfocused.
- TR-input-005: track the active device kind and emit `active_device_changed(kind, pad_style)`; pad style detected under SDL3.
- TR-input-006: Input maps devices to actions only, knows no modes and never depends on Game State; raw pointer events go to the UI, which syncs 4.6 dual focus.
- Zero added latency: an action is reported in the same frame the device reports it (GDD Game Feel).
- Every Acceptance Criterion marked [L] runs headlessly with no scene tree.

## Decision

**1. Logic core: `InputResolver` (`RefCounted`, `src/input/input_resolver.gd`).** It owns the compiled binding table, the per-action held set, the move vector, the menu-repeat timers, the active device kind and pad style, the active pad's device ID, focus state, the per-axis "re-centre before counting" latches, and the cumulative pointer distance. It has no scene-tree dependency. It is driven through four entry points: `feed_event(event: InputEvent)`, `tick(delta: float)`, `set_window_focused(focused: bool)` and `on_joy_connection(device: int, connected: bool, joy_name: String)`. It declares every Input signal itself and **satisfies ADR-0002's `ActionSource` contract directly**, so `GameRoot` passes the resolver straight to `machine.bind_action_source()` with no adapter. All tests drive it.

**2. Shell: `InputSystem` node (`src/input/input_system.gd`), a child of `GameRoot/Services`** with `process_mode = PROCESS_MODE_ALWAYS`, so the Menu's disabled `ModeHost` never stops it. It is the only place that touches engine input:
- `_input(event)` forwards device events to `resolver.feed_event()`. It ignores `InputEventAction` (see §5) and never calls `set_input_as_handled()`, so text fields and the native mouse GUI still receive their events.
- `_process(delta)` calls `resolver.tick(delta)`.
- `_notification()` maps `NOTIFICATION_APPLICATION_FOCUS_OUT/IN` to `set_window_focused()`.
- `Input.joy_connection_changed` maps to `on_joy_connection()`, with `Input.get_joy_name(device)`.

It is not an autoload. `GameRoot` creates it and hands the **resolver** to exactly two holders: Game State (as `ActionSource`) and the UI Framework service under `Services`. Modes and overlays never get it (ADR-0002's `mode_direct_input_access`). Widgets inside modes and overlays, such as HUD button-prompt glyphs, need the active device, pad style and pointer events. The UI Framework service exposes these through a **read-only prompt/pointer facade**, and the resolver reference never leaves the service. A glyph widget reaches Input only through that facade.

**3. Own binding table, not `InputMap`.** The resolver matches events against a dictionary compiled once from the bindings record:
- keyboard by `physical_keycode`, so WASD and Z/X keep their positions on non-QWERTY layouts;
- gamepad buttons by `JoyButton`, which SDL3 maps positionally (`JOY_BUTTON_A` = south);
- stick and d-pad by `JoyAxis` and `JoyButton`;
- mouse buttons by `MouseButton`.

Godot's `Input.is_action_pressed()` and `InputMap` merge devices and can't express the GDD's rules: held until *every* device releases, the larger magnitude winning per axis with ties going to the d-pad, a fresh press required after focus returns, and only the active pad's disconnect counting. Using them would also put global engine state into every test. A remap (Vertical Slice) recompiles the table from overrides, with no engine-global mutation.

**4. Bindings are a catalog record; tuning is a project config.**
- **`InputBindings`** (`src/data/records/input_bindings.gd`, record type `bindings`, ID prefix `bindings_`, file `data/bindings/bindings_default.tres`). A single field `bindings: PackedStringArray` of `"action:device:input"` triples, for example `"confirm:key:Enter"`, `"confirm:pad:south"`, `"move_left:pad_axis:left_x-"`, `"page_left:pad:left_shoulder"`. `move` is authored as four sub-actions (`move_up/down/left/right`), which the resolver composes into the vector. Key tokens resolve through `OS.find_keycode_from_string()`. Pad tokens are a fixed positional vocabulary in code (`south`, `east`, `west`, `north`, `start`, `back`, `left_shoulder`, `right_shoulder`, `dpad_*`, `left_x±`, `left_y±`), mapping to `JoyButton`/`JoyAxis`. That mapping is engine glue, not tuning. A flat string list avoids typed-dictionary export semantics, diffs cleanly, and holds no `Resource` references (ADR-0001's forbidden pattern).
- **`InputConfig`** (`src/input/input_config.gd`, `data/config/input_config.tres`), a project config like ADR-0002's `TransitionConfig`. It holds `deadzone`, `repeat_delay`, `repeat_interval`, `menu_stick_threshold`, `pointer_switch_px`, and the pad-style name patterns (`xbox`, `playstation`, `nintendo` substrings matched case-insensitively against `get_joy_name()`). These are the GDD's tuning knobs, read by tests as well.

**5. GUI integration: routed, then re-injected.**
- **Strip.** In `InputSystem._enter_tree()`, before any `Control` can grab focus, `InputSystem` calls `InputMap.action_erase_events()` on Godot's built-in navigation actions: `ui_accept`, `ui_select` (name not individually verified on 4.7.2), `ui_cancel`, `ui_up`, `ui_down`, `ui_left`, `ui_right`, `ui_focus_next`, `ui_focus_prev`, `ui_page_up`, `ui_page_down`, `ui_home`, `ui_end`. The `ui_text_*` actions stay, so text fields keep working. Native `Control` keyboard/gamepad navigation then can't run straight from a device and bypass Game State's lock.
- **Re-inject, bounded.** A mode or overlay that receives a routed action hands it to the UI Framework's re-injection helper. The helper maps `confirm` → `ui_accept`, `cancel` → `ui_cancel`, `nav_*` → `ui_up/down/left/right` and the paging actions to `ui_page_*`, then calls `Input.parse_input_event()` under two rules:
  - (a) It injects **only if `get_viewport().gui_get_focus_owner()` is inside the receiver's own subtree**, so an injected `ui_accept` can never press a control beneath the overlay. Every overlay grabs focus inside itself when it opens, and a mode grabs focus inside itself on `mode_entered`.
  - (b) Each routed **press** injects an atomic press-then-release pair. Routed releases are **never** mirrored, so a transition that locks input between a press and its release can't leave `ui_accept` stuck down.
  
  Godot's own focus, `Button`, `ItemList` and `ScrollContainer` behavior then runs as it would natively. The resolver ignores `InputEventAction`, so a re-injected event can't loop back as a new action (verified: injected events do reach `_input()`).
- **Mouse is native, and locked by layering.** Clicks and wheel go straight to the native GUI, as GDD rule 3 intends. The lock covers the mouse too. During a transition, `TransitionLayer` (ADR-0002) shows a full-screen `Control` with `mouse_filter = MOUSE_FILTER_STOP`. Every overlay's root has a full-screen backdrop with `MOUSE_FILTER_STOP`, so clicks never reach the GUI beneath it. Game State owns when the transition blocker is up; the UI Framework owns the overlay backdrops. The UI Framework syncs 4.6 dual focus by calling `grab_focus()` on `mouse_entered`.
- **Ownership.** The re-injection helper belongs to the UI Framework. This ADR fixes the contract: `ui_*` has no device bindings, injection is focus-bounded and press-only, and the helper is the only code besides `InputSystem` allowed to call into `Input` (and only `parse_input_event()` with a `ui_*` `InputEventAction`).

**6. Bindings validation runs inside the catalog's own pass.** ADR-0004's `ContentBootstrap` registers `InputBindingsValidator.validate` with `ContentCatalog.register_record_validator(&"bindings", ...)` before `load_all()`. This is this ADR's only addition to the bootstrap's registration list. `InputBindingsValidator.validate(record) -> PackedStringArray` is a static pure function in `src/input/`, and it enforces GDD rule 7:
- every action has at least one keyboard and one gamepad binding;
- no key or button is bound to two actions on the same device;
- every token parses;
- no mouse bindings appear in the record (mouse is fixed).

A failure fails the catalog, so Boot goes to Content Error and "the game does not start".

**7. Fallback bindings for Content Error only.** If the catalog is `FAILED` (possibly because the bindings themselves are invalid), `GameRoot` configures the resolver with a code-constant fallback: `confirm` (Enter, south), `cancel` (Esc, east), `move` (arrows, d-pad). Content Error's Quit is then reachable by keyboard and pad as well as mouse. In the same way, if `data/config/input_config.tres` is missing or fails to load, `GameRoot` uses `InputConfig.new()` (its declared defaults, which equal the GDD's defaults) and logs an error. This is the only hardcoded binding set, and it is a documented exception to "gameplay values are data": it exists so a data failure can never leave the game uncontrollable. A unit test asserts that `make_fallback_bindings()` passes `InputBindingsValidator`'s token parsing and compiles into a usable table.

**8. Signals, actions and the active device.**
- `action_pressed(action)` / `action_released(action)` fire on edges. `released` fires once, at the last device's release (GDD Edge Cases).
- `action_held(action)` fires on every `tick` while held (AC-2).
- The vocabulary is fixed:
  - **`move_*` are binding-side sub-actions only.** They are never emitted as discrete actions and feed only `get_move_vector()`.
  - **`nav_up`, `nav_down`, `nav_left` and `nav_right` are four derived actions**, emitted as `action_pressed` with no `released`, at the `step_time(k)` times from `move` input. They are emitted **always**, because Input knows no modes. A receiver that doesn't navigate (Overworld walking) returns `false` from `handle_action()`.
  
  Encoding steps as actions means ADR-0002's `ActionSource` routes them under the same lock, with no contract change.
- `get_move_vector()` returns the deadzone-rescaled, per-axis-arbitrated, diagonal-normalized vector. It returns `Vector2.ZERO` while the window is unfocused.
- Pointer events go out raw: `pointer_confirm(position)`, `pointer_cancel(position)`, `wheel_step(direction: int)`, plus `pointer_position`. No pointer event ever affects `move` (AC-21).
- `active_device_changed(kind: DeviceKind, pad_style: StringName)` uses the GDD's signature.
- `device_lost()` fires only for the active pad, after its held actions are released. `device_restored()` fires for any pad reconnecting, focused or not.
- `focus_lost()` fires after every held action is released. `focus_gained()` fires on focus return. After it, a still-held key or button counts only after a fresh press, because echo events are ignored and every axis must return inside the deadzone before it counts.
- The first pad to send meaningful input becomes the active pad (GDD rule 10).

**9. Unfocused gamepads.** The resolver's own focus gate implements GDD rule 9 regardless of engine settings, which keeps AC-17 testable. `project.godot` also sets `input_devices/joypads/ignore_joypad_on_unfocused_application = true` (verified present on 4.7.2, default `false`) as belt and braces. That closes GDD Open Question 4.

### Architecture Diagram

```
 OS / SDL3 ──► Godot Viewport ──► InputSystem._input(event)  (GameRoot/Services, ALWAYS)
                     │                    │  ignores InputEventAction; never consumes
                     │                    ▼
                     │            InputResolver (RefCounted)  ◄── tick(delta) · focus · joy connect
                     │            binding table ◄── InputBindings record (catalog, validated at Boot)
                     │            tuning        ◄── InputConfig (project config)
                     │                    │
                     │      ActionSource: action_pressed/released (incl. nav_*), focus_lost,
                     │                    device_lost, get_move_vector()
                     │                    ▼
                     │            GameStateMachine (ADR-0002) ── routes, applies lock
                     │                    ▼
                     │            top overlay / mode .handle_action()
                     │                    │ re-inject (UI Framework helper)
                     │                    ▼
                     └────► Input.parse_input_event(InputEventAction ui_accept / ui_down …)
                                          ▼
                              native Control focus / Button / ItemList (ui_* have NO device events)

 Mouse clicks & wheel ──► native GUI directly (Button.pressed etc.); raw pointer_* also emitted
 Prompts ◄── active_device_changed(kind, pad_style) ── UI Framework service (holds the resolver)
```

### Key Interfaces

```gdscript
## src/input/input_actions.gd — the action vocabulary (StringName constants)
class_name InputActions
const MOVE_UP := &"move_up"        # move_* are sub-actions composing get_move_vector()
const MOVE_DOWN := &"move_down"
const MOVE_LEFT := &"move_left"
const MOVE_RIGHT := &"move_right"
const CONFIRM := &"confirm"
const CANCEL := &"cancel"
const MENU := &"menu"
const INSPECT := &"inspect"
const PAGE_LEFT := &"page_left"
const PAGE_RIGHT := &"page_right"
const FAST_FORWARD := &"fast_forward"
const NAV_UP := &"nav_up"          # nav_* are emitted steps, never bound
const NAV_DOWN := &"nav_down"
const NAV_LEFT := &"nav_left"
const NAV_RIGHT := &"nav_right"

## src/input/input_resolver.gd
class_name InputResolver extends RefCounted
enum DeviceKind { KEYBOARD_MOUSE, GAMEPAD }

# ActionSource contract (ADR-0002) — names unchanged
signal action_pressed(action: StringName)
signal action_released(action: StringName)
signal focus_lost()
signal device_lost()
func get_move_vector() -> Vector2

# Rest of the GDD surface
signal action_held(action: StringName)
signal focus_gained()
signal device_restored()
signal active_device_changed(kind: DeviceKind, pad_style: StringName)  # xbox|playstation|nintendo|generic
signal pointer_confirm(position: Vector2)
signal pointer_cancel(position: Vector2)
signal wheel_step(direction: int)                                      # +1 up, -1 down
signal binding_override_discarded(reason: String)                      # Vertical Slice (AC-22)

func _init(bindings: InputBindings, config: InputConfig) -> void
func feed_event(event: InputEvent) -> void
func tick(delta: float) -> void
func set_window_focused(focused: bool) -> void
func on_joy_connection(device: int, connected: bool, joy_name: String) -> void
func apply_overrides(overrides: PackedStringArray) -> void             # Vertical Slice; recompiles table
var active_device: DeviceKind: get
var pad_style: StringName: get
var pointer_position: Vector2: get
static func make_fallback_bindings() -> InputBindings                   # Content Error only (§7)

## src/input/input_bindings_validator.gd
class_name InputBindingsValidator
static func validate(record: InputBindings) -> PackedStringArray       # empty = valid

## src/data/records/input_bindings.gd — data only (ADR-0001)
class_name InputBindings extends Resource
@export var id: String                       # "bindings_default"
@export var bindings: PackedStringArray      # "action:device:input" triples

## src/input/input_config.gd — project config (not a catalog record)
class_name InputConfig extends Resource
@export var deadzone: float = 0.20
@export var repeat_delay: float = 0.40
@export var repeat_interval: float = 0.08
@export var menu_stick_threshold: float = 0.60
@export var pointer_switch_px: int = 8
@export var pad_style_patterns: PackedStringArray   # "xbox:xbox", "playstation:dualsense", …

## Registration added to ADR-0004's ContentBootstrap.run():
#   catalog.register_record_validator(&"bindings", InputBindingsValidator.validate)
```

### Implementation Guidelines
- `InputResolver` must extend `RefCounted` and must never call `Input`, `InputMap`, `get_tree()`, `Time` or `Engine`, and never reference an autoload. Events, time, focus and joypad connections enter only through its four entry points.
- `InputSystem` must be the only script that reads engine input (`_input`, `_unhandled_input`, `Input.*` polling) or mutates `InputMap`. No other script may override `_input`/`_unhandled_input` to read gameplay keys, or poll `Input.is_action_*`. **One named exception:** the UI Framework's re-injection helper may call `Input.parse_input_event()`, and only with an `InputEventAction` for a `ui_*` action, only when focus is inside the receiver's subtree, and only as an atomic press+release pair (§5).
- `InputSystem` must erase the §5 `ui_*` device events in `_enter_tree()`, before any `Control` can grab focus.
- Every overlay root must have a full-screen backdrop with `MOUSE_FILTER_STOP`, and `TransitionLayer` must show a `MOUSE_FILTER_STOP` blocker for the whole of a transition (*out* to *in*).
- Modes and overlays reach the active device, pad style and pointer only through the UI Framework service's read-only facade; the resolver reference never leaves `GameStateMachine` and that service.
- `InputSystem` must never call `set_input_as_handled()`, and the resolver must ignore `InputEventAction`.
- Keyboard and mouse are identified by event type and `DEVICE_ID_KEYBOARD` / `DEVICE_ID_MOUSE`. `event.device == 0` must never be used to mean keyboard or mouse (`deprecated-apis.md`).
- Keyboard bindings match on `physical_keycode`, never `keycode`. Echo events (`event.echo`) are ignored.
- Action names are `StringName` constants from `InputActions`; no string literals for action names outside that file and the bindings data.
- The built-in `ui_*` navigation actions listed in §5 must have no device events at runtime. No scene or script may add device events to them. Menu navigation must go through routed actions and re-injection.
- Every formula value (deadzone, repeat timing, thresholds, pointer distance) comes from `InputConfig`; tests compute expected values from the config, and each formula test also runs with a non-default config.
- For a disconnect or focus loss, every `action_released` must be emitted before `device_lost` / `focus_lost`.
- The fallback binding set is used only when the catalog is `FAILED`, and must never be extended into a second source of default bindings. A missing or invalid `input_config.tres` falls back to `InputConfig.new()` and logs an error.
- `project.godot` must set `input_devices/joypads/ignore_joypad_on_unfocused_application = true`.
- Tests of re-injected navigation must assert on the `Control` signal (e.g. `Button.pressed`), or await at least two frames. On 4.7.2 the `pressed` emission from an injected `ui_accept` did not flush within a single `await process_frame`.

## Alternatives Considered

### Alternative 1: Godot `InputMap` + `Input` singleton, built from data at boot
- **Description**: At boot, create one `InputMap` action per game action from the bindings record (`InputMap.add_action` / `action_add_event`). Systems then use `Input.is_action_just_pressed()`, `Input.get_vector()` and `get_action_strength()`.
- **Pros**: Idiomatic and short, with the engine's own deadzone and action strength; the native GUI can share the same actions.
- **Cons**: `Input` merges devices, so the GDD's rules for "held until every device releases", ties going to the d-pad, the fresh press after focus returns, and active-pad-only disconnects would need custom logic on top. Its built-in deadzone is per action rather than the GDD's radial deadzone with a rescale. Every test would mutate a global `InputMap` and run inside a scene tree, which the GDD's "no consumer attached" harness is designed to avoid. Polling `Input` from modes is also what ADR-0002 forbids.
- **Rejection Reason**: It can't express the GDD's rules without a resolver anyway, and once that resolver exists, `InputMap` adds only global state.

### Alternative 2: `Input` autoload wrapping the resolver
- **Description**: The same resolver, exposed as an autoload `GameInput` so any script can reach it.
- **Pros**: No plumbing through `GameRoot`.
- **Cons**: It holds mutable state (active device, held set), which the registered `mutable_autoload_singleton` forbids, and reaching Input from anywhere is exactly what `mode_direct_input_access` bans.
- **Rejection Reason**: Contradicts two registered stances and architecture Principle 4.

### Alternative 3 (GUI): keep native `ui_*` navigation bound to devices
- **Description**: Leave `ui_accept`/`ui_up`/… bound to keys and pad, and let Godot's focus system navigate menus by itself.
- **Pros**: No re-injection helper, and every `Control` works out of the box.
- **Cons**: Native navigation reads devices directly, so during a transition, or under an overlay, a key press would still move focus or press a button underneath. That breaks ADR-0002's lock (AC-8 "the mode and every overlay receive zero actions"). It would also duplicate bindings in two places, and native key repeat would replace the GDD's `step_time(k)` timing.
- **Rejection Reason**: Breaks the input lock and the data-driven repeat timing.

### Alternative 4 (GUI): a fully custom focus system
- **Description**: The UI Framework implements its own focus graph and never uses Godot's `Control` focus.
- **Rejection Reason**: Throws away native focus, `ItemList`, `ScrollContainer` and AccessKit (4.5+) integration for no gain over re-injection, which keeps all of that.

## Consequences

### Positive
- Every [L] Acceptance Criterion (AC-1 to AC-21 now, AC-22 in the Vertical Slice) runs headlessly against `InputResolver` with synthetic events and a fixed tick, with no scene tree and no global `InputMap`.
- The `ActionSource` contract is met directly, and nav steps travel under Game State's lock with no change to ADR-0002.
- Native GUI behavior (focus, buttons, lists, scrolling, and later AccessKit) is kept, while still being unable to bypass the lock.
- Bindings fail the boot exactly like any other bad content, and the fallback keeps Content Error controllable.
- The lock covers the mouse as well as keys and pad: the overlay backdrops and the transition blocker stop clicks reaching the GUI beneath.
- Remapping (Vertical Slice) is a table recompile, not an engine-state migration.

### Negative
- The project owns a few hundred lines of event-resolution logic that `Input` partly provides, including its own deadzone.
- Every UI screen needs the re-injection helper; a screen that forgets it has no keyboard/gamepad navigation (visible immediately, but still a trap).
- `ui_*` stripping is project-global; a third-party addon that expects device-bound `ui_*` actions would lose keyboard navigation.
- A forgotten `MOUSE_FILTER_STOP` backdrop on a new overlay reopens the mouse hole under it; the Validation Criteria test catches it only for the overlays it covers.
- The fallback is a hardcoded binding set: a narrow, documented exception to data-driven values.

## Risks
- **`parse_input_event` re-injection** was verified on 4.7.2 (focus moves and `Button` presses with the device events erased), but the `pressed` emission lags a frame. *Mitigation*: tests assert on signals or await two frames (Implementation Guidelines). If a later engine patch changes the behavior, the UI Framework's helper can call focus APIs directly, a change contained in one place.
- **SDL3 pad names may not reveal the style**, so prompts could show generic glyphs. *Mitigation*: `generic` positional glyphs are always correct, and the patterns are data (`InputConfig.pad_style_patterns`), tunable without code.
- **4.6 dual focus**: hover focus and keyboard/gamepad focus can drift apart. *Mitigation*: the UI Framework syncs them on `mouse_entered` (GDD rule 3); this ADR keeps the mouse native so that sync is the only rule needed.
- **Physical keycodes vs prompts**: binding by position means a prompt has to show the user's own layout label, and a synthetic `InputEventKey` carries `key_label`/`keycode` of 0 (observed on 4.7.2). *Mitigation*: a UI Framework concern. A candidate API is `DisplayServer.keyboard_get_label_from_physical()`, which is NOT SOURCEABLE in the engine reference; flagged for that ADR to verify.
- **The bindings validator depends on ADR-0004 being Accepted and implemented.** *Mitigation*: until ContentCatalog exists, `InputBindingsValidator` is unit-tested on its own, and the resolver is built from a record constructed in the tests.
- **Text entry (Vertical Slice: remap capture, possible naming)**: typing letters also produces actions (`Z` → `confirm`). *Mitigation*: no MVP text entry; the remap screen's capture mode is designed in the Save/Load & Settings or UI Framework ADR.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| input-system.md | Rule 1 / TR-input-001 — 8 actions, positional pad names, data defaults | `InputActions` vocabulary; `InputBindings` record with positional pad tokens; SDL3 positional `JoyButton` mapping |
| input-system.md | Rule 2 / TR-input-006 — device → action only, no mode knowledge | `InputResolver` has no Game State reference; Game State consumes it as `ActionSource` |
| input-system.md | Rule 3 — mouse raw events, UI decides; no click-to-move; focus sync | Mouse left native; raw `pointer_*` signals; AC-21 guard; dual-focus sync assigned to UI Framework |
| input-system.md | Rule 4 / TR-input-005 — active device + `pad_style` | `active_device_changed(kind, pad_style)`; patterns in `InputConfig` |
| input-system.md | Rules 5–6 / Formulas / TR-input-002 — repeat timing, radial deadzone, diagonal normalization, per-axis arbitration | Resolver implements `step_time(k)` as `nav_*` actions and `stick_output` in `get_move_vector()`; all knobs in `InputConfig` |
| input-system.md | Rule 7 — bindings are validated data | `bindings_` catalog record; `InputBindingsValidator` registered via `register_record_validator`; failure → catalog `FAILED` → Content Error |
| input-system.md | Rule 8 — remap edits overrides only (VS) | `apply_overrides()` recompiles the table; defaults record untouched |
| input-system.md | Rule 9 / Edge Cases / TR-input-004 — device lost/restored, focus, release-before-signal | Resolver ordering rules; focus gate; echo and axis latches; Open Question 4 closed (§9) |
| input-system.md | Rules 10–11 / TR-input-003 — any pad; device-ID constants | First meaningful pad becomes active; `DEVICE_ID_KEYBOARD/MOUSE` |
| game-state-scene-flow.md | Input routed by Game State with an input lock (Rule 3, AC-8) | `ActionSource` satisfied directly; nav steps are actions; native `ui_*` cannot bypass the lock |
| content-data-definitions.md | Input System row — default bindings follow rules 2 and 8 | `bindings_` prefix and ID rules; validation through the catalog's own pass |

## Performance Implications
- **CPU**: One dictionary lookup per device event plus a few comparisons per `tick`; negligible for a turn-based game. No per-frame allocation (signals carry `StringName`s and value types).
- **Memory**: The compiled binding table is a few dozen entries.
- **Load Time**: Compiling the table at boot is microseconds; validation runs inside the catalog's existing load budget (Content Data `LOAD_TIME_BUDGET`).
- **Network**: None.

## Migration Plan
No Input code exists yet; the battle HUD and demos use mouse or direct calls.
1. `/test-setup` (shared with ADR-0002's Step 0) so `tests/unit/input/` exists.
2. Build `InputActions`, `InputResolver`, `InputConfig`, `InputBindingsValidator`, and the `InputBindings` record script, with `data/bindings/bindings_default.tres` and `data/config/input_config.tres`. Tests for AC-1 to AC-21 come first, plus the fallback-compiles test. Port the spike's verified items 1–3 into regression tests: synthetic event construction, the `ui_*` erase plus re-injection, and the presence of the unfocused-joypad setting.
3. With ADR-0004's implementation: add the bindings validator registration line to `ContentBootstrap.run()`.
4. With ADR-0002's `GameRoot` story: add `InputSystem` under `Services`, construct the resolver after `ContentBootstrap.run()` returns (ADR-0004), bind it to the machine, apply the fallbacks on `FAILED` or a bad config, and set the unfocused-joypad setting in `project.godot`.
5. With the first keyboard-navigable UI story: the UI Framework's re-injection helper (focus-bounded, press-only), the facade, overlay backdrops, the transition blocker, and focus sync.

## Validation Criteria
- AC-1 to AC-21 pass headlessly in `tests/unit/input/`; AC-22 when the Vertical Slice adds overrides.
- A Game State integration test: a key press during a transition moves no `Control` focus (proves `ui_*` stripping plus the lock).
- A Game State integration test: a synthetic mouse click on a `Button` during a transition, and one on a `Button` beneath an open overlay, fires no `pressed` (proves the `MOUSE_FILTER_STOP` blocker and backdrops).
- An integration test: with focus on a control outside the receiving overlay, a routed `confirm` injects nothing. And a transition that starts between a routed press and its release leaves `ui_accept` not pressed.
- The spike's items 1–3 stay green as regression tests on 4.7.2; item 4 is recorded when hardware is available.
- Code review finds no `_input`/`_unhandled_input`/`Input.*` calls outside `src/input/input_system.gd` and the UI Framework's re-injection helper, and no `event.device == 0`.
- A deliberately broken `bindings_default.tres` (an action with no gamepad binding) makes the game boot into Content Error, and Quit works there by keyboard.

## Related
- Depends on: `docs/architecture/adr-0001-content-data-storage-format.md` (Accepted; bindings record format), `docs/architecture/adr-0002-game-state-scene-flow.md` (Accepted; `ActionSource` contract, `TransitionLayer`), `docs/architecture/adr-0004-content-boot-ordering.md` (Accepted; `ContentBootstrap`, `register_record_validator`)
- Design: `design/gdd/input-system.md` (closes Open Question 4), `design/gdd/game-state-scene-flow.md`, `design/gdd/content-data-definitions.md` (new `bindings_` record type)
- Architecture: `docs/architecture/architecture.md` — confirms and changes the proposed Input surface (drops the `is_pressed`/`is_just_*` polling API, adds `nav_*` actions); partly addresses QQ-03 (dual focus) by fixing the GUI routing contract
- Upcoming: UI Framework ADR (re-injection helper, focus sync, prompt labels), Save/Load & Settings ADR (overrides, remap capture)

## Review History
- 2026-10-21 — **godot-specialist** (engine validation): APPROVE with minor notes. A headless spike on 4.7.2 verified synthetic event construction and the default device-ID stamping (keyboard 16, mouse 32). It also verified that `ui_*` erasure plus `parse_input_event` re-injection moves focus and presses `Button`s, that injected events re-enter `_input()`, and the exact unfocused-joypad setting name. The one-frame `pressed` lag and the `key_label` note were folded in.
- 2026-10-21 — **technical-director** (TD-ADR): CONCERNS, 10 findings, all revised in this draft:
  - boot ordering split out into ADR-0004;
  - the bootstrap moved to the composition root and run in `_enter_tree()` with an idempotency guard (both in ADR-0004);
  - a mouse lock via `MOUSE_FILTER_STOP` blockers;
  - focus-bounded, press-only re-injection, with the helper named as the only other `Input` caller;
  - `move_*` and `nav_*` vocabulary pinned;
  - a UI service facade so the resolver never reaches widgets;
  - a fallback for a bad `InputConfig`, plus a fallback-compiles test;
  - the Migration Plan fixed (spike results become regression tests) and the AC-22 wording reconciled;
  - `ui_*` erasure placed in `_enter_tree()`, and `ui_select` marked unverified.
- 2026-10-22 — `/architecture-review` (`architecture-review-2026-10-22.md`): nothing blocking for this ADR. Advisory godot-specialist item E9 (Steam Input on the native Linux Deck presents "Steam Virtual Gamepad", so `pad_style` needs a Deck/Steam row; `ui_select` exists with 2 events, closing the L28 caveat) is not yet folded in.
- 2026-10-22 — **Accepted** by the user, after ADR-0002 and ADR-0004 (explicit instruction: accept ADR-0002 → ADR-0004 → ADR-0003 → ADR-0006 → ADR-0005). No stories were Blocked on this ADR.
