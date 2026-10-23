# Story 011: Quit during a transition calls the quit hook once, after transition_finished

> **Epic**: Game State & Scene Flow
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (Implementation Guidelines: "`request_quit()` … sets a flag that fires the quit hook once, after `transition_finished`"; §11: the in-mode fade also waits)
**ADR Decision Summary**: Quit is the one request a running transition accepts. It sets a Quit-wait flag, and the injected quit hook fires once, after `transition_finished`. When IDLE, the hook fires at once.
**ADR Version**: ADR-0002 2026-10-21 (Last Verified; §11 revised 2026-10-23)

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Pure machine; the hook is an injected `Callable`. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "A transition request while `phase != IDLE` returns `REJECTED_BUSY` and changes no state, except `request_quit()`."
- Required: "`GameStateMachine` must never reference the scene tree, `get_tree()` …" (hence the injected hook).
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-9 [L]** GIVEN a running transition, WHEN Quit is requested, THEN a stubbed quit hook is called exactly once, after `transition_finished`.

---

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines, §11 and the QA gate (RC-3):*

- `request_quit()` returns `OK` during OUT/SWAP/IN and sets the Quit-wait flag (`get_debug_state().quit_pending`).
- **Quit latch** — pinned (ruling 2026-10-23; to be recorded in ADR-0002 by technical-director, batched annotation): the quit hook fires **at most once per machine lifetime**. Every later `request_quit()` returns `OK` and does nothing. Repeated calls during a transition therefore never stack.
- Ordering: the quit spy writes to the shared `sequence_recorder`; the hook's index is strictly after `transition_finished`.
- When IDLE, `request_quit()` calls the hook synchronously (the Title/Menu → exit row). The confirmation dialog is UI (031) and sits **in front of** this call, never inside the machine.
- The quit hook is a `Callable` injected at `_init`. Production binds `get_tree().quit` in `GameRoot` (035), never in the machine.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 031: the Title Quit confirmation.
- Story 028: Quit during the in-mode fade (re-asserted there).

---

## Files

- `src/game_state/game_state_machine.gd` (Quit-wait flag, latch)
- `tests/unit/game_state/game_state_quit_wait_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE, consistent with the RC-3 latch). The developer implements against these — do not invent new test cases during implementation.*

- **AC-9**: `game_state_quit_wait_test.gd :: test_quit_hook_after_transition_finished` (parameterized OUT, SWAP, IN)
  - Given: Overworld→Battle stopped in the phase; the quit spy writes to the sequence recorder.
  - When: `request_quit()` ×3 (returns `OK` each), then tick to completion.
  - Then: `quit_spy.calls == 1`; recorder `index(quit) > index(transition_finished)`; `quit_pending` true until then.
  - Edge cases: IDLE in Title → hook called synchronously inside `request_quit()`; Quit during the in-mode fade (028).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_quit_wait_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-008-busy-transition-rejects-requests.md`
- Unlocks: `production/epics/game-state-scene-flow/story-025-menu-stops-time-quit-to-title.md`, `production/epics/game-state-scene-flow/story-028-in-mode-fade.md`, `production/epics/game-state-scene-flow/story-031-title-focus-and-quit-confirm.md`
