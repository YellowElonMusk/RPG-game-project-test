# Story 008: A running transition rejects any other transition or overlay request

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

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (Implementation Guidelines: "`phase != IDLE` must return `REJECTED_BUSY` and change no state")
**ADR Decision Summary**: One transition at a time. While a transition runs, every other transition and overlay request returns `REJECTED_BUSY` and changes nothing; only `request_quit()` is accepted.
**ADR Version**: ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Pure machine. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "A transition request while `phase != IDLE` returns `REJECTED_BUSY` and changes no state, except `request_quit()`."
- Forbidden: "No system other than `GameStateMachine` (through its `SceneLoader`) may add, remove or free children of `ModeHost`/`OverlayHost`."
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-6 [L]** GIVEN a running transition, WHEN another transition or any overlay open/close is requested, THEN it is rejected.

---

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines and the QA gate:*

- **Precedence pinned:** a busy machine returns `REJECTED_BUSY` **before any other check**, including `close_overlay()` on an empty stack.
- Parametrize over phase (`OUT`, `SWAP`, `IN`) × request (`request_transition` to a legal target, `open_overlay` of each kind, `close_overlay`, `request_in_mode_fade`, `report_battle_outcome`). Each returns `REJECTED_BUSY` with an unchanged probe.
- `report_battle_outcome` during a transition is a programming error (GDD Edge Cases: "Battle only reports Defeat outside transitions"). Return `REJECTED_BUSY` and log `&"outcome_during_transition"`.
- `request_quit()` is **not** rejected (story 011). Leave it out, with a comment.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 009: same-frame ordering.
- Story 011: Quit during a transition.

---

## Files

- `tests/unit/game_state/game_state_busy_rejection_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE, precedence pinned). The developer implements against these — do not invent new test cases during implementation.*

- **AC-6**: `game_state_busy_rejection_test.gd :: test_request_during_phase_rejected` (parameterized phase ∈ {OUT, SWAP, IN} × request)
  - Given: Overworld→Battle in progress, stopped in the given phase (stub loader held PENDING for SWAP); `probe_before`.
  - When: `request_transition(CAMP, valid payload)` / `open_overlay(each kind)` / `close_overlay()` / `request_in_mode_fade(valid)` / `report_battle_outcome(VICTORY)`.
  - Then: `REJECTED_BUSY`; probe equal; no extra signal in the recorder; `report_battle_outcome` also logs code `&"outcome_during_transition"`.
  - Edge cases: `request_quit()` deliberately absent (comment → 011); the running transition completes normally afterwards.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_busy_rejection_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (439/439 unit tests green, incl. 21 new parameterized cases; 0 errors, 0 failures, 0 orphans)

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-001-overworld-to-battle-signal-order.md`
- Unlocks: `production/epics/game-state-scene-flow/story-009-same-frame-requests-first-wins.md`, `production/epics/game-state-scene-flow/story-011-quit-waits-for-transition.md`

---

## Completion Notes

**Files**:
- `src/game_state/game_state_machine.gd` — three fixes to pin the precedence ADR-0002 requires:
  - `close_overlay()`: now checks `_phase != Phase.IDLE` first, returning `REJECTED_BUSY` before the empty-stack `REJECTED_INVALID_PAIR` check (previously it had no busy check at all).
  - `request_in_mode_fade()`: busy is now checked before the Overworld-mode check (previously a busy call returned `REJECTED_INVALID_PAIR` instead of `REJECTED_BUSY`, since both conditions were OR'd into one branch).
  - `report_battle_outcome()`: busy is now its own branch, logging `&"outcome_during_transition"` via `_log.error()` before returning `REJECTED_BUSY`; the wrong-mode-but-idle case still returns `REJECTED_BUSY` with no log (unchanged). `request_transition()` and `open_overlay()` already checked busy first and needed no change.
- `tests/unit/game_state/game_state_busy_rejection_test.gd` — new. `test_request_during_phase_rejected`, gdUnit4-parameterized over 21 `(phase, request)` pairs (`OUT`/`SWAP`/`IN` × the 7 requests the QA Test Cases name). Reuses `GameStateFixtures.make_machine_in_overworld`, `StubSceneLoader.script_results`, `GameStateProbe.states_equal`, `SequenceRecorder`, `SpyGameStateLog` — no new test doubles needed. `request_quit()` is deliberately absent, with a comment pointing to story 011.

**Test count**: 439/439 unit tests green (418 prior + 21 new), 0 errors, 0 failures, 0 orphans.

**Deviations**: None from the Implementation Notes or QA Test Cases. The precedence fix touched three methods beyond what a first read of the ADR skeleton suggested was needed, because `close_overlay()` had no busy check at all and the other two conflated busy with a different rejection code — both are corrections to match the ADR's already-stated rule, not new design.

**Items owed**: None for this story. Stories 009 (same-frame ordering) and 011 (`request_quit()` during a transition) remain out of scope here, as noted above.
