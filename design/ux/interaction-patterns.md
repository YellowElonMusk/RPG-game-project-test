# Interaction Pattern Library

> **Status**: In Design
> **Author**: user + ux-designer (`/ux-design patterns`, autonomous mode)
> **Last Updated**: 2026-10-22
> **Template**: Interaction Pattern Library

---

## Overview

This library names every reusable interaction in *Go back to your planet!*, so
per-screen UX specs reference a pattern by name instead of re-specifying it.
Each pattern says what the player experiences, how the input maps, what
feedback they get, and which accessibility commitments it carries
(`design/accessibility-requirements.md`, Standard tier).

**Source of these patterns.** No per-screen UX spec exists yet. Every pattern
below is taken from decisions that are already Accepted or designed:
- ADR-0003 (Input System): routed input, re-injected `ui_*` navigation;
- ADR-0006 (Battle Replay): beats, latch, gated menus;
- ADR-0008 (UI Framework): `FocusScope`, `MenuGuard`, `PointerFocusSync`, `UiFeedback`, `PromptFacade`, backdrops, transitions;
- ADR-0010 / ADR-0011: command checks, rule text;
- `input-system.md`, `sprite-camera-presentation.md` (rules 9, 13) and `game-state-scene-flow.md` (Menu overlay, Defeat Prompt, Retry/Retreat).

The patterns are therefore normative for implementation even before a screen
spec cites them. If a screen spec needs to deviate, it must say so and name the
pattern.

**Device model (applies to every pattern).** There are eight actions:
`confirm`, `cancel`, `menu`, `fast_forward`, directions, `page_*`, plus derived
`nav_*`. They are bound per device from data (ADR-0003). Keyboard and gamepad
drive everything; the mouse adds pointing and clicking (`pointer_confirm` /
`pointer_cancel`, `wheel_step`). Prompts always show the active device's
glyphs. No pattern requires a held or simultaneous input, and none is timed
against the player.

---

## Pattern Catalog

| # | Pattern | Category | One-line description |
|---|---|---|---|
| P1 | Focus-Scoped Menu | Navigation | A list or grid of native controls navigated by direction keys / d-pad / stick, with one visible focus |
| P2 | Guarded Menu | Input | A focus-scoped menu that refuses presses carried over from the previous screen or arriving within `input_guard` |
| P3 | Refusal Feedback | Feedback | A press that changes nothing pulses the control and ticks, never silently fails |
| P4 | Disabled Option with Reason | Data Display | An unavailable command stays visible, marked non-color, with the reason it can't be used |
| P5 | Pointer Focus Sync | Input | Mouse hover moves keyboard focus only after real movement (`pointer_switch_px`); a click focuses with hidden focus |
| P6 | Device-Aware Prompt | Feedback | Button prompts show the glyph for the device last used, and switch live |
| P7 | Overlay with Backdrop | Overlay | An overlay opens over a frozen world with a full-screen click-blocking backdrop and owns focus until closed |
| P8 | Pausing Menu | Modal | The Menu overlay stops mode time in Overworld, Camp and Battle |
| P9 | Input-Locked Transition | Navigation | During a mode transition, no input is accepted and a curtain blocks the pointer |
| P10 | Beat Replay with Latch | Feedback | Battle outcomes play beat by beat; one tap speeds up the rest of the replay without skipping a beat |
| P11 | Replay Indicator | Feedback | A small passive prompt shows the replay's speed state; clicking it toggles the latch |
| P12 | Rule Banner with Tooltip | Data Display | The active faction rule is always on screen as text, with a longer explanation on focus |
| P13 | Floating Number | Feedback | Damage and heals appear as signed numbers over the target, duplicated in the HP readout |
| P14 | Confirm-Gated Text | Modal | Dialogue, results and notices wait for `confirm`; nothing actionable auto-dismisses |
| P15 | Binary Choice Prompt | Modal | A two-option decision (Retry / Retreat) with a safe default focus |
| P16 | Settings Row | Input | One setting per row: left/right changes a value live, with the value always shown as text |
| P17 | Binding Capture | Input | The remap screen waits for one key or button press, rejects conflicts with a message, and can always restore defaults |
| P18 | One-Shot Notice | Feedback | A single message about something the game fixed (e.g. discarded bindings), shown once on Title |

---

## Patterns

### P1. Focus-Scoped Menu

**Category**: Navigation
**Used In**: battle command menu, target selection, Menu overlay pages, Title, settings, Defeat Prompt, results (planned screens; ADR-0008 §5)

**Description**: The standard way to choose among options. A set of native
`Control`s inside one `FocusScope`, navigated with directions. One control has
focus at a time, and focus never leaves the scope while the screen is open. Use
it for every list, grid or row of choices.

**Specification**:
- Directions move focus one step on press. A held direction repeats after `repeat_delay` (0.40 s) at every `repeat_interval` (0.08 s). A stick counts once it passes `menu_stick_threshold` (`input-system.md` rules 5–6).
- `confirm` activates the focused control. `cancel` backs out one level, or does nothing at the top level (no surprise exits).
- Navigation is re-injected into native focus only while focus is inside the scope, as an atomic press-then-release pair (ADR-0003). Focus wrap-around is per-screen, and the spec must state it.
- On open, `UiService` gives focus to the scope's safe default. A screen never grabs focus in its own `_ready()` (ADR-0008 §5).
- Focus is drawn with the `focus` stylebox as the single "selected" indicator; it has a shape (frame/cursor), not only a tint. Hover uses only the `hover` stylebox.

**Accessibility**: Fully operable by keyboard alone and gamepad alone. The
focus indicator is non-color. Native controls expose names and roles to
AccessKit, and focus order must match visual order.

**When to Use**: any choice among on-screen options.
**When NOT to Use**: free movement in the overworld (that is `get_move_vector()`, not focus); text entry (none planned).

**Reference**:
```
 ┌──────────────┐
 │ ▶ Attack     │   ▶ = focus (shape + stylebox)
 │   Defend     │
 │   Specials   │
 │   Items      │
 └──────────────┘
```

---

### P2. Guarded Menu

**Category**: Input
**Used In**: battle command menu, target selection, Defeat Prompt, results screen (ADR-0008 Implementation Guidelines; `sprite-camera-presentation.md` rule 9)

**Description**: A P1 menu that protects high-stakes choices from presses that
weren't meant for it: a `confirm` still held from the previous screen, a mashed
fast-forward running into the command menu, or a press in the first instant
after the menu appears.

**Specification**:
- Menu actions go through `MenuGuard.filter()`, then `UiNavigator.route()`.
- A press is refused if its action was already held when the menu opened (carry-over), or arrives within `input_guard` (0.15 s, data) of the menu opening. A new press of the same action after release is accepted.
- Every refused press gets P3 Refusal Feedback. It never executes, and it is never buffered for later.

**Accessibility**: Protects players with tremor or with motor-planning
difficulty from accidental commits. The guard is short and is not a timing
window the player has to hit.

**When to Use**: any menu that appears automatically after an animation or replay and whose choice is consequential.
**When NOT to Use**: menus the player opens deliberately (settings, Menu pages): plain P1.

---

### P3. Refusal Feedback

**Category**: Feedback
**Used In**: every guarded menu (P2), disabled options (P4), the replay latch when a press changes nothing (P10)

**Description**: When a press does nothing, the player is told, so that "the
game ignored me" never happens.

**Specification**:
- `UiFeedback.refuse(control)`: a short pulse on the control plus the UI refusal tick (ADR-0008 §7).
- A refusal never reveals hidden focus, and never moves focus.
- The pulse is a scale or outline change, not a flash (it is not a flash-gate source).

**Accessibility**: Visual and auditory together. The pulse alone is
sufficient (SFX audit, `accessibility-requirements.md`).

**When to Use**: any accepted-but-ineffective press.
**When NOT to Use**: as an error dialog. If the player needs an explanation, use P4's reason line.

---

### P4. Disabled Option with Reason

**Category**: Data Display
**Used In**: battle command menu (Specials when MP is short, moves the faction rule forbids), target selection

**Description**: An option the player can't use right now stays in the list, so
the menu shape never jumps. It is visibly unavailable, and the reason is shown.

**Specification**:
- Availability comes from `BattleCore.check_command()` (ADR-0010 §2). The same check `submit_action()` uses, so the menu never offers what the core would reject.
- Unavailable: dimmed **and** marked with a non-color glyph (lock or strike-through). Focusing it shows `CommandCheck.reason` as one line of text (e.g. "Not enough MP", or the faction rule's own wording).
- Confirming it gets P3 Refusal Feedback.

**Accessibility**: Never grey-only (color-only audit row). The reason is text,
readable by AccessKit through `accessibility_description`.

**When to Use**: options that are temporarily unavailable.
**When NOT to Use**: options that never apply in this context; hide those instead.

---

### P5. Pointer Focus Sync

**Category**: Input
**Used In**: every P1 menu when a mouse is used (ADR-0008 §6, `input-system.md` rule 3)

**Description**: The mouse and the keyboard/gamepad share one focus without
fighting. Hovering doesn't steal focus from a player who is using the keyboard
and nudged the mouse. A click selects exactly what was clicked.

**Specification**:
- Hover moves focus only after the pointer has moved `pointer_switch_px` since the last keyboard/gamepad navigation.
- A click focuses with **hidden** focus (no ring) and activates. The next keyboard/gamepad navigation reveals focus and continues from the clicked control.
- Every `grab_focus()` states `hide_focus`: `true` for pointer-driven grabs, visible for key and pad.

**Accessibility**: Tremor-tolerant. Keyboard users never lose their place to an accidental mouse movement.

**When to Use**: automatically, in every P1 menu.
**When NOT to Use**: n/a.

---

### P6. Device-Aware Prompt

**Category**: Feedback
**Used In**: battle HUD prompts, the replay indicator, dialogue "continue" prompts, the remap screen

**Description**: Wherever the UI tells the player which button to press, it
shows the glyph for the device they last used, and it switches the moment they
pick up another device.

**Specification**:
- Glyphs come only from `UiContext.prompts` (`PromptFacade`): device kind, pad style (Xbox / PlayStation / Nintendo / generic) and the bound input's glyph, honouring remapping (`get_bindings()`), ADR-0003/0008 §4.
- Updates on `active_device_changed(kind, pad_style)` with no restart.
- Keyboard glyphs use the player's keyboard layout (`keyboard_get_label_from_physical()`).

**Accessibility**: Required by "Input method switching" (Standard). Prompt text has an `accessibility_name` with the action name, not the glyph.

**When to Use**: every button prompt.
**When NOT to Use**: never hardcode a glyph or a key name in text; use a prompt token.

---

### P7. Overlay with Backdrop

**Category**: Overlay
**Used In**: Menu overlay, Defeat Prompt, results screen, dialogue boxes over the world, confirmation dialogs

**Description**: A layer that opens over the current mode. The world stays
visible but frozen and blurred behind it (art bible: menus over a frozen,
blurred diorama). The overlay owns input until it closes.

**Specification**:
- The overlay root is a plain `Control` whose first child is a full-rect `MenuBackdrop` with `MOUSE_FILTER_STOP`. Clicks never reach the world (ADR-0003, ADR-0008 §6).
- Opening pushes focus onto the overlay focus stack; closing returns focus to where it was (`UiService`).
- The backdrop blur respects Reduce Blur. A backdrop fade that is a large-area luminance change books through the flash gate.

**Accessibility**: Reduce Blur and Reduce Flashing apply (rule 13). Focus return is predictable.

**When to Use**: anything modal over a mode.
**When NOT to Use**: a mode change (that is P9).

---

### P8. Pausing Menu

**Category**: Modal
**Used In**: the Menu overlay in Overworld, Camp and Battle (`game-state-scene-flow.md` rule 10)

**Description**: Opening the Menu pauses the game: animations, timers and
ambient motion all stop. In Battle it is the system menu (settings, quit).

**Specification**:
- `menu` opens it in Overworld, Camp and Battle. It is never available during a transition, in Boot or in Content Error.
- Mode time stops while it is open (`ModeHost` disabled, ADR-0002). UI animations keep running on the real clock.
- It is a P7 overlay, and its pages are P1 menus.

**Accessibility**: "Pause anywhere" (Basic). The restrictions are short, non-interactive states.

**When to Use**: the global pause and settings entry.
**When NOT to Use**: in-battle tactical info (that belongs on the HUD).

---

### P9. Input-Locked Transition

**Category**: Navigation
**Used In**: every mode change (Title → Overworld, encounter wipe into Battle, Retry, return to Overworld)

**Description**: While the game changes mode, input is locked, so a press can't
land in the half-built next screen.

**Specification**:
- Input locks at `transition_started` and unlocks after `transition_finished` (ADR-0002). `TransitionLayer` shows a full-rect pointer blocker the whole time.
- Lengths come from data (0.5 s Retry, 1.0 s battle wipes, 1.5 s fades). Flashing transitions book through the flash gate and play their capped variant if refused.
- The next screen's first menu is a P2 Guarded Menu, so presses held through the transition don't fire.

**Accessibility**: Reduce Flashing forces capped variants. Never more than about 1.5 s of locked input.

**When to Use**: mode changes only.
**When NOT to Use**: overlays (P7).

---

### P10. Beat Replay with Latch

**Category**: Feedback
**Used In**: battle (every command's resolution, the enemy phase, knockouts, the boss takeover)

**Description**: After the player commits a command, the round resolves
instantly in logic, then is **shown** beat by beat: wind-up, impact, reaction,
number. The command menu reopens only after the last beat. The player can speed
up the rest of the replay, but no beat is ever skipped.

**Specification**:
- One `fast_forward` or `confirm` press (or a click on P11) latches speed-up for the rest of this replay. `cancel` clears it. There is one latch level, and the latch never carries into the next replay (ADR-0006, rule 9).
- Presses during a replay are consumed by the latch, never buffered into the command menu.
- Faster battle animations (setting) makes every replay quicker. The latch is always faster still (`battle_speed_mult ≤ ff_mult − 0.25`).
- The first-encounter boss takeover is protected at 1× unless "Speed up boss entrances" is On.

**Accessibility**: Every outcome is visible (visual equivalent for all
audio). The pace is player-controllable without losing information (Reading
time). Hit-punch respects Screen Shake / Reduce Motion.

**When to Use**: any sequence of game outcomes the player must be able to read.
**When NOT to Use**: UI-only animation (that runs on the real clock).

---

### P11. Replay Indicator

**Category**: Feedback
**Used In**: battle HUD during replays

**Description**: A small on-screen marker that shows the replay is playing and
whether it is sped up, and doubles as a clickable fast-forward toggle.

**Specification**:
- States: passive (playing at the set pace), latched (sped up). Clicking toggles the latch.
- The click is its own signal, never `confirm` (ADR-0008 §12).
- A press that changes nothing triggers P3.

**Accessibility**: The state is shown by a glyph change, not color only.

**When to Use**: during battle replays only.
**When NOT to Use**: elsewhere.

---

### P12. Rule Banner with Tooltip

**Category**: Data Display
**Used In**: battle HUD (every faction fight), boss takeover

**Description**: The game's core joke and puzzle is the faction's rule, so the
rule is never something the player must remember. A banner states it in plain
text for the whole fight, and focusing or hovering it explains it.

**Specification**:
- The text comes from the faction rule's record templates (`get_banner_text()`, `get_tooltip_text()`, ADR-0011), read through `LocText`. It updates per round when the rule's state changes.
- The banner uses the faction color **and** the faction's shape icon (art bible §4).
- Combatant-specific notes (`get_combatant_tooltip_note()`) appear in the target's tooltip, e.g. "Not yet APPROVED".

**Accessibility**: Text, not color, carries the rule (color-only audit). It
supports Pillar 4 (Readable in One Turn).

**When to Use**: any active battle-wide rule.
**When NOT to Use**: per-action results (P13).

---

### P13. Floating Number

**Category**: Feedback
**Used In**: battle (damage, heals, MP upkeep)

**Description**: When a beat lands, a number rises from the target. It is
transient, and the value is always duplicated in the target's HP/MP readout.

**Specification**:
- Signed values (`−12` damage, `+12` heal), and a different motion for each (damage drops, heal rises).
- Minimum 8 logical px with a 1 px Outline Ink outline. Code-set text has `auto_translate_mode = DISABLED` on the leaf label (ADR-0013).
- Positioned through `ui.world_to_ui()` over the actor, in the mode's HUD `CanvasLayer`. It never shakes with the hit-punch.

**Accessibility**: Never color-only. Transient, but the information persists in the HP readout.

**When to Use**: any per-target numeric change.
**When NOT to Use**: the only display of a value.

---

### P14. Confirm-Gated Text

**Category**: Modal
**Used In**: dialogue and banter boxes, results screen, Combo Codex entries, tutorial prompts

**Description**: Text the player must read stays until they press `confirm`. A
first press while text is still revealing completes the reveal, and the next
press advances.

**Specification**:
- No auto-advance and no auto-dismiss for actionable or story text.
- Opaque window (navy/cream), speaker name on every line, size ≥ 10 logical px at text scale 1.0.
- A prompt glyph (P6) shows that more follows.

**Accessibility**: Reading time (Standard): text never leaves before the player is done.

**When to Use**: any text the player is meant to read in full.
**When NOT to Use**: ambient barks that carry no needed information. Those may time out, but must still use opaque windows.

---

### P15. Binary Choice Prompt

**Category**: Modal
**Used In**: Defeat Prompt (Retry / Retreat), quit confirmations, overwrite-save confirmations

**Description**: A two-option decision presented as a P2 Guarded Menu, with the
non-destructive option focused by default.

**Specification**:
- Default focus is the safe or most common choice (Retry on the Defeat Prompt; "No" on quit and overwrite).
- `cancel` selects the safe option's effect, or closes without acting; the spec must say which.
- It is a P7 overlay. Its appearance (the Defeat card) is flash-gated.

**Accessibility**: Guarded against carried-over presses (P2). The safe default limits the cost of a mistake.

**When to Use**: two-way consequential decisions.
**When NOT to Use**: more than three options (use P1).

---

### P16. Settings Row

**Category**: Input
**Used In**: settings screen: comfort settings (Faster battle animations, Speed up boss entrances, Screen Shake, Reduce Blur, Reduce Flashing, Reduce Motion), text scale, colorblind UI palette, volume sliders, brightness, locale

**Description**: One setting per row. Left and right change the value, the
current value is always shown as text, and the change applies immediately.

**Specification**:
- Rows are a P1 menu. Left/right (or `page_*`) step through values; sliders step in fixed increments.
- Changes apply live through `SettingsService.set_value()` and its views, and are saved after a short debounce (ADR-0009 §7).
- The value is shown as a word or number ("Reduced", "1.25×", "80%"), never only by a toggle color.

**Accessibility**: Values are text (color-only audit). Live preview lets players judge text scale and motion settings immediately.

**When to Use**: every option in settings.
**When NOT to Use**: binding changes (P17).

---

### P17. Binding Capture

**Category**: Input
**Used In**: the remap screen (Vertical Slice; `input-system.md` rule 8, UI Requirements)

**Description**: Choosing an action's row enters capture. The next key or
button pressed becomes the binding, unless it conflicts.

**Specification**:
- Capture runs through the `InputCapture` facade only (ADR-0008/0009). Overrides only: "Restore defaults" is always available.
- A conflicting input is rejected with a clear message naming the action that already uses it. Nothing is silently swapped.
- A "swap confirm/cancel" option is provided. `cancel` during capture exits capture without changing anything (the spec must define how `cancel` itself is rebound).

**Accessibility**: Full input remapping (Standard).

**When to Use**: remapping only.
**When NOT to Use**: n/a.

---

### P18. One-Shot Notice

**Category**: Feedback
**Used In**: Title (discarded or invalid binding overrides, corrupted settings replaced by defaults)

**Description**: When the game repairs something on the player's behalf, it
tells them once, plainly, and never again.

**Specification**:
- Notices queue in `SettingsService.pending_notices()` and are drained on Title (ADR-0009 §7). Each shows once as P14 Confirm-Gated Text.
- The text says what changed and what the player can do ("Your custom controls couldn't be loaded and were reset. You can set them again in Settings → Controls.").

**Accessibility**: Never auto-dismissed. Plain language.

**When to Use**: automatic repairs the player should know about.
**When NOT to Use**: errors the player can't act on; log those (Content Error has its own screen).

---

## Gaps & Patterns Needed

| Gap | Needed by | Notes |
|---|---|---|
| Overworld interaction prompt ("talk", "open") | Overworld Exploration & Encounters | Waits for the Overworld GDD (ADR-0012 is Proposed). Must use P6 prompts and no held input |
| Encounter warning (symbol / zone) | Overworld | Must be visual, never audio-only (accessibility SFX rule) |
| Quirk state badge + inspection | Quirk State System | Icon + name, never color-only; inspection is probably a P1 target-info panel |
| Combo discovery banner and Codex browsing | Combo System & Codex | A banner pattern plus a Codex list; discovery may reuse P14 |
| Party swap at camp | Camp & Party Management | Likely a two-list P1 variant |
| Shop / inventory compare | Items, Equipment & Shops (Vertical Slice) | Stat deltas with +/− signs |
| Save slot list | Save/Load & Settings | Slot summaries (P1) plus P15 for overwrite |
| Screen-reader announcements for P10/P13 | Accessibility OQ-1 / OQ-4 | Depends on the menu screen-reader decision |
| Tab / page navigation inside the Menu | Menu overlay | `page_*` actions exist; the pattern isn't specified |

---

## Open Questions

| Question | Owner | Resolution |
|---|---|---|
| Does `cancel` at a top-level P1 menu do nothing (current proposal), or open the Menu? | ux-designer | Unresolved; settle in the battle HUD UX spec |
| Should P1 lists wrap around at the ends? | ux-designer | Unresolved; per-screen for now |
| P14: should a held `confirm` fast-forward text reveal (like P10), or only single presses advance? Holding must never be required. | ux-designer | Unresolved |
| Patterns were derived from ADRs and GDDs, not from UX specs. Re-run `/ux-design patterns` after the first screen specs (battle HUD, Menu, Title) to reconcile. | ux-designer | Open |
