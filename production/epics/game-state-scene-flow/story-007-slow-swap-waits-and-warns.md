# Story 007: A slow swap makes the in phase wait and logs a performance warning

> **Epic**: Game State & Scene Flow
> **Status**: Complete (2026-10-30)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-006` ("overruns are logged")
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (Implementation Guidelines overrun rule; Performance Implications)
**ADR Decision Summary**: A budget is never enforced by skipping work. When `t_swap` runs past `transition_budget − t_out − t_in`, IN still waits for the swap, and the machine logs a performance warning with the transition type and the measured `t_swap`.
**ADR Version**: ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Headless; stub loader. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Guardrail: "Swap phase load: bounded by `TransitionConfig`'s per-type budgets (0.5 s Retry, 1.0 s battle wipes, 1.5 s fades); an overrun logs a warning and never skips work."
- Required: "`TransitionPresenter` calls are fire-and-forget; phase timing comes only from `tick()`."
- Forbidden: skipping or truncating a phase to meet a budget.

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [x] **AC-26 [P]** *(part: the slow-swap test only)* "A second test injects a slow swap and asserts that the *in* phase waits and a performance warning is logged." (The hardware benchmark half is story 037.)

---

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines and the QA gate:*

- The allowance is `transition_budget − t_out − t_in`, computed from the config fixture (never a literal).
- The warning is logged **once, when the swap reaches DONE**, carrying `context.type` and the measured `context.t_swap` (the measured value only exists at completion). Code: `&"swap_over_budget"`.
- While the loader is PENDING, `phase` stays `SWAP` and `play_in` is not called. No work is skipped.
- Placed in Step 1 because it is headless and needs no hardware (AC-26 split, accepted).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 037: the 30-run benchmark on the min-spec PC and the Steam Deck.

---

## Files

- `src/game_state/game_state_machine.gd` (overrun warning)
- `tests/unit/game_state/game_state_swap_overrun_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-26 (slow swap)**: `game_state_swap_overrun_test.gd :: test_in_waits_and_warning_logged`
  - Given: `cfg` fixture row `battle_wipe`; `allowance = budget − t_out − t_in` computed from `cfg`; the stub loader PENDING for `ceil((allowance + 0.2) / step)` ticks of `step = 0.05`, then DONE.
  - When: Overworld→Battle runs to IDLE.
  - Then: `phase == SWAP` on every PENDING tick; `presenter.play_in` not called before the DONE poll; exactly one warning entry, `code == &"swap_over_budget"`, `context.type == &"battle_wipe"`, `context.t_swap` within 1e-6 of the scripted duration; `transition_finished` fires after IN; no work skipped (stub loader poll count == PENDING count + 1).
  - Edge cases: `t_swap == allowance` exactly → no warning; an overrun on a `retry_flash` (no load) path is still warned.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_swap_overrun_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing: `tests/unit/game_state/game_state_swap_overrun_test.gd` (game_state unit 184/184; with overworld + game_state integration 242/242, 2026-10-30)

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-006-transition-time-and-budget-check.md`
- Unlocks: `production/epics/game-state-scene-flow/story-037-transition-budget-hardware-bench.md`

---

## Completion Notes

**Completed**: 2026-10-30
- New _warn_if_swap_over_budget(): warning `swap_over_budget` {type, t_swap, allowance} once at swap DONE (normal and Retry swaps) when t_swap > budget - t_out - t_in (+1e-9). `none` and types without a budget row are skipped. Equality is not an overrun.
- Formula test runs on the fixture row and a non-default row. StubSceneLoader gained poll_count.
- Files: src/game_state/game_state_machine.gd, tests/unit/game_state/game_state_swap_overrun_test.gd, tests/unit/game_state/doubles/stub_scene_loader.gd
