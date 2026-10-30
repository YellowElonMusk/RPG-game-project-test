# Story 019: Repeated Retry inputs during the Retry transition cause exactly one restart

> **Epic**: Game State & Scene Flow
> **Status**: Complete (2026-10-30)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§6: input dropped while a transition runs; Implementation Guidelines: `REJECTED_BUSY`)
**ADR Decision Summary**: Retry is a transition, so once it starts, further Retry inputs are dropped by the input lock and direct `choose_retry()` calls return `REJECTED_BUSY`.
**ADR Version**: ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Pure machine. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "A transition request while `phase != IDLE` returns `REJECTED_BUSY` and changes no state."
- Required: "A mode reads movement only through `machine.get_move_vector(self)`; discrete actions arrive only through `handle_action()`."
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [x] **AC-18 [L]** GIVEN repeated Retry inputs during the Retry transition, THEN exactly one restart occurs.

---

## Implementation Notes

*Derived from ADR-0002 §6 and Implementation Guidelines:*

- Two paths must both yield one restart: (a) synthetic `confirm` presses during OUT/SWAP/IN are dropped by routing (the prompt is closed anyway); (b) direct `choose_retry()` calls during the transition return `REJECTED_BUSY`.
- Same-frame double `choose_retry()` before any tick: the first moves `phase` to `OUT` synchronously (story 009's rule), so the second is rejected.
- Assert `restore_start_snapshot` call count == 1 and that the Battle → Battle signal set fires once.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 017: the Retry restore itself.
- Story 030: the prompt's `confirm` → button press.

---

## Files

- `tests/unit/game_state/game_state_retry_debounce_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-18**: `game_state_retry_debounce_test.gd :: test_one_restart`
  - Given: the Defeat Prompt open in BATTLE.
  - When: `choose_retry()` twice with no tick between; then during OUT, SWAP and IN, synthetic confirm presses and direct `choose_retry()` calls.
  - Then: first `OK`, every later call `REJECTED_BUSY`; `restore_start_snapshot` calls == 1; `transition_started(BATTLE, BATTLE)` recorded once; the prompt's `handle_action` count during the transition == 0.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_retry_debounce_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing: `tests/unit/game_state/game_state_retry_debounce_test.gd` (game_state unit 184/184; with overworld + game_state integration 242/242, 2026-10-30)

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-010-input-locked-during-transition.md`, `production/epics/game-state-scene-flow/story-017-defeat-prompt-and-retry-snapshot.md`
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-30
- Deviation from 'tests only': choose_retry() (and choose_retreat()) returned REJECTED_INVALID_PAIR mid-transition; a busy check was added after the Content Error check so they return REJECTED_BUSY.
- Files: src/game_state/game_state_machine.gd, tests/unit/game_state/game_state_retry_debounce_test.gd
