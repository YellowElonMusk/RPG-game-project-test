# Input System

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-10-22
> **Last Verified**: 2026-10-13
> **Implements Pillar**: Readable in One Turn (via the `inspect` action and consistent, device-aware prompts)
> **Amendment (2026-10-22)**: `fast_forward` is a button that may be tapped or held, not a hold-only action. In battle replays a tap latches fast-forward and Cancel clears it, per Sprite & Camera Presentation rule 9 (creative-director ruling of the 2026-10-22 `/design-review`); Dialogue may still use it as a hold. OS key-repeat echoes never produce a second `pressed` (rule 2). Input's own behavior is otherwise unchanged.
> **Follow-up (2026-10-22, fourth `/design-review` ruling 1)**: the battle-replay latch has one level. A `fast_forward` or `confirm` press (or a click on the replay prompt) speeds every beat's wind-up, knockouts included (the slump hold after a knockout always plays at normal speed). The first boss entrance is sped only with the opt-in "Speed up boss entrances" setting. (Updated 2026-10-22 to the presentation GDD revision 6 rulings: knockouts became plain beats, and the setting was renamed from "Speed up all replay beats".) Input's own behavior is unchanged.

## Summary

Input System turns keyboard, mouse and gamepad input into eight named game actions (move, confirm, cancel, menu, inspect, page left/right, fast-forward), and tracks which device the player is using so on-screen prompts always match. Players get DQ-style controls that work the same on any device: menus by keys, pad or mouse, walking by keys or pad, and an `inspect` button that explains any rule on screen. It deliberately knows nothing about game modes, so it stays a one-way foundation every other system can rely on.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `Content Data Definitions (soft — bindings data)`

## Overview

Input System turns physical devices (keyboard, mouse and gamepad) into a small set of named game actions such as `confirm`, `cancel`, `menu` and `move`, and keeps track of which kind of device the player is currently using. It knows nothing about game modes. It reports *what the player pressed*, and Game State & Scene Flow decides *who receives it* (the current mode or the top overlay). That separation keeps the dependency one-way and lets every other system stay device-agnostic.

Players feel it as controls that simply work, whichever device they pick up: walking with WASD, the arrow keys, a stick or a d-pad; menus and battle commands navigable by keyboard, gamepad, or by pointing and clicking with the mouse; and on-screen button prompts that switch to match the device last used. Bindings live in data from day one, so the remapping screen planned for the Vertical Slice is a UI task, not a redesign.

## Player Fantasy

**"My hands already know this game."** Whatever the player picks up (keyboard,
an Xbox or PlayStation pad, the Steam Deck), the controls should feel like the
ones they already trust from the genre: the stick walks, `confirm` confirms,
`cancel` backs out, menus scroll at a steady clip and never overshoot. The
player never reads a prompt for a device they are not holding, and never has to
hold a button to do anything.

The system serves Pillar 4 (Readable in One Turn) at the level of the hands: a
command the player meant is the command that happens, once. Its guardrails:
- **One press, one action.** No doubled or eaten presses, across devices and across transitions.
- **Prompts never lie.** The on-screen glyph always matches the device in use.
- **Nothing held or timed.** Every action is a discrete press (accessibility commitment).

> Retrofit 2026-10-23 (commit-hook gap at `workflow: full`), written from the existing Overview and Game Feel; no rule changed.

## Detailed Design

### Core Rules

**1. Action set (MVP).** Every input the game understands is one of these actions. Default bindings are data (rule 7); this table is the shipped default. Gamepad buttons are named by **position**, not printed label, so the same binding works on Xbox, PlayStation and Nintendo-style pads.

| Action | Kind | Keyboard | Gamepad | Mouse | Purpose |
|---|---|---|---|---|---|
| `move` | vector | WASD, arrow keys | Left stick, d-pad | — | Overworld walking; menu navigation (rule 5) |
| `confirm` | button | Enter, Space, Z | South face button | Left-click (via UI, rule 3) | Accept / advance text |
| `cancel` | button | Esc, Backspace, X | East face button | Right-click (via UI, rule 3) | Back out of a menu or selection |
| `menu` | button | Tab, M | Start | — | Open the Menu overlay |
| `inspect` | button | I, Q | North face button | Hover (tooltip) | Show the full rule text of a hovered enemy, quirk state or faction rule (Pillar 4) |
| `page_left` / `page_right` | button | 1 / 3 | Left / right shoulder | Mouse wheel (in lists) | Switch party member, tab or list page |
| `fast_forward` | button | Shift | West face button | — | Speed up battle replays and dialogue text. In a battle replay, a press latches a speed-up of the remaining plain beats and `cancel` clears it (Sprite & Camera Presentation rule 9); in Dialogue it speeds text while held. How much is decided by Turn Battle and Dialogue |

**2. Device → action only.** Input reports actions as `pressed`, `released` and `held`, plus the current `move` vector. It has **no knowledge of modes, overlays or transitions** and never decides whether an action should be used. A button produces exactly one `pressed` per physical press: while it stays down, Input emits `held`, and the operating system's key-repeat echoes never produce another `pressed`. Receivers that guard against mashing (Sprite & Camera Presentation rule 9) rely on this. Game State & Scene Flow routes actions to the current mode or top overlay and applies the input lock. This rule is what prevents a dependency loop between the two systems.

**3. Mouse scope.** The mouse provides raw pointer events: `pointer_position`, `pointer_confirm` (left-click), `pointer_cancel` (right-click) and wheel steps. Input always reports them, because it cannot know what is clickable. The **UI Framework** decides whether a click landed on an interactive element and, if so, turns it into `confirm` or `cancel` for that element. A click on empty space therefore does nothing. Only menus, battle command windows and other UI use the pointer. **Overworld movement is never driven by the mouse** (no click-to-move). Hovering a UI element moves keyboard/gamepad focus to it, but only once the pointer has moved at least `pointer_switch_px` (cumulative) since that menu opened, so a resting or bumped pointer never steals the default focus (Sprite & Camera Presentation rule 9), and the two never disagree about what is selected (Godot 4.6+ keeps mouse focus and keyboard/gamepad focus separate, so the UI Framework must sync them).

**4. Active device.** Input tracks the **active device kind**: `keyboard_mouse` or `gamepad`. It switches to the kind of the last meaningful input: a key press, a mouse click or a mouse move of at least `pointer_switch_px` pixels; a gamepad button press; or a stick or trigger past its deadzone. It then broadcasts `active_device_changed(kind, pad_style)`, where `pad_style` (`xbox` | `playstation` | `nintendo` | `generic`) lets the UI show matching button prompts. Stick drift inside the deadzone never switches the device.

**5. Menu navigation repeat.** When `move` drives a menu, holding a direction produces one navigation step immediately, then repeats after `repeat_delay` at every `repeat_interval` (Formulas) until released. Overworld walking uses the continuous `move` vector and has no repeat. Each step is reported as one of four **derived actions**, `nav_up`, `nav_down`, `nav_left` and `nav_right` (never bound, `pressed` only). They are always emitted, since Input knows no modes, and a receiver that doesn't navigate ignores them (ADR-0003). `move` is bound as four sub-actions (`move_up/down/left/right`) that only feed the vector.

**6. Analog handling.** Sticks use a radial deadzone and rescale the remaining range to 0–1 (Formulas). For menu navigation, a stick counts as a direction once its magnitude passes `menu_stick_threshold` along that axis. The d-pad and keys are always full magnitude, and their diagonals are normalized to length 1, so walking diagonally is never faster than walking straight.

**7. Bindings are data.** The default bindings are a data record following the Content Data Definitions rules (stable IDs, strict validation). Player overrides are stored by Save/Load & Settings (Vertical Slice). Validation requires every action to have at least one keyboard binding and at least one gamepad binding, and forbids the same key or button being bound to two actions on the same device. Mouse bindings are fixed and not remappable.

**8. Remapping (Vertical Slice).** The MVP ships the defaults only. The remap screen arrives in the Vertical Slice and edits overrides only: the defaults can always be restored. A "swap confirm/cancel" setting (for Nintendo-style habits) is part of the same screen.

**9. Devices coming and going.** If the active gamepad disconnects, Input broadcasts `device_lost`. When any gamepad reconnects, it broadcasts `device_restored`. When the game window loses or regains focus, it broadcasts `focus_lost` / `focus_gained`. While the window is unfocused, gamepad input is ignored, so a pad on the desk doesn't play the game in the background.

**10. Single player, any pad.** Any connected gamepad controls the game. The first pad to send meaningful input becomes the active one. Keyboard and mouse work at all times alongside it.

**11. Device identity.** Keyboard and mouse are identified by Godot's dedicated device-ID constants (`InputEvent.DEVICE_ID_KEYBOARD` / `DEVICE_ID_MOUSE`, Godot 4.7), never by device `0`, which some gamepads also use.

### States and Transitions

| State | Meaning | Changes to | When |
|---|---|---|---|
| Active: keyboard_mouse | Prompts show keys and mouse | Active: gamepad | A gamepad button press, or a stick or trigger past its deadzone |
| Active: gamepad | Prompts show pad buttons in that pad's style | Active: keyboard_mouse | A key press, a mouse click, or mouse movement of at least `pointer_switch_px` |
| Active: gamepad | — | Active: keyboard_mouse, plus `device_lost` | The active pad disconnects |
| (focus) Focused | All devices read | Unfocused, plus `focus_lost` | Window loses focus; gamepad input is ignored until `focus_gained` |

The game starts in `keyboard_mouse` (the primary input on PC).

### Interactions with Other Systems

| System | Gets from Input | Gives to Input |
|---|---|---|
| Game State & Scene Flow | All actions; `device_lost`, `device_restored`, `focus_lost`, `focus_gained` | Nothing. Input does not depend on it (Game State GDD, Dependencies) |
| Overworld Exploration & Encounters | `move` vector, `confirm` (interact), `menu` (via Game State routing) | — |
| Turn Battle System | `confirm`, `cancel`, `inspect`, `page_left/right`, `fast_forward` (via routing) | — |
| Dialogue, Banter & Quests | `confirm` (advance), `fast_forward`, `cancel` (where a choice can be backed out of) | — |
| UI Framework | Navigation repeat steps, pointer events, `active_device_changed` (for button prompts) | Focus sync requests (rule 3) |
| Save/Load & Settings (Vertical Slice) | Binding validation results | Player binding overrides |
| Content Data Definitions | — | Default bindings record (rule 7) |

## Formulas

> `systems-designer` and `ux-designer` not consulted (lean mode). The defaults below are common genre values to tune by feel on the development PC.

The stick_output formula (radial deadzone) is defined as:

`stick_output = 0 if |raw| < deadzone, else raw / |raw| × min(1, (|raw| − deadzone) / (1 − deadzone))`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| raw | Vector2 | each axis −1.0–1.0 | calculated (device) | Raw stick position |
| deadzone | float | 0.10–0.30 (default 0.20) | data file | Radius below which the stick reads as centered |
| stick_output | Vector2 | magnitude 0.0–1.0 | calculated | Rescaled stick value used by `move` |

**Output Range:** magnitude 0 at or inside the deadzone, rising smoothly to 1 at full tilt. There is no jump at the deadzone edge.
**Example:** raw = (0.60, 0), deadzone 0.20 → (0.60 − 0.20) / 0.80 = 0.50 → stick_output = (0.50, 0).

The menu_repeat_times formula is defined as:

`step_time(k) = 0 for k = 0; repeat_delay + (k − 1) × repeat_interval for k ≥ 1`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| k | int | 0+ | calculated | Index of the navigation step since the direction was pressed |
| repeat_delay | float (s) | 0.25–0.60 (default 0.40) | data file | Wait before the first repeat |
| repeat_interval | float (s) | 0.05–0.15 (default 0.08) | data file | Time between repeats after that |
| menu_stick_threshold | float | 0.40–0.80 (default 0.60) | data file | Stick magnitude along an axis that counts as a menu direction (after deadzone rescale) |
| pointer_switch_px | int (px) | 4–32 (default 8) | data file | Mouse movement needed to switch the active device to keyboard_mouse |

**Output Range:** 1 step at press; then about 12.5 steps per second at the default interval, after a 0.40 s pause.
**Example:** a direction held for 1.0 s produces steps at 0, 0.40, 0.48, 0.56, … 0.96 s, so 1 + 8 = 9 steps.

## Edge Cases

**Simultaneous and conflicting input**
- **If `confirm` and `cancel` are pressed in the same frame**: both are reported in the order received, and the receiver handles them in that order. Input never merges or drops actions.
- **If the keyboard and a gamepad press the same action in the same frame**: the action is reported once per press (two `pressed` events), and the active device becomes the one whose input arrived last.
- **If the same action is held on two devices and released on one**: the action stays held until every device holding it has released it. `released` fires only once, at the final release.
- **If opposite directions are held at once** (left and right): they cancel on that axis (`move.x` = 0) and menu repeat stops for that axis.
- **If the stick and the d-pad point different ways**: the input with the larger magnitude wins per axis. A d-pad press counts as magnitude 1. **On a tie, the d-pad wins**, as the deliberate digital input.
- **If the held menu direction changes** (a new direction pressed, or one of two opposing keys released so a single direction remains): that counts as a new press. One step fires immediately and the repeat timer restarts from `repeat_delay`.

**Devices**
- **If the active gamepad disconnects mid-hold** (e.g. while `fast_forward` is held): every action held on that pad is released immediately (`released` fires), then `device_lost` is broadcast. No action is left stuck down.
- **If a non-active gamepad disconnects**: nothing is broadcast, because the player isn't using it.
- **If the window loses focus while an action is held**: every held action is released, then `focus_lost` is broadcast.
- **If a key or button is still physically held when focus returns**: it does not count as held until it is released and pressed again. No action resumes "stuck down" after `focus_gained`.
- **If a gamepad reconnects while the window is unfocused**: `device_restored` is still broadcast, but its input is ignored until `focus_gained`.
- **If an unrecognized pad style connects**: `pad_style` is `generic`, and prompts show position-based glyphs (south, east, west, north).

**Mouse**
- **If the pointer clicks empty space or a non-interactive element**: Input reports `pointer_confirm` with the position as usual, and the UI Framework finds nothing interactive there, so nothing happens. A click never becomes a stray `confirm`.
- **If the mouse moves less than `pointer_switch_px`** (a bumped desk): the active device does not change. The distance is **cumulative**: total pointer movement since the last non-mouse input, reset whenever the active device changes.
- **If the mouse is used in the Overworld**: pointer input is ignored there (rule 3), apart from UI windows open on top.

**Bindings**
- **If the bindings data fails validation** (an action with no keyboard or gamepad binding, or a key bound to two actions): it is an error under Content Data Definitions rule 8, and the game does not start.
- **If a player override is invalid** (Vertical Slice; e.g. a corrupted settings file): the override is discarded, defaults are restored, and a single notice is raised at the moment it is discarded. The next launch loads cleanly, so there is no repeat notice. A broken override never makes the game uncontrollable.

## Dependencies

**Upstream (this system depends on):**

| System | Nature | Interface |
|---|---|---|
| Content Data Definitions | Soft (data only) | The default bindings record follows its ID and validation rules (rule 7). Input reads data; it does not call any Content Data logic beyond the catalog lookup |

There is no dependency on Game State & Scene Flow, by design (rule 2).

**Downstream (these systems depend on this one):**

| System | Nature | What it relies on |
|---|---|---|
| Game State & Scene Flow | Hard | Actions to route; `device_lost`, `device_restored`, `focus_lost`, `focus_gained` |
| Overworld Exploration & Encounters | Hard | `move`, `confirm` |
| Turn Battle System | Hard | `confirm`, `cancel`, `inspect`, paging, `fast_forward` |
| Dialogue, Banter & Quests | Hard | `confirm`, `fast_forward`, `cancel` |
| UI Framework | Hard | Navigation repeat, pointer events, `active_device_changed` |
| Save/Load & Settings | Soft (Vertical Slice) | Stores player binding overrides |

**Bidirectional notes:**
- Game State & Scene Flow lists Input System as a hard upstream dependency (provisional). This GDD now confirms that interface, and its action list (`confirm`, `cancel`, `menu`, directions) is a subset of rule 1.
- Content Data Definitions does not yet list the bindings record or Input as a consumer. Add Input to its Interactions table when that GDD is next revised.
- The systems index lists Input with no dependencies. It should gain a *soft* dependency on Content Data Definitions.

## Tuning Knobs

All knobs are data (the `bindings_default` record and the input config, ADR-0003); none is a code literal.

| Knob | Default | Safe range | Too low | Too high | Bound by |
|---|---|---|---|---|---|
| `deadzone` | 0.20 | 0.10–0.30 | Worn sticks drift the leader | Small tilts are ignored; slow walking is hard | `stick_output` |
| `repeat_delay` | 0.40 s | 0.25–0.60 | One tap skips two menu entries | Long lists feel sticky | `menu_repeat_times` |
| `repeat_interval` | 0.08 s | 0.05–0.15 | Held directions overshoot | Long lists drag | `menu_repeat_times` |
| `menu_stick_threshold` | 0.60 | 0.40–0.80 | A diagonal nudge moves the menu | Menus need a hard push | Applied after the deadzone rescale |
| `pointer_switch_px` | 8 px | 4–32 | A bumped mouse swaps every prompt to keyboard glyphs | Mouse users see pad prompts after moving the mouse | Device switching (rule 3) |
| Default bindings | `bindings_default` | Any conflict-free set | — | — | Validated at boot (ADR-0003, ADR-0004) |

**How the knobs interact.** `deadzone` rescales the stick before `menu_stick_threshold` is tested, so raising the deadzone also makes menu navigation by stick feel heavier. `repeat_delay` and `repeat_interval` together set how fast a held direction crosses a list (Formulas example: 9 steps in 1.0 s).

> Retrofit 2026-10-23 (commit-hook gap at `workflow: full`), collected from the Formulas variable tables; no value changed.

## Visual/Audio Requirements

None of its own. Button-prompt art (keyboard keys, mouse, and Xbox / PlayStation / Nintendo / generic pad glyphs) belongs to the UI Framework and follows the art bible's UI palette. There is no controller rumble in MVP (see Open Questions).

## Game Feel

- **Zero perceived lag:** an action is reported in the same frame the device reports it. Input adds no buffering or smoothing beyond the deadzone rescale.
- **Menus fly but don't overshoot:** the 0.40 s repeat delay stops a single tap from skipping two entries, and the 0.08 s interval scrolls long lists quickly. Both are tuned by feel.
- **Prompts never lie:** the moment the player touches a different device, every on-screen prompt matches it. A prompt showing the wrong device makes a turn-based game feel broken.
- **Fast-forward never costs a punchline by accident.** In a battle replay, one tap of `fast_forward` or `confirm` speeds up the rest of that replay's beats, knockouts included, and `cancel` returns it to normal speed at once; the next replay always starts at normal speed. A knockout's slump hold always plays at normal speed, so the punchline still lands. No press ever speeds the first boss entrance unless the player has turned on "Speed up boss entrances" (Sprite & Camera Presentation rules 9 and 13). In Dialogue, holding `fast_forward` speeds text and letting go returns it to normal. That matters for a comedy game where players will want to see the punchlines.

## UI Requirements

- **Button prompts** everywhere an action is shown, drawn for the active device and `pad_style` (rule 4).
- **Focus sync:** hovering with the mouse moves keyboard/gamepad focus to the same element once the pointer has moved `pointer_switch_px` since the screen opened (rule 3).
- **Remap screen (Vertical Slice):** lists every action with its keyboard and gamepad bindings, captures a new key or button, rejects conflicts with a clear message, has "Restore defaults", and includes "swap confirm/cancel".

> **📌 UX Flag — Input System**: This system has UI requirements (button prompts, focus sync, and the Vertical Slice remap screen). In Pre-Production, run `/ux-design` for the remap screen and the prompt conventions before writing epics.

## Cross-References

| This GDD references | Document | What is referenced |
|---|---|---|
| Input is a pure device → action layer; actions routed by Game State; `device_lost`, `focus_lost` | `design/gdd/game-state-scene-flow.md` | Rule 2, Dependencies (Input System row), Edge Cases (focus loss) |
| Bindings as validated data; stable IDs | `design/gdd/content-data-definitions.md` | Rules 2 and 8 |
| KB/M primary, full gamepad, d-pad navigable menus | `.claude/docs/technical-preferences.md` | Input & Platform |
| `DEVICE_ID_KEYBOARD` / `DEVICE_ID_MOUSE`; separate mouse and keyboard focus; SDL3 pads | `docs/engine-reference/godot/` (`breaking-changes.md` 4.6→4.7, `modules/input.md`) | Engine behavior relied on |
| Remapping as an accessibility commitment | `design/art/art-bible.md` §4 (colorblind and accessibility rules); `design/gdd/systems-index.md` (UI Framework includes accessibility) | Accessibility scope |

## Acceptance Criteria

Harness: synthetic device events (including a gamepad that reports device ID 0), an injectable clock with a fixed tick, and a recorder of emitted actions and signals, with **no consumer attached** (Input is tested alone). Expected values are **computed from the config** using the Formulas, never hardcoded. Each formula test also runs once with a non-default config, to prove nothing is hardcoded. Vector comparisons use a tolerance of 1e-6. Ordering contract: for a disconnect or focus loss, every `released` comes before the `device_lost` / `focus_lost` signal.

Evidence: **[L]** Logic (gdUnit4, `tests/unit/input/`). UI evidence for button prompts belongs to the UI Framework GDD. The behavior of Game State when it receives `device_lost` is tested in the Game State GDD.

**Bindings and actions**
- **AC-1 [L]** Parametrized over every default binding (all 8 actions, keyboard and gamepad): press emits `pressed` for that action, release emits `released`.
- **AC-2 [L]** Holding `fast_forward` emits exactly one `pressed`, `held` on every tick while held, and exactly one `released` on release. A one-tick tap emits exactly one `pressed` and one `released`. A keyboard key held through the operating system's key-repeat, with synthetic echo events injected, emits no second `pressed`, for `fast_forward` and `confirm` alike.
- **AC-3 [L]** Validation reports an error for an action with no keyboard binding, an action with no gamepad binding, and a key bound to two actions. A valid default set reports zero errors.

**Movement and analog**
- **AC-4 [L]** A single key or d-pad direction yields magnitude 1. Two diagonal keys (W+D) yield length 1 within tolerance.
- **AC-5 [L]** Deadzone cases, expected values from the formula: raw at exactly `deadzone` gives 0; raw at `deadzone + ε` gives magnitude at most ε / (1 − deadzone); a diagonal raw input keeps its direction; raw (0.60, 0) gives the formula value; raw magnitude above 1 is clamped to 1. The deadzone applies to the vector's magnitude, not per axis.
- **AC-6 [L]** Opposite directions held together give 0 on that axis. Stick and d-pad on the same axis: the larger magnitude wins. At equal magnitude, the d-pad wins.

**Menu repeat**
- **AC-7 [L]** A direction held for T seconds produces steps exactly at the times given by `step_time(k)` for every k with `step_time(k) ≤ T` (a step due exactly at T counts). Releasing stops further steps.
- **AC-8 [L]** Changing the held direction mid-repeat fires one immediate step and restarts the timer from `repeat_delay`.
- **AC-9 [L]** A stick at `menu_stick_threshold − ε` along an axis produces no menu step; at `+ ε` it produces one.

**Active device**
- **AC-10 [L]** Separate tests, each emitting exactly one `active_device_changed` with the expected kind: key press, then pad button (gamepad); stick past the deadzone (gamepad); mouse click (keyboard_mouse); cumulative mouse movement reaching `pointer_switch_px` (keyboard_mouse).
- **AC-11 [L]** No `active_device_changed` fires for: stick movement inside the deadzone; cumulative mouse movement below `pointer_switch_px`; a second input from the already-active kind.
- **AC-12 [L]** Each recognized pad type reports its `pad_style` (`xbox`, `playstation`, `nintendo`). An unrecognized pad reports `generic`.
- **AC-13 [L]** A gamepad reporting device ID 0 makes the active device `gamepad`. A key press makes it `keyboard_mouse`, identified by the keyboard device-ID constant.

**Devices and focus**
- **AC-14 [L]** The active pad disconnects while `fast_forward` is held: `released(fast_forward)` is emitted, then `device_lost`.
- **AC-15 [L]** A non-active pad disconnects (including while it holds an action): no `device_lost`. Any of its held actions are released only if no other device still holds them.
- **AC-16 [L]** A pad reconnects: `device_restored` is emitted, including while unfocused.
- **AC-17 [L]** Focus is lost while an action is held: `released` is emitted, then `focus_lost`. Pad input while unfocused emits nothing. After `focus_gained`, a key still physically held emits nothing until it is pressed again.

**Concurrency**
- **AC-18 [L]** `confirm` and `cancel` pressed in the same frame: both emitted, in input order.
- **AC-19 [L]** The same action held on two devices: releasing one emits nothing; releasing the second emits exactly one `released`.

**Mouse**
- **AC-20 [L]** With no consumer attached, a left click emits `pointer_confirm` with its position, a right click emits `pointer_cancel`, and wheel up and wheel down emit steps of opposite sign.
- **AC-21 [L]** No pointer event ever produces a `move` action (no click-to-move).

**Overrides (Vertical Slice)**
- **AC-22 [L] [VS]** An invalid player override is discarded, defaults are active, and exactly one notice signal is emitted. On the next load, zero notices are emitted.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Esc opens the menu?** Esc is bound to `cancel`. PC players expect Esc to open the menu on the overworld. Should Game State treat `cancel` with nothing to cancel (in Overworld or Camp) as `menu`? | user + Game State & Scene Flow GDD | Next revision of the Game State GDD |
| 2 | **Controller rumble**: none in MVP. Wanted for combo punchlines or boss hits? | user + game-designer | Vertical Slice |
| 3 | **Default key choices** (Z/X, I/Q, 1/3, Shift) were picked without `ux-designer`; validate them in the first playtest. | user + ux-designer | First playable |
| 4 | ~~**Engine setting**: Godot 4.7's "Ignore Joypad on Unfocused Application" may implement rule 9 directly; confirm in the ADR.~~ **Resolved (ADR-0003, Proposed):** `input_devices/joypads/ignore_joypad_on_unfocused_application` exists on 4.7.2 (verified). It is enabled as a backstop, and the resolver's own focus gate still implements rule 9. | `/architecture-decision` (godot-specialist) | Technical Setup |
