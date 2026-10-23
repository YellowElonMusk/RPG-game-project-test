# Story 015: After Victory, the return to the Overworld starts only after the results screen is done

> **Epic**: Game State & Scene Flow
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (Key Interfaces: `report_results_done()`, "Victory waits for this (AC-12)"); ADR-0010: Turn Battle System (§5 reporting order: outcome → results screen → `report_results_done`); ADR-0006: Battle Replay Ownership (§5 "End of the fight": outcome reported only after the replay's last beat and the hold)
**ADR Decision Summary**: `report_battle_outcome(VICTORY)` records the outcome and starts nothing. The Battle → Overworld `battle_wipe_reverse` starts only on `report_results_done()`.
**ADR Version**: ADR-0002 2026-10-21 · ADR-0010 2026-10-22 · ADR-0006 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Pure machine. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "Signals fire in exactly this order for a transition …" (nothing fires before `report_results_done`).
- Required: "Under Game State the Battle mode must call `BattleCore.start_battle(false)` …" (context: the Battle mode, not the machine, owns the results screen).
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-12 [L]** GIVEN outcome Victory, THEN the transition to Overworld starts only after Battle signals that its results screen is done.

---

## Implementation Notes

*Derived from ADR-0002 Key Interfaces and ADR-0010 §5:*

- `report_battle_outcome(VICTORY)` returns `OK`, records the outcome (`get_debug_state().pending_outcome`) and starts nothing. Then `report_results_done()` starts the Battle → Overworld `battle_wipe_reverse`.
- `report_results_done()` with no Victory pending → rejected and logged, probe unchanged. A second `report_battle_outcome` while a Victory is pending → rejected.
- Input still routes to the Battle mode while the results screen is up (it is not a transition).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 016: Fled (no results wait).
- Story 034: the Battle mode's interim results screen.
- Story 036: dialogue after the return.

---

## Files

- `src/game_state/game_state_machine.gd` (`report_battle_outcome`, `report_results_done`)
- `tests/unit/game_state/game_state_victory_results_wait_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-12**: `game_state_victory_results_wait_test.gd :: test_return_starts_only_after_results_done`
  - Given: the machine in BATTLE (entered from Overworld).
  - When: `report_battle_outcome(VICTORY)` → `OK`; tick 120 × (1/60).
  - Then: `phase == IDLE`; no `transition_started`; a synthetic confirm still reaches the Battle mode; then `report_results_done()` → `OK` and `transition_started(BATTLE, OVERWORLD)` with `&"battle_wipe_reverse"`.
  - Edge cases: `report_results_done()` with no pending Victory → rejected, logged, probe equal; a second `report_battle_outcome` while Victory is pending → rejected.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_victory_results_wait_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-014-overworld-snapshot-exact-restore.md`
- Unlocks: `production/epics/game-state-scene-flow/story-002-transition-table-rows-succeed.md`, `production/epics/game-state-scene-flow/story-036-victory-dialogue-after-transition.md`
