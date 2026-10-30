# Story 033: the command menu, Defeat Prompt and outcome report open only after the replay, never off BattleCore's raw signals

> **Epic**: Sprite & Camera Presentation
> **Status**: Complete (awaiting /story-done)
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-009`, `TR-presentation-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Battle Replay Ownership
**ADR Decision Summary**: `BattleReplayController` releases gated copies of the turn, round and end signals only after the beats ahead of them have played; the command menu and HUD connect only to the controller's gated signals, never to `BattleCore.turn_started`, `round_advanced` or `battle_ended` directly.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API. This is a signal-ordering integration test against a real, seeded `BattleCore` and a stub Game State — the gdUnit4 headless pattern (typed signals, explicit `advance()` deltas) is the project's existing precedent and needs no further engine verification.

**Control Manifest Rules (this layer)**:
- Required: "`BattleHud` and the Battle mode must connect only to the controller's signals, and must never connect to `BattleCore.turn_started`, `round_advanced` or `battle_ended` directly" (ADR-0006 Implementation Guidelines).
- Required: "`BattleHud` must read HP, MP and status only through `get_display()`, and the round only through `get_display_round()`" (ADR-0006 Implementation Guidelines).
- Forbidden: "Never let a mode scene light itself with no Director" — not applicable to this clause; the relevant Core Forbidden rule is instead ADR-0006's own "must never connect... directly," quoted above as Required (the manifest states it as an obligation, not a Forbidden-Approaches entry, because it is Feature-side wiring the Core HUD must honour).

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [x] **AC-29 [I]** (P-01, P-04) (Game State, Turn Battle) With a real, seeded `BattleCore`, the controller and a stub Game State: GIVEN a battle entry, THEN the first command menu opens only after the reveal, and in a boss fight only after the takeover. GIVEN a command that ends the battle, THEN the outcome reaches Game State only after the last beat and the end-of-fight hold, and the Defeat Prompt opens only after that. GIVEN a command that does not, THEN the command menu opens only when the next turn is released. The HUD has no connection to `BattleCore`'s own turn, round or end signals.

---

## Implementation Notes

*Derived from ADR-0006 Decision §3 (States and signals), §4 (`advance()` step 4: release markers) and §5 (Call order):*

- `turn_started_after_replay`, `round_advanced_after_replay` and `battle_ended_after_replay` are emitted only when the corresponding TURN/ROUND/END marker reaches the head of the queue and every entry ahead of it has finished (§4 step 4) — the test drives `advance()` explicitly and asserts the command menu's open call fires from these gated signals, never from a direct `BattleCore` connection.
- On first entry, the reveal gate (and, in a boss fight, the `TAKEOVER_FULL` hold behind it) sits ahead of the first `turn_started` marker in the queue — so the first command menu cannot open before `open_reveal_gate()` is called on `transition_finished(BATTLE)`, and in a boss fight not before `hold_finished(TAKEOVER_FULL)` either.
- `battle_ended_after_replay(won)` is released only after the last beat finishes; the Battle mode's end-of-fight hold (`victory_hold`/`defeat_hold`, counted on mode time, §5) runs **after** that signal and is not part of the controller's own queue — `report_battle_outcome()` (and, on a loss, the Defeat Prompt) must wait for that hold too, which this test must drive explicitly rather than assume is instantaneous.
- A command that does not end the battle simply lets the queue drain to the next TURN marker — the command menu's reopening is driven by `turn_started_after_replay`, with no separate signal needed.
- The assertion "the HUD has no connection to `BattleCore`'s own... signals" is a structural check (inspecting `BattleCore`'s signal connection lists for the HUD instance), not merely a behavioural one — a HUD that happens to behave correctly while also holding a stray direct connection still fails this AC.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-040-retry-and-exit-mid-replay-clear-the-display.md`: what happens to the queue and display on Retry/Retreat/Quit instead of a normal end-of-fight.
- `story-049-boss-takeover-runs-on-one-clock.md`: the takeover's own internal timing (this story only needs that the command menu waits behind it).
- `BattleHud` itself and the Defeat Prompt screen (built in their own UI stories, not this epic).

---

## Files

- `src/battle/battle_replay_controller.gd`
- `tests/integration/battle/replay_gating_test.gd` (new)
- `src/battle/battle_mode.gd` (constructs and drives the controller; end-of-fight hold; reveal gate on `transition_finished(BATTLE)`)
- `src/battle/ui/battle_hud.gd`, `src/battle/ui/battle_command_menu.gd` (optional `replay` argument: gated signals and `get_display()` only)
- 8 existing integration tests: `settle_replay()` after a forced or fought outcome (outcome is no longer reported synchronously)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/battle/replay_gating_test.gd` OR playtest doc

**Status**: [x] Created and passing -- `tests/integration/battle/replay_gating_test.gd` (6/6); screenshots in `production/qa/evidence/story-033-replay-wired/`

---

## Dependencies

- Depends on: `BattleReplayController` (ADR-0006, no epic yet); ADR-0002 Migration Step 2 (the Battle mode, not `ChapterFlow`, must construct `BattleCore` before this controller can connect — ADR-0006's own hard prerequisite)
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-30
**Criteria**: AC-29 covered by `replay_gating_test.gd` (reveal gate, boss takeover, non-ending command, win after last beat + `victory_hold`, Defeat Prompt after `defeat_hold`, structural no-connection check over `BattleCore`'s four signals).
**Deviations**:
- `battle_replay_controller.gd` needed no change; the wiring lives in `BattleMode`, `BattleHud` and `BattleCommandMenu` (the HUD/menu keep a no-replay path for the standalone HUD demo and existing unit tests).
- No battle sprites exist, so the controller gets empty `windup`/`ko_landing` callables: every beat takes the debug path (`beat_min`). `TODO(sprite-camera)` in `battle_mode.gd`.
- Retry cancels the replay and releases the first turn at once (story 040 owns the rest).
- `BattleMode.settle_replay()` / `step_replay()` added for tests and capture tooling.
**Balance**: `BattleCore` untouched.
