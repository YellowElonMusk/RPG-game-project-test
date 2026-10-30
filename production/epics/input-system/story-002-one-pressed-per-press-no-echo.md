# Story 002: One `pressed` per physical press, `held` every tick, and no second `pressed` from OS key-repeat echoes

> **Epic**: Input System
> **Status**: Complete (2026-10-30)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (§8, Implementation Guidelines)
**ADR Decision Summary**: `action_pressed`/`action_released` fire on edges and `action_held` fires on every `tick` while an action is held. OS key-repeat echo events are ignored, so a physical press yields exactly one `pressed`.
**ADR Version**: ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `InputEventKey.echo` predates the LLM cutoff and is stable.

**Control Manifest Rules (this layer)**:
- Required: "**`action_pressed`/`action_released` fire on edges; `action_held` fires every `tick` while held.** `nav_*` are derived actions, never bound directly"
- Required: "**Keyboard bindings match on `physical_keycode`, never `keycode`.** Echo events are ignored"
- Forbidden: "**`InputSystem` never calls `set_input_as_handled()`, and the resolver ignores `InputEventAction`**"
- Guardrail: one dictionary lookup per device event, negligible per `tick`.

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [x] **AC-2** Holding `fast_forward` emits exactly one `pressed`, `held` on every tick while held, and exactly one `released` on release. A one-tick tap emits exactly one `pressed` and one `released`. A keyboard key held through the operating system's key-repeat, with synthetic echo events injected, emits no second `pressed`, for `fast_forward` and `confirm` alike.

---

## Implementation Notes

*Derived from ADR-0003 §8 and Implementation Guidelines:*

- "**`action_held(action)` fires on every `tick` while held**". `held` comes from `tick(delta)`, never from device events. A tap pressed and released inside one tick emits `pressed` and `released` and **zero** `held`. Assert the exact count of `held` for N ticks.
- "Echo events (`event.echo`) are ignored". Drop an `InputEventKey` with `echo == true` before table lookup. Also treat a non-echo press for a key already in the held set as a no-op. Some platforms deliver repeats differently, and the held-set check is the second guard. Gamepad buttons have no echo, so the held-set check covers them.
- Run the test for both `fast_forward` (Shift) and `confirm` (Enter, Space, Z) as the AC requires. This is the property Sprite & Camera rule 9's mash guards rely on.
- Shared fixtures (`DEFAULT`, `R`, `rec`, `DT`) come from `tests/unit/input/input_test_support.gd` (story 001).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: the same action held on two sources (released only at the last release).
- Story 025: a key still held across focus return needing a fresh press.

---

## Files

- `src/input/input_resolver.gd`
- `tests/unit/input/input_press_semantics_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

**AC-2** — one `pressed` per physical press, `held` every tick, no echo `pressed`.

```
Test: holding fast_forward emits one pressed, one held per tick and one released
Given: R with DEFAULT
When:  press Shift, call tick(DT) N = 10 times, release Shift
Then:  rec holds exactly pressed(fast_forward), then 10 × held(fast_forward), then released(fast_forward)
Edge cases:
  - repeat with pad west (device 0)
  - N = 1
```

```
Test: a tap emits exactly one pressed and one released
Given: R
When:  (a) press and release Shift with no tick between them; (b) press Shift, tick(DT) once, release Shift
Then:  (a) is [pressed, released] with 0 held; (b) is [pressed, held, released]
Edge cases: none
```

```
Test: key-repeat echoes never produce a second pressed
Given: R
When:  press the key, feed 5 echo events (pressed = true, echo = true) interleaved with tick(DT), then release it
Then:  exactly one pressed(a) and one released(a); the held count equals the tick count
Edge cases:
  - parametrize over Shift (fast_forward), and Enter, Space and Z (confirm)
  - a non-echo duplicate press of the same key while it is held emits nothing (the held-set guard)
  - a duplicate press of pad south on the same device while it is held emits nothing
```

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/input/input_press_semantics_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (2026-10-30)

---

## Dependencies

- Depends on: `production/epics/input-system/story-001-default-bindings-press-release.md`
- Unlocks: `production/epics/input-system/story-025-focus-lost-and-gained.md`

---

## Completion Notes

*2026-10-30, implementation (autonomous run, tag sin).*

- **Files**: `src/input/input_resolver.gd` (`tick()` emits `action_held` once per held action; repeated press of a held source is a no-op); `tests/unit/input/input_press_semantics_test.gd`
- **Tests**: 18 cases (Shift, Enter, Space, Z; pad duplicate press; idle tick). Input dir 145/145; full suite 1266/1266, exit 0.
- **Deviations**: None.
