# Story 017: The pointer distance restarts from zero after a switch to gamepad, so switching back needs a full `pointer_switch_px`

> **Epic**: Input System
> **Status**: Complete (2026-10-30)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (§1 "the cumulative pointer distance", §8)
**ADR Decision Summary**: The resolver keeps a cumulative pointer distance for device switching, measured since the last non-mouse input and reset whenever the active device changes, compared against `InputConfig.pointer_switch_px`.
**ADR Version**: ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: None beyond the shared ADR-0003 notes.

**Control Manifest Rules (this layer)**:
- Required: "**Bindings are a catalog record** (`bindings_` prefix); **tuning values** (deadzone, repeat timing, `pointer_switch_px`, pad-style patterns) are a project config (`InputConfig`), not a catalog record"
- Required: "**`InputResolver` (`RefCounted`) owns the binding table, held set, move vector and device state, with no scene-tree dependency.**"
- Guardrail: one dictionary lookup per device event.

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [x] **AC-28** Cumulative pointer movement below `pointer_switch_px`, then a pad press (active device → gamepad), then further mouse movement: the distance counts from zero after the switch, so the switch back to keyboard_mouse needs a full `pointer_switch_px` of new movement.

---

## Implementation Notes

*Derived from ADR-0003 §1, §8 and the GDD Edge Cases:*

- **When the counter resets.** GDD Edge Cases: "total pointer movement since the last non-mouse input, reset whenever the active device changes". Reset the counter both on any non-mouse meaningful input and on every `active_device_changed`.
- **Steps.** Move `pointer_switch_px − 1` → pad press (one emission, gamepad) → move `pointer_switch_px − 1` (no emission) → move 1 more (one emission, keyboard_mouse). All values are derived from config. Repeat with `NON_DEFAULT`.
- **Not the UI counter.** This is the device-switch counter, not the UI's hover-focus counter (ADR-0008 §6, reset per screen, TR-input-009). Do not share state with it. The UI computes its own from `pointer_position`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- UI Framework epic: the hover-focus `pointer_switch_px` check (TR-input-009, ADR-0008 §6).
- Story 012: the basic switch on reaching `pointer_switch_px`.

---

## Files

- `src/input/input_resolver.gd` (counter reset)
- `tests/unit/input/input_active_device_test.gd` (shared with stories 012 and 013)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

**AC-28** — the pointer distance resets on the switch to gamepad.

```
Test: the pointer distance resets on the switch to gamepad
Given: R in its initial keyboard_mouse state, cfg ∈ {DEFAULT, NON_DEFAULT}, p = cfg.pointer_switch_px
When:  move p − 1 (nothing), pad south (one GAMEPAD signal), move p − 1 (nothing), move 1 more
Then:  exactly two active_device_changed in total: GAMEPAD at the pad press and KEYBOARD_MOUSE at the final 1 px
Edge cases:
  - the counter also resets on a non-mouse input that does not change the kind: in gamepad, move p − 1, pad east, move p − 1 gives no switch
  - sub-pixel relatives (0.5 px steps) accumulate
```

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/input/input_active_device_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (2026-10-30)

---

## Dependencies

- Depends on: `production/epics/input-system/story-012-active-device-changed.md`
- Unlocks: None

## Completion Notes

*2026-10-30, implementation (autonomous run, tag sin2).*

- **Files**: `src/input/input_resolver.gd` (`_pointer_distance` resets on every non-mouse meaningful input and on every active-device change; separate from any UI counter.); `tests/unit/input/input_active_device_test.gd`; `tests/unit/input/input_test_support.gd` (Recorder filters)
- **Tests**: 1 case x DEFAULT/NON_DEFAULT (px-1, pad press, px-1 silent, +1 switches). Input dir 193/193 (single-dir run; full suite run by main session).
- **Deviations**: None.
