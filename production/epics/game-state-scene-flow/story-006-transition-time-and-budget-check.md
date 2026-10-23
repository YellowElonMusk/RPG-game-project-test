# Story 006: transition_time sums the three phases, and a budget below t_out + t_in logs an error

> **Epic**: Game State & Scene Flow
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§9 `TransitionConfig`, data-only, loaded directly by `GameRoot._ready()`; ADR-0001 data-only rules via §9)
**ADR Decision Summary**: Transition timings and budgets live in a data-only `TransitionConfig`. The machine measures `transition_time` from accumulated tick deltas, and a budget below `t_out + t_in` is a load-time error naming the transition type.
**ADR Version**: ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Pure machine plus an in-memory `Resource`. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "Mode/overlay scene paths, transition timings and budgets come from `TransitionConfig` data, never literals."
- Forbidden: "Never use `@export var x: OtherResourceType` for a cross-reference" (scene paths are `String`).
- Guardrail: "Swap phase load: bounded by `TransitionConfig`'s per-type budgets … an overrun logs a warning and never skips work."

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-33 [L]** (Formulas) GIVEN stub phases of t_out 0.35, t_swap 0.20 and t_in 0.30 on the injected clock, THEN `transition_time` is 0.85 s (within 1e-6). GIVEN a `TransitionConfig` row with `transition_budget < t_out + t_in`, THEN loading it logs an error naming the transition type.

---

## Implementation Notes

*Derived from ADR-0002 §9 and the QA gate (RC-1 c, file-I/O rule):*

- `transition_time = t_out + t_swap + t_in` is **measured** from accumulated `tick` deltas under story 001's pinned tick rule: a phase ends on the first tick where accumulated phase time `>= duration - 1e-9`; overshoot is not carried; in SWAP, `tick` adds `delta` to `t_swap` and then polls. `t_swap` runs from SWAP start until `poll_swap() == DONE`. Expose `last_transition_time` and `last_t_swap` as read-only queries (used by 007 and 037).
- **API pinned: `TransitionConfig.validate(log) -> bool`** on an in-memory instance. It logs one error per offending row (`code = &"budget_below_phases"`, `context.type` = the row's `StringName`), does not stop at the first bad row, and returns `false` if any row failed. The comparison is strict (`budget < t_out + t_in`).
- **`validate` skips rows whose type is `none`**: the GDD Budgets table has no row for `none` (Boot → Content Error, exit).
- **No `.tres` in unit tests.** Build the config in code from `game_state_fixtures.gd` (`fixtures.transition_config_with(...)`). The "loaded from disk, then validated" path is asserted once in story 035's integration boot test against `data/config/transition_config.tres`.
- 0.35 / 0.20 / 0.30 are the GDD worked example, so they are allowed boundary literals ("the exact number IS the point"); build them through the factory, not inline in the assertion.
- `TransitionConfig` follows ADR-0001's data-only rules: no logic beyond validation, no `Resource`-typed exports, scene paths as `String`. It is a project config, not a catalog record.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007: the overrun warning.
- Story 035: `data/config/transition_config.tres` and its disk load.
- Story 037: the hardware benchmark.

---

## Files

- `src/game_state/transition_config.gd` (`validate(log) -> bool`)
- `src/game_state/game_state_machine.gd` (`last_transition_time`, `last_t_swap`)
- `tests/unit/game_state/game_state_transition_time_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fixes applied: pinned tick rule, `validate(log)` on an in-memory config, `none` skipped). The developer implements against these — do not invent new test cases during implementation.*

- **AC-33 (formula)**: `test_transition_time_sums_phases`
  - Given: `cfg` from `fixtures.transition_config_with(&"battle_wipe", t_out = 0.35, t_in = 0.30)`; stub loader returns PENDING on the first poll and DONE on the poll after the second tick in SWAP.
  - When: request Overworld→Battle; `tick(0.35)`; `tick(0.10)`; `tick(0.10)`; `tick(0.30)`.
  - Then: `last_transition_time` within 1e-6 of 0.85; `last_t_swap` within 1e-6 of 0.20.
- **AC-33 (budget check)**: `test_budget_below_phases_logs_error`
  - Given: a factory config with row `&"retry_flash"` whose `transition_budget < t_out + t_in`, plus one valid row.
  - When: `cfg.validate(spy_log)`.
  - Then: exactly one error entry, `code == &"budget_below_phases"`, `context.type == &"retry_flash"`; returns `false`; the valid row produces no entry; two bad rows → two entries (validation does not stop at the first).
  - Edge cases: budget == `t_out + t_in` exactly → no error (strict `<`); a `none` row with no budget → no entry; ticks of 1/60 s over the same phases give the same `transition_time` within one frame (60 Hz quantization documented).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_transition_time_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-001-overworld-to-battle-signal-order.md`
- Unlocks: `production/epics/game-state-scene-flow/story-007-slow-swap-waits-and-warns.md`, `production/epics/game-state-scene-flow/story-035-game-root-main-scene.md`, `production/epics/game-state-scene-flow/story-037-transition-budget-hardware-bench.md`
