# Story 016: The same action pressed on keyboard and pad in one frame emits two `pressed`, and the active device is the later event's kind

> **Epic**: Input System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-005`, `TR-input-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (§8)
**ADR Decision Summary**: Every physical press emits `pressed`, synchronously and in input order, and the active device follows the kind of the latest meaningful input; `released` fires only when the last holding source lets go.
**ADR Version**: ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: None beyond the shared ADR-0003 notes.

**Control Manifest Rules (this layer)**:
- Required: "**`action_pressed`/`action_released` fire on edges; `action_held` fires every `tick` while held.**"
- Forbidden: "**Never use `event.device == 0` to mean mouse/keyboard**"
- Required: "**`InputResolver` (`RefCounted`) owns the binding table, held set, move vector and device state**"

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [ ] **AC-27** Pressing the same action on the keyboard and on a pad in one frame emits two `pressed`, and the active device is the kind of the later event.

---

## Implementation Notes

*Derived from ADR-0003 §8 and the AC-19/AC-27 ruling (2026-10-23: every physical press emits `pressed`; `released` fires only at the last release):*

- **Feed order.** Feed key Enter, then pad south, with no `tick()` between. Assert two `pressed(confirm)` and `active_device == GAMEPAD`. Then do the reverse order in a fresh resolver and assert `KEYBOARD_MOUSE`.
- **Agree with story 008.** The held set still has two sources, so release semantics stay AC-19's: one `released` at the last release. That assertion is an edge case here, so 008 and 016 are proven consistent.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: the release side in full.
- Story 012: the general device-switch rules.

---

## Files

- `tests/unit/input/input_concurrency_test.gd` (shared with stories 007 and 008)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

**AC-27** — keyboard and pad in one frame give two `pressed`, and the later kind wins.

```
Test: keyboard and pad in one frame give two pressed, and the later kind wins
Given: a fresh R per order
When:  (a) key Enter then pad south, with no tick; (b) pad south then key Enter
Then:  (a) two pressed(confirm), active_device == GAMEPAD, one active_device_changed; (b) two pressed(confirm), active_device == KEYBOARD_MOUSE, two active_device_changed in the order GAMEPAD, KEYBOARD_MOUSE
Edge cases:
  - releasing one source emits nothing; releasing the other emits one released(confirm), consistent with story 008
```

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/input/input_concurrency_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on:
  - `production/epics/input-system/story-008-two-device-hold-release.md`
  - `production/epics/input-system/story-012-active-device-changed.md`
- Unlocks: None
