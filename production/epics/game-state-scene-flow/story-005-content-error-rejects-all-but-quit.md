# Story 005: Content Error rejects every request except Quit and ignores focus loss

> **Epic**: Game State & Scene Flow
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (Complete)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§10 `REJECTED_TERMINAL`; §6 focus loss ignored in Boot and Content Error)
**ADR Decision Summary**: Content Error is terminal. Every entry point returns `REJECTED_TERMINAL` except `request_quit()`, and focus or device loss is ignored without setting the deferred-Menu flag.
**ADR Version**: ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Pure machine. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "A transition request while `phase != IDLE` returns `REJECTED_BUSY` and changes no state, except `request_quit()`" (the same exception shape as terminal).
- Required: "Signals fire in exactly this order …" (nothing fires at all in Content Error).
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-2 [L]** GIVEN Content Error, WHEN each kind of request (every transition, every overlay, focus-lost) is made repeatedly, THEN every request is rejected except Quit, and the focus-lost notice is ignored.

---

## Implementation Notes

*Derived from ADR-0002 §6, §10 and the QA gate (RC-1 b, RC-3):*

- Every entry point returns `REJECTED_TERMINAL` in Content Error: `request_transition` (every `Mode`), `open_overlay` (every `OverlayKind`), `close_overlay`, `request_in_mode_fade`, `report_battle_outcome`, `report_results_done`, `choose_retry`, `choose_retreat`.
- `register_camp` returns `void`, so it is logged and ignored and asserted through the probe, not a return code.
- **Quit latch** — pinned (ruling 2026-10-23; to be recorded in ADR-0002 by technical-director, batched annotation): the quit hook fires **at most once per machine lifetime**. Every later `request_quit()` returns `OK` and does nothing.
- `focus_lost` / `device_lost` from the synthetic `ActionSource` produce no overlay and **set no deferred-Menu flag**; assert `get_debug_state().menu_deferred == false`.
- "Repeatedly": each request at least 3 times, with the probe asserted after each.
- Quit in Content Error has **no confirmation** at machine level; the scene's Quit button calls `request_quit()` directly. Rule 12's confirmation is Title/Menu UI (031).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 035: the Content Error scene.
- Story 031: the Quit confirmation on Title.

---

## Files

- `tests/unit/game_state/game_state_content_error_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fixes applied: quit latch, `menu_deferred` via `get_debug_state()`). The developer implements against these — do not invent new test cases during implementation.*

- **AC-2 (requests)**: `test_every_request_rejected_terminal` (parameterized over entry point)
  - Given: the machine in CONTENT_ERROR (stub catalog FAILED); `probe_before`.
  - When: each of `request_transition(every Mode)`, `open_overlay(every OverlayKind)`, `close_overlay()`, `request_in_mode_fade(valid)`, `report_battle_outcome(each)`, `report_results_done()`, `choose_retry()`, `choose_retreat()` is called 3 times, with one tick between calls.
  - Then: every call returns `REJECTED_TERMINAL`; probe equal after each call; recorder empty.
- **AC-2 (register_camp)**: `test_register_camp_ignored`
  - Given: CONTENT_ERROR.
  - When: `register_camp("camp_a")` ×3.
  - Then: `last_camp_id` unchanged; one log entry per call; probe equal.
- **AC-2 (focus/device loss)**: `test_focus_and_device_loss_ignored`
  - Given: CONTENT_ERROR, synthetic source bound.
  - When: synthetic `focus_lost` ×3 and `device_lost` ×3; tick 10.
  - Then: no `overlay_opened`; `get_debug_state().menu_deferred == false`; a later tick still opens nothing.
- **AC-2 (Quit)**: `test_quit_only_accepted`
  - When: `request_quit()` ×3.
  - Then: each returns `OK`; `quit_spy.calls == 1` (latch).
  - Edge cases: synthetic `action_pressed(&"menu")` and `(&"confirm")` in Content Error reach no receiver.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_content_error_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (521/521 project-wide)

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-004-boot-to-title-or-content-error.md`
- Unlocks: `production/epics/game-state-scene-flow/story-024-menu-input-gating.md`, `production/epics/game-state-scene-flow/story-035-game-root-main-scene.md`, `production/epics/content-catalog/story-025-error-screen-on-launch.md` (together with 035)

---

## Completion Notes

**Files**:
- `tests/unit/game_state/game_state_content_error_test.gd` (new) — the story's required evidence: one parameterized test over all 17 entry-point/argument cases (`test_every_request_rejected_terminal`), plus `test_register_camp_ignored`, `test_focus_and_device_loss_ignored`, `test_quit_only_accepted`.
- `src/game_state/game_state_machine.gd` (edited) — most entry points already returned `REJECTED_TERMINAL` in `CONTENT_ERROR` (story 004's work). Four had a real gap, found by running the new tests against the unfixed code first: `close_overlay()`, `report_results_done()`, `choose_retry()` and `choose_retreat()` had no `CONTENT_ERROR` guard and fell through to `REJECTED_INVALID_PAIR`/`REJECTED_BUSY` instead. Added the same `if _current_mode == Mode.CONTENT_ERROR: return RequestResult.REJECTED_TERMINAL` guard used by the other entry points, checked first (same order as `request_transition`).

**Not changed (already correct, pinned by the new tests)**:
- `register_camp()` — already ignored outside `OVERWORLD`, which covers `CONTENT_ERROR`.
- `_on_source_focus_lost()` / `_on_source_device_lost()` — still no-ops (story 026 not yet implemented), so no overlay opens and `_menu_deferred` is never set, in any mode including `CONTENT_ERROR`.
- `_dispatch_discrete_action()` — the stub loader's `current_mode_node()`/`current_overlay_node()` default to `null`, so `action_pressed(&"menu"/"confirm")` already reaches no receiver.
- `request_quit()`'s latch (story 011) — already fires the hook at most once per lifetime; verified directly rather than re-derived.

**Test count**: 521/521 project-wide (up from 501), 0 errors, 0 failures, 0 flaky, 0 orphans.

**Deviations**: None from the QA Test Cases. No new cases invented.

**Items owed**: None for this story. Stories 024, 035 and content-catalog/025 remain unlocked as noted above.

---

## Completion Notes

**Completed**: 2026-10-29
**Criteria**: 1/1 passing (AC-2 terminal-state rejection)
**Deviations**: None from the QA Test Cases. Four entry points (`close_overlay()`, `report_results_done()`, `choose_retry()`, `choose_retreat()`) were missing the `CONTENT_ERROR` → `REJECTED_TERMINAL` guard other entry points already had — fixed as part of this story's own scope, not a deviation from it.
**Test Evidence**: `tests/unit/game_state/game_state_content_error_test.gd` — confirmed passing in the full suite (581/581, 0 failures, 2026-10-29)
**Reviewed by**: self, no independent review (lean mode — LP-CODE-REVIEW and QL-TEST-COVERAGE skipped)
