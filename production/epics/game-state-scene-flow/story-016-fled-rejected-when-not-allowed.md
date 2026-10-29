# Story 016: Fled on a descriptor with can_flee = false is rejected and the battle continues

> **Epic**: Game State & Scene Flow
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (Complete)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§6, GDD rule 6 descriptor fields); ADR-0010: Turn Battle System (§5: "Game State still rejects it when `can_flee` was false (AC-13), which can't happen when gate 4 is honoured")
**ADR Decision Summary**: The machine keeps the current descriptor from battle entry. A Fled outcome on `can_flee = false` is rejected and logged as a Turn Battle bug; with `can_flee = true`, Fled returns to the Overworld at once.
**ADR Version**: ADR-0002 2026-10-21 · ADR-0010 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Pure machine. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "A transition request while `phase != IDLE` returns `REJECTED_BUSY` and changes no state" (the same no-change probe for the rejected outcome).
- Required: "Split into a pure logic core …" (the descriptor is held by the machine as data, never re-read from Battle).
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-13 [L]** GIVEN outcome Fled on a descriptor with `can_flee = false`, THEN the outcome is rejected, an error is logged, and the mode stays Battle.

---

## Implementation Notes

*Derived from ADR-0002 §6 and ADR-0010 §5:*

- `report_battle_outcome(FLED)` checks the stored `descriptor.can_flee`. When false it returns `REJECTED_INVALID_PAYLOAD`, logs `&"fled_not_allowed"` with `context.encounter_id` ("This is a Turn Battle bug"), and changes nothing. The battle continues.
- With `can_flee = true`, FLED starts the return immediately; no results wait, unlike Victory (ADR-0010 §5: "The Battle mode reports at once").
- Game State only carries the Fled outcome. The Flee *design* section of `turn-battle-system.md` is still owed (EPIC risks); add no flee rules here.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 034: Fled wiring in the real Battle mode (a TODO until `battle_fled` exists).
- Story 014: the Fled round trip's exact restore.

---

## Files

- `src/game_state/game_state_machine.gd` (Fled guard)
- `tests/unit/game_state/game_state_fled_guard_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-13**: `game_state_fled_guard_test.gd :: test_fled_rejected_when_not_allowed`
  - Given: BATTLE entered with descriptor `can_flee = false`.
  - When: `report_battle_outcome(FLED)`.
  - Then: `REJECTED_INVALID_PAYLOAD`; error code `&"fled_not_allowed"`, `context.encounter_id` == the descriptor's id; mode BATTLE; probe equal; a later `report_battle_outcome(VICTORY)` is still accepted.
  - Edge cases: `can_flee = true` → FLED starts Battle→Overworld immediately (no `report_results_done` needed).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_fled_guard_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-014-overworld-snapshot-exact-restore.md`
- Unlocks: `production/epics/game-state-scene-flow/story-002-transition-table-rows-succeed.md`

---

## Completion Notes

- `src/game_state/game_state_machine.gd`: `report_battle_outcome()`'s `FLED`
  branch now checks `_current_descriptor.can_flee` before starting the
  Battle -> Overworld transition. `can_flee = false` returns
  `REJECTED_INVALID_PAYLOAD`, logs `&"fled_not_allowed"` with
  `{"encounter_id": ...}`, and leaves `_pending_outcome`, `_phase` and
  `_current_mode` untouched (battle continues). A `null` descriptor (no
  Battle entry payload) is treated as flee-allowed, matching the existing
  `choose_retreat()` null-descriptor convention. Doc comment above
  `report_battle_outcome()` extended to describe the guard.
- `tests/unit/game_state/game_state_fled_guard_test.gd` (new):
  `test_fled_rejected_when_not_allowed` (AC-13, exact QA case: rejection code,
  error code/context, mode unchanged, probe-equal, later VICTORY still
  accepted) and `test_fled_allowed_starts_return_immediately` (QA edge case:
  `can_flee = true` starts `battle_wipe_reverse` at once, no
  `report_results_done()`).
- No fixture changes — built the `can_flee = false` descriptor inline from
  `GameStateFixtures.make_encounter_descriptor()` since the shared fixture
  defaults to `true` and other tests depend on that default.
- Full suite: 462/462 pass (`godot --headless ... GdUnitCmdTool.gd`), 0
  errors/failures/flaky/skipped/orphans.
- Deviations: none. Items owed: none within this story's scope (Story 034 —
  real Battle mode wiring — and Story 014's exact Fled restore remain
  Out of Scope here, as specified).

---

## Completion Notes

**Completed**: 2026-10-29
**Criteria**: 1/1 passing (AC-13)
**Deviations**: None.
**Test Evidence**: `tests/unit/game_state/game_state_fled_guard_test.gd` — confirmed passing in the full suite (581/581, 0 failures, 2026-10-29)
**Reviewed by**: self, no independent review (lean mode — LP-CODE-REVIEW and QL-TEST-COVERAGE skipped)
