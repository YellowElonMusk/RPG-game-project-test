# Story 023: A non-active pad disconnecting emits no `device_lost`, and its held actions release only if no other device holds them

> **Epic**: Input System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (§8)
**ADR Decision Summary**: A disconnecting pad's held sources are always removed, but `action_released` fires only for actions no other source still holds, and `device_lost()` fires only when the disconnecting pad is the active pad.
**ADR Version**: ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Multi-pad disconnect timing under SDL3 is unverified on hardware; the test drives `on_joy_connection` directly.

**Control Manifest Rules (this layer)**:
- Required: "**`device_lost()`/`focus_lost()` fire only after every held action's `action_released`**"
- Required: "**`action_pressed`/`action_released` fire on edges; `action_held` fires every `tick` while held.**"
- Required: "**`InputResolver` (`RefCounted`) owns the binding table, held set, move vector and device state**"

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [ ] **AC-15** A non-active pad disconnects (including while it holds an action): no `device_lost`. Any of its held actions are released only if no other device still holds them.

---

## Implementation Notes

*Derived from ADR-0003 §8:*

- **Setup.** The active pad A comes from story 015's rule (the first pad to send meaningful input; per-switch re-election as pinned there). Pad B holds `confirm`.
  - Case 1: B disconnects with nothing else holding `confirm`. Expect one `released(confirm)` and no `device_lost`, and no `active_device_changed`.
  - Case 2: keyboard Enter also holds `confirm`. B disconnects: nothing is emitted, and `confirm` is still held, so `action_held` continues on `tick`.
- **Shared code path.** Same path as story 022. Only the `device == active_pad` check differs.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 022: the active pad's disconnect.
- Story 024: reconnect.

---

## Files

- `tests/unit/input/input_device_connection_test.gd` (shared with story 022)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

**AC-15** — a non-active pad disconnect releases its sole-held actions only.

```
Test: a non-active pad disconnect releases its sole-held actions only
Given: R; pads 0 and 1 connected; pad 0 press-and-release (active pad 0); pad 1 south held
When:  (case 1) on_joy_connection(1, false, ""); (case 2, fresh R) Enter also held, then disconnect pad 1
Then:  case 1 rec.since(mark) == [released(confirm)], with no device_lost and no active_device_changed; case 2 rec.since(mark) is empty, and the next tick emits held(confirm)
Edge cases:
  - pad 1's stick deflection disappears from get_move_vector() after the disconnect
  - pad 1 disconnecting with nothing held emits nothing
```

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/input/input_device_connection_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on:
  - `production/epics/input-system/story-015-first-pad-sets-style.md`
  - `production/epics/input-system/story-022-active-pad-lost.md`
- Unlocks: None
