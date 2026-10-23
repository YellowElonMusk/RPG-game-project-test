# ADR-0008: UI Framework — One UI Service, Native Focus, Composable Guard and Focus Components

## Status
Accepted

## Date
2026-10-22

## Last Verified
2026-10-22

## Decision Makers
User (autonomous mode — decisions logged in `production/session-logs/decision-log.md`), Claude (orchestrating session), reviewed by godot-specialist (engine validation, probed on 4.7.2) and technical-director (TD-ADR). Revision 2 folds in both reviews (see Review History).

## Summary
Four Accepted ADRs (0002, 0003, 0005, 0006) and the presentation and input GDDs hand a "UI Framework" concrete obligations that nothing owns yet:
- the `ui_*` re-injection helper and the read-only prompt facade;
- 4.6 dual-focus sync and overlay focus handoff;
- the menu input guard with refusal feedback;
- the transition visuals behind `TransitionPresenter`, the Menu's backdrop blur and the flash-gated UI sources;
- the replay indicator's click;
- the window stretch mode.

Without one owner, each screen would implement these rules its own way, and the guard and focus rules (TR-presentation-012, TR-input-006/009) would drift from screen to screen.

Decided: a `UiService` under `GameRoot/Services` holds the `InputResolver`. It hands every concrete mode and overlay a `UiContext` through a pre-setup injection hook, which keeps the dependency inverted so Game State imports nothing from Presentation. Screens are built from native `Control`s and three composable components: `FocusScope`, `MenuGuard` and `PointerFocusSync`. The guard and pointer rules get their inputs by polling the resolver the service already holds, so no new signals are needed. The UI draws at a 640×360 logical base with `canvas_items` stretch, `expand` aspect and integer scaling. One project `Theme` carries a live text scale.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | UI |
| **Layer** | Presentation |
| **Knowledge Risk** | HIGH — 4.6 dual focus, 4.5 AccessKit and recursive Control disable, 4.7's stretch defaults and `accessibility_live` retyping are all post-cutoff |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `modules/ui.md`, `breaking-changes.md` (GUI, UI, Project, Accessibility rows), `deprecated-apis.md` (`accessibility_live`, `RichTextLabel` image rows), `current-best-practices.md` (UI 4.6, UI and Input 4.7, Accessibility 4.5) |
| **Post-Cutoff APIs Used** | 4.6 dual focus (one focus owner; keyboard/gamepad focus via `grab_focus()`, hover shown separately); 4.7 `Control.offset_transform_*` (a visual offset that containers do not reset) for the refusal pulse; 4.7 stretch settings; 4.5+ AccessKit `Control.accessibility_name` / `accessibility_description` for any custom-drawn interactive control; `DisplayServer.keyboard_get_label_from_physical()` for prompt labels |
| **Verification Required** | **Probed on 4.7.2 (godot-specialist, 2026-10-22):**<br>(1) `canvas_items` + `expand` + `scale_mode = integer` at base 640×360: logical 640×360 at 1920×1080 and 640×400 at 1280×800, no letterbox, and the render target stays at native window size, so 3D renders native (ADR-0005 §3) — **PROBED**;<br>(3) hover alone never moves focus, a click on a `Button` moves it, and there is exactly one focus owner (`gui_get_focus_owner()`) — dual focus is a visual split, not a second focus API — **PROBED**;<br>(4) `add_child()` then a synchronous `grab_focus()` succeeds with no frame wait — **PROBED by proxy**; whether `overlay_opened` fires after the overlay is in the tree is an implementation-order requirement (§5);<br>(5) `DisplayServer.keyboard_get_label_from_physical()` exists and remaps by layout — **PROBED**;<br>(6) a `canvas_item` shader with `hint_screen_texture`, `filter_linear_mipmap` and `textureLod` on a layer-10 `CanvasLayer` compiles and renders with no errors — **PROBED** (pixel capture of the lower layer is REASONED);<br>(7) `Control` exposes `accessibility_name`, `accessibility_description`, `accessibility_live` and the `accessibility_*_nodes` relations — **PROBED**;<br>also probed: `offset_transform_*` names, `ui_page_up/down` injection (one-frame lag, as ADR-0003), `Theme.set_font_size()` live update, and a plain `var` on a concrete subclass of an `@abstract` base.<br>(8) **Windowed render probe, 4.7.2, Vulkan, RTX 4080 (2026-10-22, `/architecture-review` 2026-10-22b F1).** With a fixed 640×360 base, a window that is not an exact multiple is **letterboxed**. The root viewport renders only `f × logical`, and the margins are black for UI and 3D alike: 1280×960 inside 1600×1200 at offset (160,120); 1280×720 inside 1366×768; 2560×1600 inside 2880×1800, which is **4×, not 5×**, since `floor(min(4.5, 5)) = 4`. Refitting `content_scale_size` to `(W div f, H div f)` on every resize (§9) fills the window at the same integer factor: 1600×1200 → 800×600 logical at 2×; 1366×768 → 683×384 at 2×; 2880×1800 → 720×450 at 4×; 1000×500 → 1000×500 at 1×. 1920×1080 and 1280×800 are unchanged. A window size not divisible by `f` leaves under `f` px (1365×767 → 1364×766 at offset (1,1)). **PROBED**.<br>(11) **Hidden focus** (godot-specialist, same review, F2). A mouse click focuses a `Button` with hidden focus: `has_focus()` is true, `has_focus(true)` is false, and the `focus` stylebox is not drawn. `grab_focus(hide_focus := false)` chooses per call. **PROBED**.<br>(12) A `Container` lays out a full-rect child: a `GuardBlocker` under a `VBoxContainer` came out 200×0 (same review, F3). **PROBED**.<br>(13) **Refit trigger** (godot-specialist, `/architecture-review` 2026-10-22c E1/E3/E4). The root `size_changed` fires only when the stretched size changes: 1366×768 → 1920×1080 keeps `f = 2` and fires nothing, leaving the window letterboxed at offset (277,156); `NOTIFICATION_WM_SIZE_CHANGED` did not reach a child on a code-driven resize. Setting `content_scale_size` inside a handler re-fires `size_changed` once (no loop, no flicker). `get_viewport().size` reports the full window (1365×767), and `get_tree().root` is `get_viewport()` for main-scene code. Hence §9's per-frame size check. **PROBED** (code-driven resize; a hand-dragged resize not probed).<br>(14) **Minimum size** (same review, E2). A 600×300 window gives `f = 1` and a 600×300 logical size; hence `min_size`. **PROBED**. Also: from hidden focus, an injected `ui_down` moves focus and reveals it natively (E5). **PROBED**.<br>**Still to verify:** (2) the default `display/window/stretch/mode` when the key is absent (moot: §9 writes it explicitly); (9) dynamic fonts stay sharp under `canvas_items` at 3× and 4× (4.5+ oversampling is not covered by the reference); (10) `Viewport.get_final_transform()` maps window pixels to the logical canvas as §9 uses it |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Game State & Scene Flow, **Accepted**): `GameMode`/`GameOverlay`, `OverlayHost`/`TransitionLayer`, the six announcements, `TransitionPresenter`. ADR-0003 (Input System, **Accepted**): the resolver handed to the UI service, the stripped `ui_*` actions and the re-injection contract, `pointer_position`, `get_move_vector()`, `active_device_changed`, `InputConfig.pointer_switch_px` / `menu_stick_threshold`. ADR-0005 (Sprite & Camera Presentation, **Accepted**): `FlashGate` (§12), the backdrop blur rule (§8), `PresentationConfig` (`input_guard`, `blur_base`, `reduce_blur_factor`), the Boot warm-up (§11). ADR-0006 (Battle Replay Ownership, **Accepted**): the replay indicator click and the refusal feedback on a `false` latch call. ADR-0013 (Localization, **Accepted**): §11's string conventions, including "each control is translated exactly once" |
| **Enables** | Save/Load & Settings ADR (ADR-0009, which lists this ADR under Depends On: it uses the `pre_setup` hook of §2's ADR-0002 amendment, its composition-root adapter implements `UiSettings`, and the settings and remap screens are built on this framework); Overworld Exploration & Encounters ADR (its overlays and prompts); any UI story past the battle HUD |
| **Blocks** | Every UI story beyond the existing battle HUD (Story 005): the Title, Menu, Defeat Prompt, results screen, command menu rewrite and target selection. The `battle_hud.gd` migration to replay-driven display (ADR-0006) uses this ADR's guard and feedback |
| **Ordering Note** | **Additive amendment to ADR-0002 (annotation only, §2):** the production `SceneLoader` and the `OverlayHost` push take an injected `pre_setup: Callable(node: Node)`, which runs after instantiation and before `setup()`. `GameRoot` binds it to `UiService.inject`. `GameMode` and `GameOverlay` are **not** changed: Foundation imports no Presentation type. **Additive amendment to ADR-0003 (annotation only, §4):** `InputResolver` gains the read-only `get_bindings(action, device_kind) -> PackedStringArray`. Neither amendment changes an existing signature, and both take effect when this ADR is Accepted |

## Context

### Problem Statement
The MVP shipped one screen, the battle HUD. It builds its controls in code, keeps its colours as `const`s, and listens to `BattleCore` directly; ADR-0006 already forbids that last part. Every other screen the GDDs name needs the same handful of behaviours: Title, the Menu with settings, the Defeat Prompt, the results screen, the command menu and target selection under the replay rules, and Content Error. Four Accepted ADRs have deferred each of those behaviours to "the UI Framework":

- **ADR-0003 §5:**
  - the re-injection helper (focus-bounded, press-then-release, and the only code besides `InputSystem` that may call `Input`);
  - overlay backdrops with `MOUSE_FILTER_STOP`;
  - dual-focus sync;
  - a read-only prompt facade that keeps the resolver reference out of widgets.
- **ADR-0002:** the visuals behind `TransitionPresenter.play_out/play_in(type, duration, capped)` on `TransitionLayer`, and focus handoff when an overlay opens and closes (QQ-03).
- **ADR-0005:**
  - §8: the Menu backdrop blur over the frozen frame;
  - §11: the Boot warm-up of every in-play canvas material;
  - §12: the flash-gated UI sources;
  - §3: the window stretch mode.
- **ADR-0006:**
  - the replay indicator's click is its own event, never `confirm`;
  - a refused latch produces refusal feedback;
  - the menu-opening input guard is the UI's.

The presentation GDD adds the guard's exact behaviour (TR-presentation-012). The input GDD adds pointer focus after `pointer_switch_px` (TR-input-009). These rules cut across screens. If each screen implemented them, the acceptance criteria that test them would have to be re-verified screen by screen.

### Constraints
- **Engine:**
  - 4.6 shows hover separately from keyboard/gamepad focus, but there is still one focus owner (probed).
  - AccessKit works through native `Control`s and the `accessibility_*` properties (probed).
  - This project's `project.godot` sets no stretch keys.
- **Architecture:**
  - No mutable autoloads (`mutable_autoload_singleton`).
  - Modes and overlays never reach the Input System (`mode_direct_input_access`).
  - Only `InputSystem` and the re-injection helper touch `Input` (`engine_input_outside_input_system`).
  - UI shaders outside `ModeHost` may use `TIME` (`world_shader_time`).
  - Lower layers never import higher ones: Principle 7, so Game State (Foundation) may not name a Presentation type.
- **Platform:** a GTX 1080 desktop at 1920×1080 and the Steam Deck at 1280×800 are both binding (`project.yaml`). The battle budget is ≤ 100 canvas draw calls, counted separately from 3D.
- **Art:** art bible §7 (UI/HUD) is still "[To be designed]". This ADR fixes structure, not look.
- **Resources:** solo developer. The framework is built alongside the first new screen, not as a separate milestone.

### Requirements
- One implementation each of the re-injection helper, focus sync, overlay focus handoff, the input guard and refusal feedback.
- Widgets learn the active device and pad style without holding the resolver.
- Logic rules (guard timing, carry-over, focus-stack bookkeeping) are testable headlessly. Look-and-feel rules are tested by retained screenshot.
- Text scale, Reduce Blur and Reduce Motion apply live, from a settings source this ADR does not own.
- The UI is crisp at 1920×1080 and on Steam Deck, and never moves with the battle camera's hit-punch.

## Decision

**1. `UiService`, the one UI owner.** `src/ui/ui_service.gd` is a `Node` under `GameRoot/Services` with `PROCESS_MODE_ALWAYS`. `GameRoot._ready()` creates it after the `InputResolver`, `GameStateMachine` and `FlashGate`:

```gdscript
setup(machine: GameStateMachine, resolver: InputResolver, flash_gate: FlashGate,
      input_config: InputConfig, presentation_config: PresentationConfig,
      config: UiConfig, settings: UiSettings, real_clock: Callable) -> void
```

It is the second and last holder of the resolver (ADR-0003 §2). It connects to the resolver's `active_device_changed`, `action_pressed`, `action_released`, `pointer_confirm` and `pointer_cancel`, and to the machine's six announcements. Once per frame in `_process`, it polls:
- `resolver.pointer_position`, adding `|Δ|` to the pointer counter (§6);
- `resolver.get_move_vector()`, to derive the held directions (§6).

It builds once, and owns:
- the `PromptFacade` (§4), `UiNavigator` (§3), `UiFeedback` (§7) and `InputCapture` (the remap screen's capture facade, defined with ADR-0009);
- the overlay focus stack (§5), the pointer counter and the held-direction mirror (§6);
- the `UiTransitionPresenter` handed to the machine (§8);
- the project `Theme`'s live text scale (§9);
- the world-to-UI coordinate conversion (§9).

It is not an autoload and holds no game state. Its bookkeeping (who had focus, how far the pointer moved) means nothing outside the current session.

**2. Screens get a `UiContext` through an injected pre-setup hook.** `UiContext` (`RefCounted`) exposes:
- `prompts: PromptFacade`, `navigator: UiNavigator`, `feedback: UiFeedback`, `input_capture: InputCapture` and `settings: UiSettings` (read-only);
- `new_guard() -> MenuGuard`;
- `request_ui_flash(source_id: StringName) -> int`, which books on the real clock at rate 1.0 and returns the handle, or `-1` for the capped variant;
- `cancel_ui_flash(handle)`;
- `world_to_ui(window_px: Vector2) -> Vector2`.

It holds no reference to the resolver or the machine.

*Additive amendment to ADR-0002 (annotation only):* the production `SceneLoader` and the `OverlayHost` push accept an injected `pre_setup: Callable(node: Node)` and call it after instantiating a mode or overlay, before `setup()`. `GameRoot` binds it to `UiService.inject(node)`, which sets `node.ui` if the node declares a `ui` property. **Concrete** mode and overlay scripts (Feature and Presentation) declare `var ui: UiContext`. The Foundation base classes `GameMode`/`GameOverlay` are unchanged and name no Presentation type. This is the same inversion ADR-0002 already uses for `TransitionPresenter`. Tests skip the hook or assign a stub `UiContext`. A screen passes `ui` down to its own widgets through their `setup()` calls, and widgets never look it up.

**3. `UiNavigator`, the re-injection helper (`src/ui/ui_navigator.gd`).** It is the only file outside `src/input/input_system.gd` that may call into `Input`, and only `Input.parse_input_event()` with an `InputEventAction` named `ui_*` (registry `engine_input_outside_input_system`).

```gdscript
func route(receiver: Control, action: StringName) -> bool
```

- **Mapping:**
  - `confirm` → `ui_accept`, `cancel` → `ui_cancel`;
  - `nav_up/down/left/right` → `ui_up/down/left/right`;
  - `page_left/right` → `ui_page_up/down`.

  Any other action returns `false` and injects nothing, so the screen handles it itself.
- It injects only if `receiver.get_viewport().gui_get_focus_owner()` is `receiver` or a descendant (ADR-0003 rule (a)). Otherwise it returns `false`.
- It injects an atomic pair, `pressed = true` then `pressed = false`, in one call, and never mirrors a routed release (ADR-0003 rule (b)).
- It returns `true` when it injected. Assertions on the effect wait for the `Control` signal or two frames (probed: state updates one frame after injection).

**4. `PromptFacade`, read-only device and glyph state (`src/ui/prompt_facade.gd`, `RefCounted`).** It forwards only the device kind, the pad style and glyphs. It exposes no pointer data and no held state.

```gdscript
signal device_changed(kind: StringName, pad_style: StringName)
func active_device_kind() -> StringName          # &"keyboard_mouse" | &"gamepad"
func pad_style() -> StringName                    # &"xbox" | &"playstation" | &"nintendo" | &"generic"
func glyph_for(action: StringName) -> PromptGlyphRef
```

- **`PromptGlyphRef`** is either an atlas region from the active style's `GlyphSet` (pad buttons, mouse buttons, fixed key art), or a short text label drawn on a generic keycap.
- **Keyboard labels:** the facade gets the action's bound tokens through `InputResolver.get_bindings(action, device_kind)` (*additive amendment to ADR-0003*, read-only). It converts each physical keycode to the user's layout label with `DisplayServer.keyboard_get_label_from_physical()` (probed present).
- **`GlyphSet`** is a project config `Resource` per style (`data/ui/glyphs_<style>.tres`), data-only under ADR-0001's rules.
- **`PromptGlyph`** (`src/ui/widgets/prompt_glyph.gd`) takes an action, draws `glyph_for(action)`, and redraws on `device_changed`.

**5. Focus: native `Control` focus, organized by `FocusScope`.** The UI uses Godot's focus system (ADR-0003 rejected a custom focus graph). Every mode root and overlay root that takes keyboard/gamepad input contains one `FocusScope` node (`src/ui/focus_scope.gd`):
- `@export var default_focus: NodePath` is the "safe default" of presentation rule 9 for menus that have one.
- `focus_default()` grabs `default_focus`, or the first focusable descendant if it is empty.
- `contains(control) -> bool`.
- `track(control)` registers a focusable added at runtime.

`UiService` owns the handoff, so no screen hand-codes it:
- **`overlay_opened(kind)`:** push the current focus owner (or `null`) if it is outside the new overlay, then call the new top overlay's `focus_default()`. Overlays do **not** grab focus in their own `_ready()`. *Requirement on ADR-0002's implementation:* `overlay_opened` is emitted after the overlay is in the tree and visible (a synchronous `grab_focus()` then succeeds; probed). If the implementation can't guarantee that, `UiService` defers `focus_default()` with `call_deferred`, and the bookkeeping is unchanged.
- **`overlay_closed(kind)`:** pop. Restore the saved control if it is still valid, in the tree, visible and focusable. Otherwise call `focus_default()` on the new top overlay's scope, or on the mode's.
- **`mode_entered(to)`:** clear the stack, and call the mode's `focus_default()` if it has a scope.

**One focus indicator, shown by device.** Under 4.6 there is one focus owner, and hover is a separate visual state (probed). The theme draws the `focus` stylebox as the single "selected" indicator, and hover uses only the `hover` stylebox, never a second ring. Focus can be **hidden** (Verification item 11). A click focuses natively with hidden focus, so keyboard navigation continues from whatever the player clicked. Every focus grab in this framework states its `hide_focus` value:
- **Pointer-driven grabs hide the ring.** A native click does this itself. `PointerFocusSync` (§6) calls `grab_focus(true)`. With the mouse, the `hover` stylebox is the indicator.
- **Keyboard- and gamepad-driven grabs show the ring.** `focus_default()`, the overlay handoff (`overlay_opened`/`overlay_closed`/`mode_entered`) and restores call `grab_focus(hide)`, with `hide = (active device kind == KEYBOARD_MOUSE and the last input was a pointer event)`. A screen opened from a key or pad press therefore shows its default focus at once.
- **Reveal on navigation.** Before `UiNavigator` (§3) injects a routed `nav_*`, `confirm` or `page_*` action, it checks the focus owner. If the owner's focus is hidden (`has_focus()` true, `has_focus(true)` false), it first calls `owner.grab_focus(false)` and then injects the same action. The first key or pad press after a click shows the ring and acts; no press is swallowed.
- **Refusal on hidden focus.** `UiFeedback.refuse(control)` (§7) pulses the control whether or not its ring is visible, and never reveals the ring. A refused click on a hidden-focus control still pulses that control.

**6. The input guard, carry-over and pointer focus: `MenuGuard` and `PointerFocusSync`.**

`MenuGuard` (`src/ui/menu_guard.gd`, `RefCounted`, from `ui.new_guard()`) is pure logic. Its clock and held-set source are injected. The held-set source is a `Callable` that `UiService` binds to its own mirror; it is not on the widget facade.

```gdscript
enum Verdict { PASS, REFUSE, SWALLOW }
func open(screen_root: Control) -> void        # records t_open, snapshots held actions, raises GuardBlocker
func filter(action: StringName, pressed: bool) -> Verdict
func on_released(action: StringName) -> void    # UiService forwards resolver releases and derived direction releases
func is_guarding() -> bool
```

- **Held-direction mirror.** The resolver emits `nav_*` as presses only, with no release, and never emits `move_*` as actions (ADR-0003 §8). So `UiService` derives held directions itself, once per frame from `resolver.get_move_vector()`:
  - a direction is held while its component is past `InputConfig.menu_stick_threshold`;
  - when the component drops back, `UiService` produces that direction's release (`on_released(&"nav_left")`, …).
  
  Keys, the d-pad and the stick all feed the move vector, so one rule covers every device. Button actions (`confirm`, `cancel`, `page_*`) use the resolver's own `action_released`.
- **Guard window.** For `PresentationConfig.input_guard` seconds (0.15 s; ADR-0005 owns the knob, GDD Tuning Knobs) after `open()`, every menu action press (`confirm`, `cancel`, `nav_*`, `page_*`) returns `REFUSE`.
- **Carry-over.** An action held at `open()` returns `SWALLOW` for every press and repeat step until its release, with no feedback ("does nothing until released"). OS key-repeat echoes never arrive, because the resolver emits one `pressed` per physical press (TR-input-007).
- **Releases** return `PASS`, and are never mirrored (§3).
- **On `REFUSE`,** the screen calls `ui.feedback.refuse(focused_control)`.
- **Pointer clicks during the guard.** `open()` adds a `GuardBlocker` as the last child of `screen_root` for `input_guard` seconds. It is a full-rect transparent `Control` with `MOUSE_FILTER_STOP`. A click on it is a refused press, and the feedback goes to the focused control. The blocker is removed when the guard ends.
- **Full-rect children need a plain parent.** `screen_root`, every overlay root and `TransitionLayer`'s direct `Control` children **must** be plain `Control`s (or `CanvasLayer`s), never `Container`s. A `Container` lays out its children and would collapse the `GuardBlocker`, `MenuBackdrop`, `TransitionCurtain` and input-lock blocker (Verification item 12). Layout containers go one level down, as siblings of those full-rect children.
- **Scope.** `MenuGuard` is **required** on the four screens the GDD names: the command menu, target selection, the Defeat Prompt and the results screen. Other screens (Title, Menu, settings) may use it but are not required to. Widening the scope is a design ruling, not a framework rule.

**`PointerFocusSync`** (`src/ui/pointer_focus_sync.gd`) is a child node of a `FocusScope`. It hooks `mouse_entered` on every focusable descendant, and on descendants added later through `FocusScope.track()`.
- `UiService`'s pointer counter is the cumulative `|Δ pointer_position|` polled each frame. It is reset when a screen opens (`overlay_opened`, `overlay_closed`, `mode_entered`, and every `MenuGuard.open()`).
- A `mouse_entered` grabs focus, with `grab_focus(true)` (hidden; §5), only once the counter has reached `InputConfig.pointer_switch_px` (TR-input-009). A click moves focus natively, also hidden.
- Hover never steals focus before that (presentation GDD rule 9, input rule 3).

**7. Refusal feedback: `UiFeedback.refuse(control: Control)`.**
- **Pulse.** A short pulse on the control through `offset_transform_*`, a visual offset that containers do not reset (`UiConfig.refusal_pulse_px` / `refusal_pulse_time`). It is scaled to zero under Reduce Motion.
- **Tick.** A soft tick through an `AudioStreamPlayer` owned by `UiService`, on the bus named by `UiConfig.feedback_bus`, falling back to `Master` when that bus doesn't exist. The Audio Manager ADR will take the tick over.
- **`control` may be `null`.** Only the tick plays then. ADR-0006's latch refusals during a replay happen with nothing focused; the Battle mode passes the `ReplayIndicator` when it is visible, and `null` otherwise. ADR-0006's `false` from `request_latch()`/`clear_latch()` calls this function.

**8. Transitions, backdrops, UI flashes and warm-up.**
- **`UiTransitionPresenter extends TransitionPresenter`** (ADR-0002's `RefCounted` contract) drives a `TransitionCurtain` `Control` under `TransitionLayer`.
  - `play_out(type, duration, capped)` and `play_in(...)` start a real-clock animation per transition type: `fade`, `battle_wipe`, `battle_wipe_reverse`, `retry_flash`. `none` does nothing.
  - `capped = true` selects the capped variant declared with ADR-0005's flash source declarations.
  - It never signals completion and never extends a phase.
  - The input-lock blocker is a full-rect `MOUSE_FILTER_STOP` `Control` on `TransitionLayer`. It shows from `transition_started` to `transition_finished`, on Game State's timing (ADR-0003 §5).
- **`MenuBackdrop`** (`src/ui/widgets/menu_backdrop.gd`) is every overlay root's first child: a full-rect background with `MOUSE_FILTER_STOP` (ADR-0003 §5).
  - The Menu's variant blurs the screen with a `canvas_item` shader (`hint_screen_texture`, `filter_linear_mipmap`, `textureLod`; probed).
  - Its strength is the Menu preset's `blur_base`, × `reduce_blur_factor` when Reduce Blur is On. Both knobs belong to ADR-0005's `PresentationConfig` and the GDD.
  - It is drawn over a frozen frame (ADR-0005 §8), so it needs no shader time.
- **UI flash sources** are declared with the other flash sources (ADR-0005 §12): `ui_menu_backdrop_open`, `ui_menu_backdrop_close`, `ui_defeat_stamp`, `ui_results_open`.
  - A screen calls `ui.request_ui_flash(id)` when the transition starts, and plays the capped variant on `-1`.
  - A screen that is freed before its transition lands calls `ui.cancel_ui_flash(handle)`.
- **Warm-up.** `UiService.warmup_materials() -> Array[Material]` lists every in-play canvas material: the blur, every curtain variant including the capped ones, the Defeat stamp and the results opening. ADR-0005 §11's Boot warm-up stage draws them in the main viewport, so AC-64's canvas-compile count covers the UI.

**9. Resolution, stretch, coordinates and theme.**
- **Stretch.** These keys are written explicitly into `project.godot`:
  - `display/window/stretch/mode = "canvas_items"`;
  - `aspect = "expand"`;
  - `scale_mode = "integer"`;
  - base viewport **640×360** (the minimum logical size).
- **Refit on every resize (the window is never letterboxed).** With a fixed base, `scale_mode = "integer"` letterboxes any window that is not an exact multiple. The root viewport, and with it the 3D view, then renders only `f × logical`, with black margins (Verification item 8). So `UiService` owns one refit:
  - `f = max(1, floor(min(W / 640, H / 360)))`, with `W × H` the window size in pixels (`get_window().size`);
  - `get_window().content_scale_size = Vector2i(W / f, H / f)` (integer division).
  - **Trigger: a per-frame size check, not `size_changed`.** `size_changed` fires only when the *stretched* size changes. A resize that keeps `f` (1366×768 → 1920×1080, as on maximize) fires nothing, so a signal-driven refit is skipped and the window stays letterboxed (Verification item 13). `UiService._process` (already per-frame, §1) compares `get_window().size` with its last refit size and refits when they differ. It also refits once in `setup()`. Nothing else triggers it. Setting `content_scale_size` re-fires `size_changed` once for other listeners; the size check is unaffected.
  - **Minimum window.** `setup()` sets `get_window().min_size = Vector2i(640, 360)`. Without it a 600×300 window gives `f = 1` and a 600×300 logical size (Verification item 14).

  The canvas then fills the window at integer factor `f` (probed):

  | Window | Factor `f` | Logical size |
  |---|---|---|
  | 1920×1080 | 3× | 640×360 |
  | 2560×1440 | 4× | 640×360 |
  | 3840×2160 | 6× | 640×360 |
  | Steam Deck 1280×800 | 2× | 640×400 |
  | 1600×1200 | 2× | 800×600 |
  | 1366×768 | 2× | 683×384 |
  | 2880×1800 | 4× | 720×450 |

  With `min_size` set, the logical size is never below 640×360. When `W` or `H` is not divisible by `f`, the engine leaves fewer than `f` black pixels on that axis, split between the sides (1365×767: 1364×766 at offset (1,1)). That is accepted. `canvas_items` renders 2D at window resolution, so text stays sharp. `get_viewport().size` still reports the full window size (1365×767), not the drawn area (Verification item 13). ADR-0005's `T = floor(H / 360)` is the same either way while `f ≤ 6`, since `f` then divides 360.
  - **What the refit changes for screens.** The logical rect grows with the window (800×600 at 1600×1200). Every screen already anchors to the full rect and lays out with containers (Layout, below), so the extra logical space goes to margins and expanding containers. No screen may read a fixed 640×360.
  - **Window size on first launch.** `display/window/size/window_width_override` / `window_height_override` are set to 1280×720, so the first windowed launch isn't a 640×360 window.
- **Grid alignment with sprites.** ADR-0005's texel size is `T = max(1, floor(viewport_height / 360))`, from the root viewport's render height. The UI factor `f` takes the smaller of the two axis ratios, so `f == T` whenever `W / 640 ≥ H / 360`, that is, at 16:9 and wider and on the Steam Deck (1280×800: both 2). UI pixels and sprite texels then share one grid on both binding targets (1920×1080 and 1280×800). Where the width ratio is the smaller (4:3 at 1600×1200: UI 2×, sprites 3×; 16:10 at 2880×1800: UI 4×, sprites 5×), the grids diverge. That is accepted: neither binding target is affected, and ADR-0005's 4:3 framing support concerns the 3D camera, not the UI grid.
- **Layout.** Every screen anchors to the full rect and lays out with containers. No screen assumes 16:9. The extra rows at 16:10 and the extra columns at 21:9 go to margins or to an expanding container, never to cropped content.
- **World-to-UI coordinates.** ADR-0005 projects actors in window pixels (`SpriteProjection`, the punch, `size_changed`). Anything the HUD places over an actor, such as damage numbers, converts with `ui.world_to_ui(p) = viewport.get_final_transform().affine_inverse() * p`. That is the one conversion, and it is owned by `UiService` (Verification item 10). It includes the refit's remainder offset (the final transform carries it; probed). ADR-0005's code must keep reading the root viewport's size in pixels (`get_viewport().size.y` as `viewport_height`), never `get_visible_rect()`, which returns logical units under this stretch. Any `size_changed` listener must be idempotent: it runs twice per refit, and the first call sees the logical size before the refit.
- **HUD layering.**
  - A mode's HUD lives under a `CanvasLayer` (layer 1) inside the mode scene. It detaches with the mode (ADR-0002 §4), and it never moves with the battle camera's projection punch (ADR-0005; GDD "the HUD never shakes").
  - Overlays are on layer 10 and transitions on layer 20 (ADR-0002).
- **Theme.**
  - There is one project theme, `data/ui/ui_theme.tres`, set as `gui/theme/custom`. Colours, styleboxes and fonts live there, never as `const`s in screen scripts.
  - **Text scale** (`UiSettings.text_scale()`: 1.0, 1.25 or 1.5) is applied live by `UiService`. It recomputes each theme type's font size as `UiConfig.base_font_sizes` × scale, rounded to an integer, and calls `Theme.set_font_size()`. Existing controls update next frame (probed).
  - Every `Label` and `RichTextLabel` that can wrap uses `AUTOWRAP_WORD_SMART`.

**10. Accessibility.**
- Interactive elements are native `Control`s by default (`Button`, `CheckBox`, `OptionButton`, `ItemList`, `Slider`, `ScrollContainer`), styled through the theme. Keyboard/gamepad focus, `ui_*` behaviour and AccessKit exposure then come from the engine.
- A custom-drawn interactive control is allowed only if it is focusable and sets `accessibility_name` (probed present on 4.7.2) and, where it has state, `accessibility_description`.
- Live regions (`Control.accessibility_live`, typed `AccessibilityServer.AccessibilityLiveMode` since 4.7) are left to the accessibility pass.
- **Not decided here:** whether screen-reader support is an MVP commitment. That is a scope call for the user and creative-director, and it is logged in the decision log as pending. `design/accessibility-requirements.md` does not exist yet. The rules above keep the option open either way.

**11. Strings (per ADR-0013, Localization).**
- Every player-visible string is **English source text**, never a key:
  - in code, `tr("Source text", &"<screen>.<purpose>")` (with `tr_n()` for counts), always with a non-empty context;
  - in scenes, `Control` automatic translation for unambiguous fixed labels;
  - record text through `LocText.of(record, &"field")`.
- No display text is assembled by concatenation. Placeholders are named (`{name}`) and filled with `String.format()` after translation.
- Screens that set text in code re-apply it on `NOTIFICATION_TRANSLATION_CHANGED`, so a live locale switch updates them.
- **Each control is translated exactly once** (ADR-0013 §1). A control whose text is set from code has `auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED`. Otherwise it re-translates the already-translated string, and pseudolocalization doubles. The framework's code-set widgets (`LocText` labels, `PromptGlyph` captions, floating numbers, `ReplayIndicator`) set it in `_init()`. Fixed scene labels stay auto-translated and are never assigned from code.
- Extraction, catalogs and checks are ADR-0013's.

**12. The replay indicator.** `ReplayIndicator` (`src/battle/ui/replay_indicator.gd`) is a battle widget built on this framework:
- it shows ADR-0006's three states;
- it draws the `fast_forward` glyph from the facade and follows the text scale;
- it emits `indicator_clicked()` on a pointer press, which the Battle mode connects to the latch logic (ADR-0006);
- it is not focusable, and never emits or injects `confirm`.

**13. What this ADR does not decide.**
- The look: art bible §7.
- The settings and remap screens' content and persistence: ADR-0009, whose composition-root adapter supplies the production `UiSettings`.
- The string pipeline: the Localization ADR.
- Damage-number timing: already fixed by ADR-0006.
- Audio Manager's bus layout.
- The screen-reader commitment: §10.

### Architecture Diagram

```
GameRoot
├── ModeHost ─ <mode> (concrete script declares `var ui: UiContext`)
│               ├── FocusScope ─ PointerFocusSync
│               └── HudLayer (CanvasLayer 1) ─ widgets (PromptGlyph, ReplayIndicator, …)
├── OverlayHost (CanvasLayer 10) ─ <overlay> (concrete script declares `var ui`)
│               ├── MenuBackdrop (MOUSE_FILTER_STOP; Menu: screen blur)
│               ├── FocusScope ─ PointerFocusSync
│               └── GuardBlocker (only while a MenuGuard is guarding)
├── TransitionLayer (CanvasLayer 20) ─ TransitionCurtain + input-lock blocker
└── Services
    ├── InputSystem ─ InputResolver ─── signals: active_device_changed, action_pressed/released,
    │                                   pointer_confirm/cancel;  polled: pointer_position, get_move_vector()
    ├── FlashGate
    └── UiService ◄─ resolver, machine, FlashGate, InputConfig, PresentationConfig, UiConfig, UiSettings
          ├─ inject(node) ◄── SceneLoader / OverlayHost pre_setup Callable (bound by GameRoot)
          ├─ PromptFacade ──► PromptGlyph widgets (device_changed)
          ├─ UiNavigator ───► Input.parse_input_event(ui_*)   (only here, besides InputSystem)
          ├─ UiFeedback (pulse + tick)
          ├─ overlay focus stack ◄── overlay_opened/closed, mode_entered
          ├─ held-direction mirror + pointer counter (polled each frame) ──► MenuGuard, PointerFocusSync
          ├─ text scale ──► ui_theme.tres font sizes;  world_to_ui()
          ├─ warmup_materials() ──► ADR-0005 Boot warm-up
          └─ UiTransitionPresenter ──► machine (ADR-0002 TransitionPresenter)

 routed action ─► machine ─► top overlay / mode.handle_action(a)
                               ├─ guard.filter(a) ─ REFUSE → ui.feedback.refuse(focus)
                               │                  └ SWALLOW → nothing
                               └─ PASS → ui.navigator.route(self, a) ─► native focus / Button
```

### Key Interfaces

```gdscript
## src/ui/ui_service.gd — GameRoot/Services, PROCESS_MODE_ALWAYS; not an autoload
class_name UiService extends Node
func setup(machine: GameStateMachine, resolver: InputResolver, flash_gate: FlashGate,
           input_config: InputConfig, presentation_config: PresentationConfig,
           config: UiConfig, settings: UiSettings, real_clock: Callable) -> void
func inject(node: Node) -> void                      # bound into SceneLoader/OverlayHost pre_setup
func get_transition_presenter() -> TransitionPresenter
func warmup_materials() -> Array[Material]
func refit_canvas() -> void                          # §9: content_scale_size = window / f; in setup() and when _process sees get_window().size change

## src/ui/ui_context.gd — what a mode, overlay or widget may use
class_name UiContext extends RefCounted
var prompts: PromptFacade          # read-only
var navigator: UiNavigator
var feedback: UiFeedback
var input_capture: InputCapture    # remap capture facade; added by ADR-0009's capture amendment, null until then
var settings: UiSettings           # read-only
func new_guard() -> MenuGuard
func request_ui_flash(source_id: StringName) -> int    # -1 = play capped
func cancel_ui_flash(handle: int) -> void
func world_to_ui(window_px: Vector2) -> Vector2

## src/ui/ui_navigator.gd — the only Input caller besides InputSystem
class_name UiNavigator extends RefCounted
func route(receiver: Control, action: StringName) -> bool

## src/ui/prompt_facade.gd — device, style and glyphs only
class_name PromptFacade extends RefCounted
signal device_changed(kind: StringName, pad_style: StringName)
func active_device_kind() -> StringName
func pad_style() -> StringName
func glyph_for(action: StringName) -> PromptGlyphRef

## src/ui/menu_guard.gd — pure; clock and held-set Callable injected by UiService
class_name MenuGuard extends RefCounted
enum Verdict { PASS, REFUSE, SWALLOW }
func _init(clock: Callable, held_now: Callable, guard_s: float) -> void
func open(screen_root: Control) -> void
func filter(action: StringName, pressed: bool) -> Verdict
func on_released(action: StringName) -> void
func is_guarding() -> bool

## src/ui/focus_scope.gd
class_name FocusScope extends Node
@export var default_focus: NodePath
func focus_default() -> void
func contains(control: Control) -> bool
func track(control: Control) -> void

## src/ui/ui_feedback.gd
class_name UiFeedback extends RefCounted
func refuse(control: Control) -> void          # null = tick only

## src/ui/ui_settings.gd — interface; the production adapter is built in the composition root (ADR-0009); tests stub it
class_name UiSettings extends RefCounted
signal changed()
func text_scale() -> float                     # 1.0 | 1.25 | 1.5
func reduce_blur() -> bool
func reduce_motion() -> bool

## src/ui/ui_config.gd — project config, data/config/ui_config.tres (ADR-0001 data-only rules)
class_name UiConfig extends Resource
@export var refusal_pulse_px: float = 2.0
@export var refusal_pulse_time: float = 0.12
@export var feedback_bus: StringName = &"UI"
@export var base_font_sizes: PackedStringArray   # "ThemeType:size" pairs, e.g. "Label:12"
# input_guard, blur_base, reduce_blur_factor stay in PresentationConfig (ADR-0005 / GDD)

## Amendments (annotation only)
# ADR-0002: production SceneLoader + OverlayHost push take pre_setup: Callable(node), called before setup()
# ADR-0003: InputResolver gains func get_bindings(action: StringName, device_kind: StringName) -> PackedStringArray
```

### Implementation Guidelines
- The command menu, target selection, Defeat Prompt and results screen **must** contain a `FocusScope` and route menu actions through `MenuGuard.filter()`, then `UiNavigator.route()`. Every other screen that takes menu input **must** contain a `FocusScope` and route through `UiNavigator`. A screen **must never** call `grab_focus()` from its own `_ready()` on open; `UiService` does it on the announcement.
- No script except `src/input/input_system.gd` and `src/ui/ui_navigator.gd` **may** call into `Input`. `UiNavigator` **may** call only `Input.parse_input_event()` with a `ui_*` `InputEventAction`, and **must** inject press and release together.
- Widgets **must** get the device, the style and glyphs only from `UiContext.prompts`. No widget **may** hold or receive the `InputResolver` or the `GameStateMachine`.
- `GameMode` and `GameOverlay` **must not** declare or import a UI type. Only concrete mode and overlay scripts declare `var ui: UiContext`.
- Colours, fonts and styleboxes **must** come from `ui_theme.tres`. Screen scripts **must not** declare colour or font-size `const`s; the existing `BattleHud` constants move to the theme in its migration story.
- Every overlay root **must** have a full-rect `MenuBackdrop` with `MOUSE_FILTER_STOP` as its first child.
- `screen_root`, every overlay root and every direct `Control` child of `TransitionLayer` **must** be a plain `Control`, never a `Container` (§6).
- Every `grab_focus()` call **must** pass `hide_focus` explicitly: `true` for pointer-driven grabs, the device rule of §5 otherwise.
- The window stretch **must** be refit only by `UiService.refit_canvas()` (§9). No script **may** set `content_scale_size` or read a fixed 640×360.
- The refit **must** be driven by the per-frame `get_window().size` comparison in `UiService._process` (§9), never by `size_changed` alone (Verification item 13). `setup()` **must** set `get_window().min_size = Vector2i(640, 360)`.
- A control whose text is set from code **must** have `auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED` (§11, ADR-0013 §1).
- An interactive element **must** be a native `Control`, or a focusable custom control that sets `accessibility_name` (§10).
- Player-visible strings **must** be English source text through `tr(source, context)`, scene auto-translation or `LocText` (§11, ADR-0013). Concatenating display text **is forbidden**.
- A HUD **must** live under a `CanvasLayer` inside its mode scene, never under `OverlayHost` and never in a 3D viewport. Positions over actors **must** go through `ui.world_to_ui()`.
- UI animations **must** run on the real clock. UI shaders under `OverlayHost`/`TransitionLayer` **may** use `TIME`. Mode-HUD shaders **must not** (registry `world_shader_time`).
- Every in-play canvas material **must** be listed in `warmup_materials()`.
- The replay indicator click **must** be its own signal, never `confirm` (ADR-0006).
- **Tests:** these are unit-tested in `tests/unit/ui/` with an injected clock, an injected held-set `Callable` and a stub focus owner:
  - `MenuGuard`;
  - the focus-stack bookkeeping;
  - the held-direction mirror (move-vector threshold crossings produce releases);
  - the pointer counter;
  - `UiNavigator`'s mapping and focus-bound check.

## Alternatives Considered

### Alternative 1: A custom focus graph (no Godot `Control` focus)
- **Description**: The UI keeps its own selection model and draws its own focus; `ui_*` actions are never used.
- **Pros**: Full control of focus behaviour; no re-injection.
- **Cons**: Re-implements the keyboard behaviour of `Button`, `ItemList` and `ScrollContainer`, and loses AccessKit exposure, which follows native focus.
- **Rejection Reason**: Already rejected in ADR-0003. The probe shows 4.6 keeps a single focus owner, so native focus is enough.

### Alternative 2: Per-screen implementations with a shared style guide
- **Description**: No framework service. Each screen implements the guard, focus handoff and prompts, following a written convention.
- **Pros**: No new service, nothing to inject.
- **Cons**: The guard, carry-over and pointer rules are subtle, and would be implemented and tested once per screen. Overlay focus handoff needs state that spans screens (what had focus below), which no single screen owns.
- **Rejection Reason**: The rules span screens by nature, and a convention can't hold the focus stack.

### Alternative 3: A UI autoload
- **Description**: `Ui` as an autoload, reachable by name from any widget.
- **Pros**: No injection plumbing, no ADR-0002 amendment.
- **Cons**: It holds mutable state (the focus stack, the pointer counter, the held mirror), which `mutable_autoload_singleton` forbids, and it would give every widget a path to the resolver's data.
- **Rejection Reason**: Violates Architecture Principle 4 and ADR-0003's facade rule.

### Alternative 4: Typed `var ui: UiContext` on `GameMode`/`GameOverlay`
- **Description**: The first draft. The Foundation base classes carry the field, and `SceneLoader` assigns it.
- **Pros**: Every mode has `ui` without declaring it.
- **Cons**: Game State (Foundation) would import a Presentation type, breaking Principle 7.
- **Rejection Reason**: TD review. The injected `pre_setup` Callable gives the same result with the dependency inverted.

### Alternative 5: New resolver signals for pointer motion and direction release
- **Description**: Amend ADR-0003 with `pointer_moved(delta)` and a `nav_*` release.
- **Pros**: Event-driven, no polling.
- **Cons**: Widens the Input contract for one consumer. `nav_*` was deliberately designed press-only (ADR-0003 §8).
- **Rejection Reason**: `UiService` already holds the resolver, and polling two getters once a frame costs nothing.

### Alternative 6: `viewport` stretch at 640×360
- **Description**: Render the whole UI into a low-resolution buffer for exact pixel art.
- **Pros**: Exact pixels.
- **Cons**: Text is blurry or blocky at every text scale. `viewport` mode would also scale the 3D render, which ADR-0005 §3 requires at native size.
- **Rejection Reason**: `canvas_items` with an integer factor gives the same grid for frame art, with sharp fonts and native 3D.

### Alternative 7: Base resolution 1920×1080 with fractional scaling
- **Description**: Author the UI at 1080p, and scale it by 0.667 on the Steam Deck.
- **Pros**: The usual default; more layout room in authoring units.
- **Cons**: Pixel frame art (the art bible's chunky pixel corners) shimmers at non-integer factors, and the Deck is a binding target.
- **Rejection Reason**: Integer scaling matches ADR-0005's texel grid on both binding targets.

## Consequences

### Positive
- Each rule that spans screens is implemented and tested in one place. Screens compose `FocusScope`, `MenuGuard` and `PointerFocusSync` instead of re-deriving them.
- The resolver stays with exactly two holders (ADR-0003), and `Input` with exactly two callers. No new Input signals are needed.
- Game State stays free of Presentation types.
- QQ-03 (4.6 dual focus, AccessKit) gets an owner and a rule: one focus indicator, plus native controls or named custom controls.
- On both binding targets, UI pixels and sprite texels share the `floor(H/360)` grid.
- Text scale, Reduce Blur and Reduce Motion apply live through one interface, filled by the settings system's adapter.

### Negative
- Two additive amendments: ADR-0002 (a `pre_setup` hook on two production collaborators) and ADR-0003 (`get_bindings`).
- Each concrete screen script declares `var ui`.
- `UiService` polls two resolver getters every frame.
- A 640×360 base gives little layout room. Dense screens (Codex, party) must scroll or page rather than shrink text.
- Below 16:10, the UI grid and the sprite grid diverge (accepted, §9).
- The battle HUD needs a migration (theme colours, the `CanvasLayer`, replay-driven display) before it follows these rules.

## Risks
- **`overlay_opened` fires before the overlay is ready.** *Mitigation*: the requirement on ADR-0002's implementation in §5, with a `call_deferred` fallback.
- **Integer scaling at untested sizes** (items 8–9). *Mitigation*: the Validation screenshots include 4:3 and 2880×1800. If text loses sharpness, `canvas_items` oversampling settings are tuned per the probe.
- **Blur cost on the Steam Deck.** `hint_screen_texture` forces a screen copy. *Mitigation*: only the Menu backdrop blurs, only while the Menu is open, while the world is frozen. P-14-style capture measures it with the rest of the frame.
- **The guard and the replay latch.** *Mitigation*: the guard applies only to menus. No menu is open during a replay, and the latch path (ADR-0006) doesn't pass through `MenuGuard`.
- **A missing `UI` audio bus** before the Audio Manager ADR. *Mitigation*: falls back to `Master`, and the bus name is data.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| sprite-camera-presentation.md | TR-presentation-012: menus open with safe default focus and refuse every menu action for `input_guard`, with visible and audible refusal; held inputs never carry in | §5 `FocusScope.default_focus`; §6 `MenuGuard` (REFUSE / SWALLOW, held-direction mirror) and `GuardBlocker`; §7 `UiFeedback.refuse` |
| input-system.md | TR-input-006: raw pointer events go to UI, which syncs 4.6 dual focus | §5 one focus indicator; §6 `PointerFocusSync` |
| input-system.md | TR-input-009: hover moves focus only after `pointer_switch_px` since the screen opened | §6 polled pointer counter, reset per screen |
| input-system.md | TR-input-005 (consumer side): prompts match the active device and pad style | §4 `PromptFacade`, `PromptGlyph`, `GlyphSet`, layout labels |
| input-system.md | Rule 5 / ADR-0003 §5: routed, then re-injected navigation | §3 `UiNavigator` |
| game-state-scene-flow.md | UI renders transitions, the Menu, the Defeat Prompt and Title; overlay focus | §8 `UiTransitionPresenter`, `MenuBackdrop`; §5 focus stack |
| game-state-scene-flow.md | TR-gamestate-007 (UI side): a refused flash plays its capped variant, with timing unchanged | §8 presenter `capped` variants; UI flash sources |
| sprite-camera-presentation.md | UI Requirements: the Menu shows a frozen, blurred world; Reduce Blur scales it | §8 `MenuBackdrop` with `blur_base` × `reduce_blur_factor` |
| sprite-camera-presentation.md | UI Requirements: the HUD never shakes; the world never tints the UI | §9 HUD on a `CanvasLayer`; UI unlit |
| sprite-camera-presentation.md | UI Requirements: the replay indicator is clickable and follows the text scale | §12 `ReplayIndicator` |
| sprite-camera-presentation.md | AC-64 (compile contract, UI part): in-play canvas materials are warmed at Boot | §8 `warmup_materials()` |
| sprite-camera-presentation.md | TR-presentation-022 (partial): Reduce Blur and Reduce Motion applied live | §7, §8 via `UiSettings`; the settings service is ADR-0009's |
| content-data-definitions.md | TR-content-012 (partial): player-visible strings can be extracted | §11 English source text with contexts (ADR-0013) |

## Performance Implications
- **CPU**: negligible. The guard and focus logic run per action. Polling `pointer_position` and `get_move_vector()` is two getter calls per frame. UI animations run on the real clock.
- **GPU / draw calls**: the HUD counts against the ≤ 100 canvas draw-call budget, and theme styleboxes batch. The Menu blur adds one screen copy and one draw, only while the Menu is open.
- **Memory**: one theme, plus one glyph atlas per pad style (four small atlases).
- **Load Time**: the theme and glyph sets load in `GameRoot._ready()`. UI materials are compiled in ADR-0005's Boot warm-up, not on first use.

## Migration Plan
1. **With the first new screen story** (Title or Defeat Prompt), build:
   - `UiService`, `UiContext`, `UiNavigator`, `MenuGuard`, `FocusScope`, `PointerFocusSync`, `UiFeedback` and `UiConfig`;
   - a stub `UiSettings` returning defaults;
   - `ui_theme.tres`, and the stretch settings in `project.godot`;
   - the ADR-0002 `pre_setup` hook and the ADR-0003 `get_bindings` amendment.

   Write the unit tests first, in `tests/unit/ui/`.
2. **With ADR-0002's Game State implementation:** `UiTransitionPresenter` and the `TransitionLayer` blocker. Add `warmup_materials()` to ADR-0005's Boot warm-up.
3. **With the first screen that shows a button prompt** (the replay indicator): `PromptFacade`, `PromptGlyph` and the glyph atlases.
4. **`battle_hud.gd` migration, alongside ADR-0006's display migration:**
   - colours move to the theme;
   - the HUD moves under a `CanvasLayer`;
   - damage numbers are positioned through `world_to_ui()`;
   - the command menu and target selection move onto `FocusScope` + `MenuGuard`.
5. **With the Menu overlay story:** the `MenuBackdrop` blur.

## Validation Criteria
- **Unit (`MenuGuard`):**
  - refuses every menu action for exactly `input_guard`, with the boundary at 0.149 / 0.150 s on an injected clock;
  - swallows the presses and `nav_*` steps of a direction held at `open()` until the held-direction mirror releases it;
  - passes releases.
- **Unit (held-direction mirror):** a move vector crossing below `menu_stick_threshold` produces exactly one release for that direction.
- **Unit (focus stack):** restores the saved control after `overlay_closed`, and falls back to the scope default when the saved control was freed.
- **Unit (`UiNavigator.route`):** returns `false` and injects nothing when focus is outside the receiver, and maps each routed action to the right `ui_*`.
- **Integration (pointer):** with the mouse resting over a button when a menu opens, focus stays on the default until the pointer has moved `pointer_switch_px`.
- **Integration (focus visibility):** a click leaves the clicked control focused with hidden focus (`has_focus(true)` false). The next `nav_*` press makes the focus visible and moves it. A menu opened from a key press shows its default focus visible at once.
- **Unit (`refit_canvas`):** for 1920×1080, 1280×800, 1600×1200, 1366×768 and 2880×1800, `content_scale_size` is 640×360, 640×400, 800×600, 683×384 and 720×450, and never below 640×360.
- **Integration (refit trigger, windowed):** resize 1366×768 → 1920×1080 directly (same `f = 2`): within one frame `content_scale_size` is 640×360 and the viewport offset is (0,0). Resize request to 600×300: the window stays at least 640×360 and the logical size is 640×360.
- **Screenshots** (retained in `production/qa/evidence/`):
  - the same screen at 1920×1080, 1280×800, 1600×1200, 1366×768 and 2880×1800, at text scale 1.0 and 1.5, with no clipped text, integer-scaled frames and **no black margins** (an open transition curtain and the Menu backdrop cover the whole window). Every listed size divides by its `f`; an uneven size leaves an accepted strip under `f` px (§9) and must not be added to this check;
  - the Menu backdrop with Reduce Blur off and on.
- **Code review:**
  - no `Input.` outside the two files;
  - no colour or font `const`s in screen scripts;
  - every overlay has a `MenuBackdrop`;
  - no `screen_root`, overlay root or `TransitionLayer` child is a `Container`;
  - every control assigned text from code has `auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED`;
  - every `grab_focus()` call in `src/ui/` passes an explicit `hide_focus` argument;
  - `GameMode`/`GameOverlay` import no `src/ui/` type.

## Related
- **Depends on:**
  - `adr-0002-game-state-scene-flow.md` (amended additively, §2);
  - `adr-0003-input-system.md` (amended additively, §4);
  - `adr-0005-sprite-camera-presentation.md` (§3, §8, §11, §12; `PresentationConfig` knobs);
  - `adr-0006-battle-replay-ownership.md` (the indicator click; refusal on a `false` latch call);
  - `adr-0013-localization.md` (§11's string conventions).
- **Enables:** `adr-0009-save-load-settings.md` (the production `UiSettings` adapter, `InputCapture`, the settings and remap screens).
- **GDDs:**
  - `design/gdd/sprite-camera-presentation.md` (UI Requirements, rule 9, rule 13, Tuning Knobs);
  - `design/gdd/input-system.md` (rules 3–5);
  - `design/gdd/game-state-scene-flow.md` (rules 10–13).
- **Strings:** `adr-0013-localization.md` (revised §11 in place).
- **Upcoming:** the Audio Manager ADR (takes over the refusal tick).
- **On acceptance:**
  - `architecture.md` closes QQ-03;
  - the registry's `input_prompt_facade` is narrowed (no pointer events);
  - `transition_presenter` gains `capped`;
  - new stances are registered: UI context injection, the theme as the only colour and font source, and the HUD on a mode-local `CanvasLayer`.

## Review History
| Date | Reviewer | Verdict | Notes |
|------|----------|---------|-------|
| 2026-10-22 | technical-director (TD-ADR) | CONCERNS → revised | 4 blocking: held/pointer data the resolver doesn't emit (fixed: poll `get_move_vector()`/`pointer_position`, held mirror off the facade); duplicate knobs vs `PresentationConfig` (fixed: use `input_guard`, `blur_base`, `reduce_blur_factor`); ADR-0002 amendment broke layering (fixed: `pre_setup` Callable, base classes unchanged); integer-scale formula (fixed: `min` rule, divergence below 16:10 accepted). Advisories folded: world-to-UI conversion, warm-up, guard scope limited to the GDD's four screens, `refuse(null)`, bus name in data, `tr()` provisional, screen-reader commitment logged as pending, registry follow-ups, font-sharpness verification item |
| 2026-10-22 | godot-specialist | APPROVE WITH NOTES | Probed 1, 3, 4 (proxy), 5, 6, 7 and five extra checks on 4.7.2; items 5 and 7 no longer NOT SOURCEABLE; confirmed both resolver gaps the TD found |
| 2026-10-22 | `/architecture-review` (`architecture-review-2026-10-22b.md`) | CONCERNS → fixed | godot-specialist **F1** (blocking): integer stretch with a fixed base letterboxes non-multiple windows. A windowed probe (Verification item 8) showed the root viewport, and so the 3D view, renders only `f × logical` with black margins, and 2880×1800 is 4×, not 5×. Fixed: §9 `refit_canvas()` sets `content_scale_size = window / f` on every resize; corrected table and grid-alignment rule; 1280×720 first-launch window (F9's window note). **F2** (blocking): a click gives hidden focus. Fixed: §5 states `hide_focus` per path (pointer hidden; key and pad visible; reveal-then-inject on navigation; refusal never reveals). **F3**: full-rect children need plain `Control` parents (§6, guideline; needed by F1's full-window curtain and backdrop). **F4**: §11 "each control is translated exactly once" (ADR-0013 §1). Dependencies: ADR-0013 added to Depends On and removed from Enables. Validation: refit unit test, focus-visibility integration test, 1366×768 screenshot with no black margins, three review checks. F9's `pointer_*` during the guard remains advisory |
| 2026-10-22 | User | **Accepted** | Explicit instruction (order ADR-0013 → ADR-0008 → ADR-0009 → ADR-0011 → ADR-0010). Dependencies ADR-0002, 0003, 0005, 0006 and 0013 are Accepted. No story was Blocked on this ADR. Its additive amendments to ADR-0002 (`pre_setup`) and ADR-0003 (`get_bindings`) are annotated in their Status sections |
| 2026-10-22 | `/architecture-review` (`architecture-review-2026-10-22c.md`) | CONCERNS → fixed (Accepted; correction in place, no re-acceptance: the decision is unchanged, only the refit trigger) | godot-specialist **E1** (HIGH, blocking §9 implementation): `size_changed` misses resizes that keep `f`. Fixed: §9 refit is driven by a per-frame `get_window().size` comparison in `UiService._process`, plus once in `setup()`; Verification item 13; Implementation Guideline; windowed 1366×768 → 1920×1080 integration test. **E2**: `min_size = 640×360` set in `setup()`; Verification item 14; test. **E3**: `size_changed` listeners must be idempotent (§9 coordinates). **E4**: §9 says `get_viewport().size` is the full window; ADR-0005 reads `get_viewport().size.y`. **E5** recorded (native reveal on navigation). **E7**: the no-margins screenshot check keeps to sizes divisible by `f` |
