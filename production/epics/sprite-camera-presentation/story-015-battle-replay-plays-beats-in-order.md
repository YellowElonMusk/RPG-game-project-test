# Story 015: A battle replay plays beats in log order, impacting, holding and ending on the controller's own clocks

> **Epic**: Sprite & Camera Presentation
> **Status**: Complete (2026-10-30)
> **Layer**: Core
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-009`, `TR-presentation-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Battle Replay Ownership (primary), ADR-0005: Sprite & Camera Presentation (secondary — presentation consumes the controller's clocks)
**ADR Decision Summary**: `BattleReplayController` queues every `BattleCore` signal in emission order with a display snapshot after each one, turns each outcome into a beat plan, and runs each beat on two owned clocks (a scaled wind-up, an unscaled post-impact clock), advanced only by the Battle mode's `advance(delta)`.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: ADR-0006 itself is LOW risk (no post-cutoff API; `RefCounted` + typed signals, the same pattern `BattleCore` already uses). The overall story risk is HIGH because presentation (`CharacterSprite`, `DioramaStage`) consumes these clocks under ADR-0005's still-open verification items (12)–(16).

**Control Manifest Rules (this layer)**:
- Required: Core never imports Feature: `DioramaStage` and `CharacterSprite` must never reference `BattleReplayController`. The owning mode connects controller signals and passes clocks as `Callable`s — source: ADR-0005
- Forbidden: Never let `DioramaStage` or `CharacterSprite` hold a direct reference to `BattleReplayController` — source: ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- **AC-13 [I]** (P-04) GIVEN an outcome log of N entries from a real, seeded `BattleCore`, played unlatched, latched, and with Faster battle animations On, THEN:
  - **order:** beats play in log order, and each outcome starts, impacts and ends exactly once, in that order;
  - **impact:** lands on the first frame where the wind-up reaches `w_i`, computed from the action animation's `impact_frame`. On that frame every reacting combatant's reaction and the punch (if any) start, and the actor shows no reaction;
  - **end:** comes `hold_i` of 1× time after impact, or later when the `beat_min` floor extends it. No number shows before the end;
  - **frames:** on every frame before impact, the actor's frame follows the wind-up clock, and from impact to the end, every reaction frame follows the post-impact clock, at every tested speed. An animation that has run out shows its last frame;
  - **after the beat:** the actor is in `idle`; a `hit`, `heal` or `status` reactor finishes its reaction, then is in `idle`; a knocked-out combatant holds the last frame of `knockout` until the battle ends;
  - **back-to-back actor:** GIVEN a Bureaucratia enemy turn of Defend then Attack, THEN on the second beat's first frame that enemy shows `attack` frame 0, and on no frame between the two beats does it show `idle`;
  - **debug path:** with validation skipped and no action animation, impact lands at `beat_min − reaction_hold` at every speed.

---

## Implementation Notes

*Derived from ADR-0006 Summary and Decision, and ADR-0005 Decision §1:*

- `BattleReplayController` (`RefCounted`, `src/battle/`, owned by the Battle mode) queues every `BattleCore` signal in emission order, with a display snapshot after each one, never modifying `BattleCore`.
- Each outcome becomes a **beat plan** (actor action, per-combatant reactions and HP changes, punch, protection), run on two owned clocks: a scaled wind-up and an unscaled post-impact clock, advanced only by the Battle mode's mode-time `advance(delta)`.
- Impact lands on the first frame the wind-up reaches `w_i`, computed from the action animation's `impact_frame`; knockout wind-ups are plain beats (no beat is protected in MVP).
- Beat-driven frames (wind-up, follow-through, reactions, boss `intro`) are set by `CharacterSprite` from these clocks every frame; its own `AnimatedSprite3D` playback stays stopped (ADR-0005 §1's call order: `stop()` once in `setup()`, then `animation` before `frame`).
- `DioramaStage` and `CharacterSprite` must never reference `BattleReplayController` directly — the Battle mode connects its signals and passes the clocks in as `Callable`s.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 016 (`production/epics/sprite-camera-presentation/story-016-replay-never-mutates-battlecore.md`): HP/status integrity and HUD-display equivalence across the whole replay
- Story 017 (`production/epics/sprite-camera-presentation/story-017-move-outcome-shapes-match-the-table.md`): per-move pose/reaction/number/punch shape

---

## Files

- `src/battle/battle_replay_controller.gd`
- `src/battle/beat_plan.gd`
- `src/presentation/character_sprite.gd`
- `tests/integration/presentation/battle_replay_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/presentation/battle_replay_test.gd` — must exist and pass

**Status**: [x] Created and passing — `tests/integration/presentation/battle_replay_test.gd` 14/14 (2026-10-30)

---

## Dependencies

- Depends on: `BattleReplayController` (ADR-0006, no epic yet), `production/epics/sprite-camera-presentation/story-001-windowed-engine-spike.md`, `production/epics/sprite-camera-presentation/story-012-one-hit-punch-per-beat-on-impact.md`
- Unlocks: `production/epics/sprite-camera-presentation/story-016-replay-never-mutates-battlecore.md`, `production/epics/sprite-camera-presentation/story-017-move-outcome-shapes-match-the-table.md`

---

## Completion Notes

**Completed**: 2026-10-30
- Integration test drives a real seeded `BattleCore` (S1 hits E1, S2 knocks out E2, E1's Defend-then-Attack turn) through `BattleReplayController`, unlatched, latched and Faster On, with default and a non-default `PresentationConfig`: order, impact frame, end (`hold_i` or `beat_min`), no number before the end, wind-up and unscaled post-impact clocks, back-to-back actor, debug path.
- Added `BeatPlan.windup_for(impact_frame, fps)` (the `w_i` the Battle mode's `windup` callable returns) and `BeatPlan.frame_at(clock, fps, count)` (beat-driven frame, holds the last frame once run out). `CharacterSprite` unchanged: it already takes frames through `show_frame()` and never references the controller.
- Deviation: the back-to-back case uses a test `FactionRule` returning Defend then Attack (Bureaucratia's turn shape) rather than the RNG-driven Bureaucratia rule. The "after the beat" idle/knockout-hold poses are covered only as clocks (`frame_at` holds the last frame); no pose state machine exists yet.
- Not done: wiring the controller into `BattleMode`/`BattleHud` (no 3D stage in Battle mode yet, so nothing player-visible changed; no screenshot). That wiring is story 033's scope.
- Files: `src/battle/beat_plan.gd`, `tests/integration/presentation/battle_replay_test.gd`.
