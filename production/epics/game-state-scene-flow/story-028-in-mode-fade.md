# Story 028: The in-mode fade fires only transition_started and transition_finished, and is legal only in a bare Overworld

> **Epic**: Game State & Scene Flow
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§11 in-mode fade); ADR-0005: Sprite & Camera Presentation, as amended by ADR-0012 (an in-mode fade triggers no rebind and no profile apply); ADR-0009: Save/Load & Settings (§4 `is_save_safe()`)
**ADR Decision Summary**: `request_in_mode_fade(callback)` is the fourth entry point, legal only in a bare, idle Overworld. It runs OUT (`fade`) → a zero-length SWAP that calls the callback once with no loader call → IN, and emits only `transition_started(mode, mode)` and `transition_finished(mode)`.
**ADR Version**: ADR-0002 2026-10-21 (Last Verified; §11 revised 2026-10-23) · ADR-0005 2026-10-22 · ADR-0009 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Pure machine. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "`request_in_mode_fade(callback)` is the fourth entry point, legal only in `OVERWORLD`, with `phase == IDLE` and no overlay open …"
- Required: "The in-mode fade is OUT (`fade`) → zero-length SWAP that calls `callback` once, with no loader call → IN; it emits only `transition_started(mode, mode)` and `transition_finished(mode)` …"
- Forbidden: "Never fade the Overworld without going through the machine."

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-27 [L]** (in-mode fade, rule 2) GIVEN Overworld with no overlay, WHEN the in-mode fade is requested, THEN exactly `transition_started(Overworld, Overworld)` and `transition_finished(Overworld)` fire (no `mode_exited`, no `mode_entered`), the callback runs once at the zero-length swap, input is locked from start to finish, and a save request during it is refused. GIVEN Battle, Camp, or Overworld with Dialogue open, THEN the request is rejected and nothing changes.

---

## Implementation Notes

*Derived from ADR-0002 §11 and ADR-0009 §4, plus the QA gate:*

- Legal only when `current_mode == OVERWORLD`, `phase == IDLE` and no overlay is open. Otherwise `REJECTED_BUSY` / `REJECTED_INVALID_PAIR` / `REJECTED_OVERLAY_BLOCKS` and nothing changes. A `callback` that is not `is_valid()` → `REJECTED_INVALID_PAYLOAD`.
- Phases: OUT (`fade` row `t_out`), a **zero-length SWAP** that calls `callback` exactly once, synchronously, with **no `SceneLoader` call**, then IN (`t_in`). `fade` never flashes, so `FlashGate` is not consulted.
- `is_in_mode_fade()` is true from `transition_started` to `transition_finished`.
- **"A save request during it is refused":** SaveService does not exist yet, so assert `is_save_safe() == false` throughout. Implement `is_save_safe()` here for all cases with its own parametrized table test, since ADR-0009 §4 consumes it.
- No rollback. **QA fix:** GDScript has no exceptions and a runtime error halts the test, so the error case is a callback whose object is freed before SWAP: an error is logged and IN still plays.
- Deferral and quit-waiting work as for any transition: cover focus loss during the fade (Menu after `transition_finished`) and Quit during the fade.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The Overworld epic's checkpoint redirect (the future caller).
- SaveService (ADR-0009) refusing the save itself.

---

## Files

- `src/game_state/game_state_machine.gd` (`request_in_mode_fade`, `is_in_mode_fade`, `is_save_safe`)
- `tests/unit/game_state/game_state_in_mode_fade_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE; the `push_error` edge case replaced by a freed-callback case). The developer implements against these — do not invent new test cases during implementation.*

- **AC-27 (fade)**: `game_state_in_mode_fade_test.gd :: test_fade_signals_and_callback`
  - Given: OVERWORLD, no overlay; a callback spy; a stub flash gate.
  - When: `request_in_mode_fade(spy)` → `OK`; run to IDLE with a synthetic confirm injected in OUT, SWAP and IN.
  - Then: recorder == `[transition_started(OVERWORLD, OVERWORLD), transition_finished(OVERWORLD)]`; callback calls == 1, made between them; stub loader `begin_swap == 0`; the mode receives 0 actions; `is_in_mode_fade()` true throughout and false after; `is_save_safe()` false throughout; flash gate untouched; same mode node (`is_same`).
- **AC-27 (rejected)**: `test_fade_rejected_elsewhere` (parameterized BATTLE, CAMP, OVERWORLD+DIALOGUE, OVERWORLD+MENU, OVERWORLD in OUT)
  - Then: `!= OK` (`REJECTED_INVALID_PAIR` / `REJECTED_OVERLAY_BLOCKS` / `REJECTED_BUSY`), probe equal, callback never called.
- **Save safety**: `test_is_save_safe_table`
  - Then: OVERWORLD/CAMP IDLE no overlay → true; with MENU → true; with DIALOGUE → false; BATTLE, TITLE → false; any `phase != IDLE` → false.
  - Edge cases: invalid Callable → `REJECTED_INVALID_PAYLOAD`; callback object freed before SWAP → error logged, IN still plays; `focus_lost` during the fade → Menu after `transition_finished`; `request_quit` during it → hook after `transition_finished`.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_in_mode_fade_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-010-input-locked-during-transition.md`, `production/epics/game-state-scene-flow/story-011-quit-waits-for-transition.md`, `production/epics/game-state-scene-flow/story-022-overlay-stack-input-and-order.md`, `production/epics/game-state-scene-flow/story-026-focus-loss-opens-menu.md`
- Unlocks: None in this epic (the Overworld epic's checkpoint redirect, future)
