# Story 007: `confirm` and `cancel` pressed in the same frame are both emitted, in input order

> **Epic**: Input System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-007`, `TR-input-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (§1, §8)
**ADR Decision Summary**: Actions are emitted synchronously inside `feed_event`, in the order the devices report them; Input never merges or drops actions — the receiver decides. "An action is reported in the same frame the device reports it."
**ADR Version**: ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: None beyond the shared ADR-0003 notes.

**Control Manifest Rules (this layer)**:
- Required: "**`action_pressed`/`action_released` fire on edges; `action_held` fires every `tick` while held.**"
- Forbidden: "**Never let a mode or overlay reach the Input System directly** — the `mode_direct_input_access` stance (ADR-0002)"
- Forbidden: "**Never make Input an autoload** — it holds mutable state"

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [ ] **AC-18** `confirm` and `cancel` pressed in the same frame: both emitted, in input order.

---

## Implementation Notes

*Derived from ADR-0003 §1, §8:*

- "Same frame" means two `feed_event()` calls with no `tick()` between them. Emission is synchronous inside `feed_event`, so order follows input order. Assert the recorder sequence is `[pressed(confirm), pressed(cancel)]` and the reverse for the reverse feed.
- Do not queue or coalesce events into `tick()`. That would add latency, and ADR-0003 Requirements say "an action is reported in the same frame the device reports it".
- Likely no resolver change; this story pins the behaviour with a test.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 016: the same action on two devices in one frame.
- Game State: which of the two actions the receiver acts on.

---

## Files

- `src/input/input_resolver.gd` (likely no change)
- `tests/unit/input/input_concurrency_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

**AC-18** — same-frame `confirm` and `cancel` are both emitted in input order.

```
Test: same-frame confirm and cancel are both emitted in order
Given: R
When:  feed press Enter, then press Esc, with no tick between them
Then:  rec == [pressed(confirm), pressed(cancel)]
Edge cases:
  - the reverse feed gives the reverse order
  - pad south then pad east gives the same result
  - mixed: key Esc then pad south gives [cancel, confirm]
  - nothing is emitted inside a following tick except held
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

- Depends on: `production/epics/input-system/story-001-default-bindings-press-release.md`
- Unlocks: None
