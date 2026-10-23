# Story 005: Content Error rejects every request except Quit and ignores focus loss

> **Epic**: Game State & Scene Flow
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

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

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-004-boot-to-title-or-content-error.md`
- Unlocks: `production/epics/game-state-scene-flow/story-024-menu-input-gating.md`, `production/epics/game-state-scene-flow/story-035-game-root-main-scene.md`, `production/epics/content-catalog/story-025-error-screen-on-launch.md` (together with 035)
