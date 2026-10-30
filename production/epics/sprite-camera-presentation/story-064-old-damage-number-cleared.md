# Story 064: A stale damage number is cleared before the next one lands

> **Epic**: Sprite & Camera Presentation
> **Status**: Complete (2026-10-30)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Battle Replay Ownership; ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: ADR-0006 §2/§7 derives each beat's `hp_changes` from that beat's own `BeatPlan`, and the HUD reads displayed numbers only through the controller's state (ADR-0006 §3, `display_resynced` and `beat_finished`), so a second beat on the same target must present its own number once the first beat's has been cleared by `beat_finished`.
**ADR Version**: ADR-0006 2026-10-22, ADR-0005 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff API; this is controller/HUD-binding logic. `beat_finished` fires after the entry's snapshot becomes the displayed state (ADR-0006 §3), which is the signal the HUD's number widget must use to retire the previous beat's number before the next beat's `beat_impact` shows a new one.

**Control Manifest Rules (this layer)**:
- Required: Displayed state changes at `beat_finished`, before the signal is emitted (ADR-0006 §3)
- Required: HUD reads HP, MP, status, round and floating numbers only through the replay's displayed state (ADR-0005 TR-presentation-013, ADR-0006 §8)
- Guardrail: No stale number is ever shown over a target once its owning beat has ended

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [x] **AC-59 [L]** (P-04) (old number cleared) GIVEN two consecutive beats on the same target, latched, THEN on the second beat's impact frame the first beat's number is removed, and no number is over the target from that frame until the second beat ends.

---

## Implementation Notes

*Derived from ADR-0006 Implementation Guidelines:*

Each beat's number display is scoped to that beat's own lifetime: it appears at `beat_impact` and must be gone by the time the next beat's `beat_impact` fires on the same target, with no frame in between where both numbers (or neither, incorrectly) are shown outside the specified window.
- With the latch set, two consecutive `OUTCOME` entries on the same target run back-to-back (ADR-0006 §4/§6); the first beat's `beat_finished` retires its number before the second beat's `beat_started`/`beat_impact` begins.
- The window to assert is exact: from the second beat's impact frame onward, no number is over the target until that second beat ends (its own `beat_finished`), i.e. the first beat's number must not linger even one frame into the second beat's impact.
- This is presentation-side widget logic bound to `beat_impact`/`beat_finished`, not a new controller field — the controller already exposes exactly the signals and `BeatPlan.hp_changes` needed (ADR-0006 §2, §7).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-070-outcome-numbers-and-round-on-the-hud.md`: the full set of numbers and round display for one replay
- `story-065-presses-before-the-reveal-do-nothing.md`: latch timing itself, as opposed to number display

---

## Files

- `src/battle/battle_replay_controller.gd`
- `src/battle/beat_plan.gd`
- `tests/unit/battle/old_number_cleared_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/battle/old_number_cleared_test.gd` — must exist and pass

**Status**: [x] Created and passing — `tests/unit/battle/old_number_cleared_test.gd` 3/3 (2026-10-30)

---

## Dependencies

- Depends on: `BattleReplayController` (ADR-0006, no epic yet)
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-30
- New `BeatNumbers` (`src/battle/beat_numbers.gd`, RefCounted, bound to the controller's signals): a beat's numbers (`BeatPlan.numbers()`) appear at its `beat_finished` (AC-13: none before the end); a later beat's `beat_impact` removes the number over every combatant it touches; `display_resynced` clears all. No controller or `BeatPlan` change was needed.
- Deviation: the Implementation Notes say a number "appears at `beat_impact`"; AC-13 (story 015) forbids any number before the end, so numbers appear at `beat_finished`. AC-59's window holds either way.
- Not wired into `BattleHud` yet (HUD still floats numbers off `BattleCore.action_resolved`; story 033/070).
- Files: `src/battle/beat_numbers.gd`, `tests/unit/battle/old_number_cleared_test.gd`.
