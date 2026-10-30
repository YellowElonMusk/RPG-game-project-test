# Story 009: With no consumer attached, left click, right click and the wheel emit raw `pointer_confirm`, `pointer_cancel` and opposite-sign wheel steps

> **Epic**: Input System
> **Status**: Complete (2026-10-30)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-006`, `TR-input-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (§5 mouse is native, §8 pointer signals); ADR-0008: UI Framework (§6, consumer: `pointer_position` polling)
**ADR Decision Summary**: Input passes the raw pointer to the UI: clicks and wheel notches become `pointer_confirm`/`pointer_cancel`/`wheel_step` signals plus a `pointer_position` getter, from fixed code outside the binding table. Input never decides what is clickable; the UI Framework turns clicks on interactive elements into actions.
**ADR Version**: ADR-0003 2026-10-21; ADR-0008 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: `DEVICE_ID_MOUSE` is post-cutoff (4.7). Verified as the default `device` on a synthetic `InputEventMouseButton` (spike item 1). Godot delivers each wheel notch as a pressed + released `InputEventMouseButton` pair.

**Control Manifest Rules (this layer)**:
- Required: "**`InputSystem` never calls `set_input_as_handled()`, and the resolver ignores `InputEventAction`**"
- Forbidden: "**Never use `event.device == 0` to mean mouse/keyboard** — since 4.7 they no longer report device `0`"
- Required: "**The resolver reference never leaves `GameStateMachine` and `UiService`.** Widgets (HUD prompt glyphs) reach the active device, pad style and glyphs only through `UiContext.prompts` (`PromptFacade`, which exposes no pointer data and no held state)"

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [x] **AC-20** With no consumer attached, a left click emits `pointer_confirm` with its position, a right click emits `pointer_cancel`, and wheel up and wheel down emit steps of opposite sign.

---

## Implementation Notes

*Derived from ADR-0003 §5, §8 and ADR-0008 §6:*

- **Pointer signals.** The signals are `pointer_confirm(position: Vector2)`, `pointer_cancel(position: Vector2)` and `wheel_step(direction: int)` (+1 up, −1 down). `pointer_position` is a getter updated on every `InputEventMouseMotion` and `InputEventMouseButton`.
- **Event-pair rules (pinned, QL-STORY-READY 2026-10-23):**
  - `pointer_confirm`/`pointer_cancel` fire on the press edge only (`pressed == true`) with `event.position`. The release emits nothing.
  - `wheel_step` fires once per `MOUSE_BUTTON_WHEEL_UP`/`DOWN` event with `pressed == true` (+1/−1). The paired release emits nothing. `factor` is ignored.
  - Middle, X1/X2 and wheel left/right emit no pointer signal.
- **Raw only.** Input never decides what is clickable. A click on empty space still emits `pointer_confirm`. The UI Framework turns a click on an interactive element into `confirm`/`cancel`. A click never emits `action_pressed(confirm)`.
- **Mouse is not in the binding table.** Mouse buttons map to pointer signals in fixed code, and the validator (story 003) rejects mouse tokens.
- **Native GUI.** The shell never calls `set_input_as_handled()`, so the native GUI also receives clicks (spike item 2). That is the shell's concern (story 025).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 012: device switching on click.
- Story 010: pointers never affecting `move`.
- UI Framework epic: hover focus (TR-input-009, ADR-0008 §6).

---

## Files

- `src/input/input_resolver.gd`
- `tests/unit/input/input_pointer_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, fixes applied: press-edge clicks, wheel press/release pair, reported position). The developer implements against these — do not invent new test cases during implementation.*

**AC-20** — raw pointer signals with no consumer attached.

```
Test: left click emits pointer_confirm with its position
Given: R, and P = Vector2(123, 45)
When:  feed mouse_button(LEFT, pressed = true, position P), then the release
Then:  rec == [pointer_confirm(P)], with no action_pressed(confirm) and pointer_position == P
Edge cases:
  - the release alone emits nothing
  - a click with no motion before it still carries P
```

```
Test: right click emits pointer_cancel
Given: R, and P
When:  a RIGHT press and release at P
Then:  rec == [pointer_cancel(P)], with no action_pressed(cancel)
Edge cases: none
```

```
Test: wheel up and down emit steps of opposite sign
Given: R
When:  one WHEEL_UP notch (press + release pair), then one WHEEL_DOWN notch
Then:  rec == [wheel_step(+1), wheel_step(−1)]
Edge cases:
  - 3 notches up give 3 steps
  - MIDDLE, XBUTTON1/2, WHEEL_LEFT and WHEEL_RIGHT give no pointer signal
  - mouse motion updates pointer_position without emitting anything
```

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/input/input_pointer_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (2026-10-30)

---

## Dependencies

- Depends on: `production/epics/input-system/story-001-default-bindings-press-release.md`
- Unlocks: `production/epics/input-system/story-010-no-pointer-move.md`

## Completion Notes

*2026-10-30, implementation (autonomous run, tag sin2).*

- **Files**: `src/input/input_resolver.gd` (`_feed_mouse_button()`: left/right press emit `pointer_confirm`/`pointer_cancel` with `event.position`, wheel up/down press emit `wheel_step(+1/-1)`; releases, middle, X1/X2, wheel left/right silent; `pointer_position` getter updated by motion and buttons.); `tests/unit/input/input_pointer_test.gd`; `tests/unit/input/input_test_support.gd` (Recorder filters)
- **Tests**: 7 cases (left, right, wheel pair, wheel factor ignored, other buttons silent, click never emits confirm, position from motion). Input dir 193/193 (single-dir run; full suite run by main session).
- **Deviations**: None.
