# Story 067: End-of-fight holds complete before the outcome is reported

> **Epic**: Sprite & Camera Presentation
> **Status**: Done
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Battle Replay Ownership
**ADR Decision Summary**: §5's "End of the fight" rule has the Battle mode, never the controller, request the Victory/Defeat light and count `victory_hold`/`defeat_hold` on mode time before calling `report_battle_outcome()`; these holds cannot be shortened by the latch, consume Confirm/Cancel presses, and are cancelled by any exit transition.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff API. These holds are deliberately owned by the Battle mode (a `GameMode`, ADR-0002), not `BattleReplayController` — "Core never imports Feature" (ADR-0005 §7) means the hold's own timer lives beside the mode, with the controller only having already emitted `battle_ended_after_replay(won)` to start it.

**Control Manifest Rules (this layer)**:
- Required: End-of-fight holds are the Battle mode's, not the controller's; they are not part of a replay and the latch can't shorten them (ADR-0006 §5)
- Required: During a hold, `confirm`, `fast_forward` and `cancel` presses are consumed and do nothing (ADR-0006 §5, §6)
- Required: A hold is cancelled by any `transition_started` away from the current battle (ADR-0006 §5)

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-62 [L]** (P-04, P-05) (end-of-fight holds) GIVEN a battle won or lost on its last beat:
  - the outcome reaches Game State `victory_hold` or `defeat_hold` after the last beat ends, within one frame, and the Victory or Defeat blend has completed by then;
  - a latch set during the final replay doesn't shorten either hold;
  - a Confirm or Cancel pressed during the hold does nothing and doesn't carry into the results screen or Defeat Prompt;
  - Quit to Title during the hold cancels it, and the outcome is never reported.

---

## Implementation Notes

*Derived from ADR-0006 Implementation Guidelines:*

On `battle_ended_after_replay(won)`, the Battle mode requests the Victory or Defeat light and starts counting `victory_hold`/`defeat_hold` on mode time, calling `report_battle_outcome()` (ADR-0002) only once the hold completes — and only then, so the Victory/Defeat blend has had the full hold duration to finish first.
- A latch set during the final replay (the beats leading up to `battle_ended_after_replay`) has no effect on the hold itself: the hold starts fresh, on mode time, at 1×, once the replay ends — the latch's speed multipliers apply only to beats, never to this hold.
- `handle_action()`'s routing (ADR-0006 §6) must treat "during the end-of-fight hold" the same as `GATED`: Confirm, `fast_forward` and Cancel are consumed and produce no effect, and nothing carries into the results screen or Defeat Prompt that opens after.
- Quit to Title during the hold is an exit transition (`transition_started(BATTLE, TITLE)`), which per §5 "Exit" cancels the hold outright — `report_battle_outcome()` must never be called for a battle being left this way.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-070-outcome-numbers-and-round-on-the-hud.md`: the HUD's own number/round display during the replay that precedes this hold
- The Victory/Defeat `LightingProfile` blends themselves (built by an earlier `src/presentation/` story)

---

## Files

- `src/battle/battle_replay_controller.gd`
- `tests/unit/battle/end_of_fight_holds_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/battle/end_of_fight_holds_test.gd` — must exist and pass

**Status**: [x] Created and passing -- `tests/unit/battle/end_of_fight_holds_test.gd` (4 tests); full suite 1857/1857, exit 0, 0 orphans (2026-10-31).

---

## Dependencies

- Depends on: `BattleReplayController` (ADR-0006, no epic yet); the Battle mode (`GameMode`, ADR-0002)
- Unlocks: None
