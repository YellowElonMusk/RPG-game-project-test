# Story 058: The menu input guard refuses presses for its full window

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: UI Framework
**ADR Decision Summary**: §6's `MenuGuard` is pure logic, with an injected clock and held-action-set source, that returns `PASS`, `REFUSE` or `SWALLOW` for every menu-action press for `PresentationConfig.input_guard` seconds after a screen opens; it also owns carry-over (held-at-open actions never fire) and the pointer-focus switch threshold.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `MenuGuard` is required on exactly four screens (command menu, target selection, Defeat Prompt, results screen); other screens may use it but are not required to. A `GuardBlocker` full-rect `MOUSE_FILTER_STOP` `Control` must be the last child of `screen_root` for the guard's duration, and `screen_root` and every overlay root must be a plain `Control` (never a `Container`), or the blocker collapses.

**Control Manifest Rules (this layer)**:
- Required: `MenuGuard` is required on the command menu, target selection, the Defeat Prompt and the results screen (ADR-0008 §6)
- Required: An action held at `open()` returns `SWALLOW` until its release, with no feedback; releases return `PASS` and are never mirrored (ADR-0008 §6)
- Required: OS key-repeat echoes never arrive as new presses, because the resolver emits one `pressed` per physical press (ADR-0008 §6, Input rule 2/TR-input-007)
- Forbidden: `screen_root` or an overlay root's direct full-rect children (`GuardBlocker` included) being a `Container` — it collapses them

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-54 [L]** (P-05) (menu input guard) For the command menu, target selection, the Defeat Prompt and the results screen, on the mode-time clock at `dt = 1/60`, with a test config of `input_guard = 9.5 / 60` s:
  - **During the guard:** a press of Confirm, Cancel, a direction, or a pointer click on frames 1 to 9 after the screen opens changes nothing, and each produces exactly one refusal event.
  - **After the guard:** a new press on frame 10 or later is accepted.
  - **Held inputs:** a Confirm held since before the screen opened never confirms, however long it is held. A direction held since before it opened never moves the focus, through any number of repeat intervals, until it is released and pressed again.
  - **Echoes:** OS key-repeat echo events are never presses.
  - **Pointer:** a pointer resting over a non-default button as the screen opens leaves the default focus in place. A pointer moving `pointer_switch_px − 1` px in total leaves it too. Reaching `pointer_switch_px` moves the focus to the button under it.
  - **Default focus:** in the command menu, the member's last-used command if it is available and costs no MP, otherwise Attack. In target selection, the first living target. In the Defeat Prompt, Retry. On the results screen, its continue option.

---

## Implementation Notes

*Derived from ADR-0008 Implementation Guidelines:*

`MenuGuard.open(screen_root)` records `t_open`, snapshots the held-action set, and raises a `GuardBlocker`; `filter(action, pressed)` returns `PASS`/`REFUSE`/`SWALLOW` per §6's rules. This story is the exhaustive test of that pure logic against the four required screens' default-focus rules.
- `input_guard` seconds come from `PresentationConfig` (ADR-0005 owns the knob; `9.5/60` s is the test's fixture value, not the shipped default).
- A `REFUSE` press and a `GuardBlocker` click both call `ui.feedback.refuse(focused_control)` exactly once per press (ADR-0008 §7).
- Held-direction carry-over goes through `UiService`'s own per-frame mirror of `resolver.get_move_vector()` (§6): a direction counts as "held at open" the same way a button does, and its release/re-press cycle is derived, not read from a resolver signal.
- `PointerFocusSync`'s pointer counter resets on `MenuGuard.open()` (§6); the `pointer_switch_px − 1` vs. `pointer_switch_px` boundary is an exact `<` / `≥` check, not approximate.
- Default focus per screen is a lookup the guard's caller supplies, not something `MenuGuard` itself decides — this story tests that each of the four screens wires the correct default in.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-074-replay-indicator-and-refusal-pulse-screenshots.md`: the refusal pulse's visual/UI evidence
- The settings/remap screens, which may use `MenuGuard` but are not required to (ADR-0008 §6)

---

## Files

- `src/ui/menu_guard.gd`
- `src/ui/ui_feedback.gd`
- `src/ui/pointer_focus_sync.gd`
- `tests/unit/ui/menu_guard_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/ui/menu_guard_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: `production/epics/sprite-camera-presentation/story-074-replay-indicator-and-refusal-pulse-screenshots.md` (the refusal pulse this story's guard triggers)
