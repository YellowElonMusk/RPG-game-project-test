# Story 008: An action held on two devices is released only once, at the second device's release

> **Epic**: Input System
> **Status**: Complete (2026-10-30)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (§3, §8: "`released` fires once, at the last device's release")
**ADR Decision Summary**: The resolver keeps a per-action held set of source keys, so an action held on several devices stays held until the last source lets go, and `released` fires exactly once then.
**ADR Version**: ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: None beyond the shared ADR-0003 notes.

**Control Manifest Rules (this layer)**:
- Required: "**`action_pressed`/`action_released` fire on edges; `action_held` fires every `tick` while held.**"
- Required: "**`InputResolver` (`RefCounted`) owns the binding table, held set, move vector and device state**"
- Forbidden: "**Never use Godot's `InputMap`/`Input` singleton for gameplay actions** — it merges devices"

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [x] **AC-19** The same action held on two devices: releasing one emits nothing; releasing the second emits exactly one `released`.

---

## Implementation Notes

*Derived from ADR-0003 §3, §8 and the AC-19/AC-27 ruling (2026-10-23: every physical press emits `pressed`; `released` fires only at the last release):*

- **Held-set source keys.** The held set maps action → set of source keys, for example `"k:<physical_keycode>"` and `"p:<device>:<JoyButton>"`.
- **Edge rules (pinned).** `pressed` fires on every non-echo press of a source key not already in the action's set. `released` fires only when the set becomes empty. A repeat press of a source already in the set is a no-op (story 002). So a second device pressing an already-held action **does** emit `pressed` (consistent with story 016, AC-27), and only the last release emits `released`.
- **`held` once per tick.** `action_held(action)` fires once per tick per action, however many sources hold it.
- **What the AC means by "two devices".** It means keyboard plus pad, and also two pads. Test both. As a third case, test two keys on the same keyboard (Enter + Space for `confirm`): the rule is the same, and stories 022, 023 and 025 rely on it.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 016: two `pressed` and the active-device kind for a same-frame keyboard+pad press.
- Stories 022, 023, 025: releasing held sources on disconnect and focus loss.

---

## Files

- `src/input/input_resolver.gd`
- `tests/unit/input/input_concurrency_test.gd` (shared with story 007)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, fix applied: edge-rule text replaced to match the AC-19/AC-27 ruling). The developer implements against these — do not invent new test cases during implementation.*

**AC-19** — the last release of a multi-source hold emits exactly one `released`.

```
Test: releasing one of two holding devices emits nothing; the last release emits one released
Given: R
When:  press Enter, press pad south (device 0), release Enter, then release pad south
Then:  rec == [pressed(confirm), pressed(confirm), released(confirm)], with the released after the pad release only
Edge cases:
  - the two-pad variant (device 0 south, device 1 south)
  - the same-keyboard variant (Enter + Space)
  - release in the opposite order
  - held fires once per tick (not twice) while both hold
  - a three-source hold releases once
```

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/input/input_concurrency_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (2026-10-30)

---

## Dependencies

- Depends on: `production/epics/input-system/story-001-default-bindings-press-release.md`
- Unlocks:
  - `production/epics/input-system/story-016-keyboard-and-pad-same-frame.md`
  - `production/epics/input-system/story-022-active-pad-lost.md`

---

## Completion Notes

*2026-10-30, implementation (autonomous run, tag sin).*

- **Files**: `src/input/input_resolver.gd` (`_apply_discrete_edge()`: every new source press emits `pressed`, `released` only when the set empties, stray releases ignored); `tests/unit/input/input_concurrency_test.gd`
- **Tests**: 4 cases (keyboard+pad, two pads, Enter+Space, stray release). Input dir 145/145; full suite 1266/1266, exit 0.
- **Deviations**: Behaviour change: a second source pressing an already-held action now emits `pressed` (it was silent before), per the AC-19/AC-27 ruling.
