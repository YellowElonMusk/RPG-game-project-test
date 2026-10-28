# Story 009: Of two same-frame transition requests, the first is accepted and the second rejected

> **Epic**: Game State & Scene Flow
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-28 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (Implementation Guidelines); GDD Edge Cases ("Order of receipt is deterministic (the order the requests were made)")
**ADR Decision Summary**: The accepting call leaves `IDLE` synchronously, so a second request in the same frame sees a busy machine and is rejected.
**ADR Version**: ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Pure machine. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "A transition request while `phase != IDLE` returns `REJECTED_BUSY` and changes no state."
- Required: "`GameStateMachine` … Time enters only through `tick(delta)`" (the same-frame definition depends on it).
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-7 [L]** GIVEN two transition requests in the same frame, THEN the first is accepted and the second rejected.

---

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines:*

- "Same frame" means no `tick()` between the two calls.
- The machine must leave `IDLE` **synchronously inside the accepting call**: set `phase = OUT` and emit `transition_started` before returning `OK`. It must never defer the phase change to the next `tick()`.
- Assert the second request's target never appears in any signal argument.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: rejection while a transition is already running.
- Story 019: the same rule for `choose_retry()`.

---

## Files

- `tests/unit/game_state/game_state_same_frame_requests_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-7**: `game_state_same_frame_requests_test.gd :: test_first_accepted_second_rejected`
  - Given: the machine in OVERWORLD, IDLE.
  - When: `request_transition(BATTLE, valid)` then `request_transition(CAMP, valid)`, with no tick between.
  - Then: first `OK`, second `REJECTED_BUSY`; `phase == OUT` immediately after the first call; `transition_started` already recorded before the second call; CAMP appears in no recorded signal argument; run to IDLE → mode == BATTLE.
  - Edge cases: reversed order (CAMP first) → CAMP wins; `open_overlay(MENU)` as the second same-frame call → `REJECTED_BUSY`.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_same_frame_requests_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing

---

## Completion Notes

*2026-10-28, implemented against existing behaviour (no production code changes needed):*

- **Files**: `tests/unit/game_state/game_state_same_frame_requests_test.gd` (new).
  No `src/` changes — `request_transition()` and `open_overlay()` already check
  `_phase != Phase.IDLE` before any other mutation and already set `_phase = OUT`
  and emit `transition_started` synchronously inside `_begin_transition()`
  (story 008/ADR-0002 behaviour), so AC-7 was already satisfied; this story
  pins it with a dedicated test.
- **Test**: one parametrized `test_first_accepted_second_rejected` with three
  cases — main scenario (BATTLE then CAMP, BATTLE wins), the QA's reversed-order
  edge case (CAMP then BATTLE, CAMP wins), and the QA's `open_overlay(MENU)`-as-
  second-call edge case (BATTLE wins, MENU never recorded). Each case asserts:
  first call `OK`; `phase == OUT` and `transition_started` recorded (index 0)
  immediately after the first call; second call `REJECTED_BUSY`; no new
  recorder event from the second call; the second request's target/kind value
  never appears in any recorded signal argument; running to IDLE lands on the
  expected winning mode.
- **Test count**: suite went from 521 to 524 test cases (3 parametrized cases
  of this one function), 0 failures, 0 orphans.
- **Deviations**: none from the QA Test Cases.
- **Items owed**: none.

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-008-busy-transition-rejects-requests.md`
- Unlocks: None
