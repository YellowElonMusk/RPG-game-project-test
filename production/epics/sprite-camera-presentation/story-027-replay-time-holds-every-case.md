# Story 027: replay_time holds the formula across every speed, latch and knockout case

> **Epic**: Sprite & Camera Presentation
> **Status**: Complete (2026-10-30)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-010`, `TR-presentation-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Battle Replay Ownership
**ADR Decision Summary**: `BattleReplayController` runs each beat on two clocks it owns (a scaled wind-up and an unscaled post-impact clock), advanced only by the Battle mode's `advance(delta)`; the one-level latch and the speed settings scale only the wind-up and hold clocks, never the post-impact clock.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: ADR-0006 introduces no post-cutoff API. Typed `Dictionary[Combatant, …]` is probed on 4.7.2 (compiles) for `BeatPlan`'s per-combatant fields. The gdUnit4 headless pattern with a stub `BattleCore` signal source and explicit `advance()` deltas is sufficient — no windowed or rendering verification is needed for this story.

**Control Manifest Rules (this layer)**:
- Required: "Core never imports Feature: `DioramaStage` and `CharacterSprite` must never reference `BattleReplayController`. The owning mode connects controller signals and passes clocks as `Callable`s" (Clocks and layering, ADR-0005 §7–§8, §11).
- Forbidden: no Core Layer Forbidden entry names the controller directly; ADR-0006 Implementation Guidelines govern it instead (quoted below).
- Guardrail: n/a — this story is a headless logic test with no draw calls or frame-time budget.

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-23 [L]** (P-04) `replay_time`, parametrized over: an empty replay, a plain-only replay, a replay with a Defend, and a replay with a knockout whose slump lands before `ko_hold` and one whose slump lands after it; latched from the first beat, latched mid-beat, and latched then Cancel mid-replay; Faster battle animations On, unlatched and latched; beats floored by `beat_min`; the debug path with no animation. In each case: every beat's wall time and the total equal the formula within one frame step per event; every outcome starts, impacts and ends exactly once; the hold never scales (impact to end equals `hold_i` within one frame, unless the floor extends it; a Defend has no hold); a knockout's wind-up plays at `ff_mult` like any other when latched, and its hold is `max(ko_hold, k_i)`; a mid-beat latch plays the rest of the wind-up at `ff_mult` from the next frame with the hold unchanged; the floor's padding lands in the hold so the impact frame matches the unfloored case; after Cancel, wind-ups return to 1× (or `battle_speed_mult` with Faster battle animations On) from the next frame; the latch clears so the next replay starts unlatched; unlatched with the setting Off, every wind-up plays at exactly 1×; Victory and Defeat blends and holds play at 1× even when the ending replay was latched.

---

## Implementation Notes

*Derived from ADR-0006 Decision §4 (`advance(delta)`), §6 (Speed, the latch and input) and §9 (Configuration):*

This story tests `BattleReplayController.advance()` purely headlessly, against a stub `BattleCore` signal source, with no scene tree and no rendering — it is the formula itself, not its presentation.

- `advance(delta)` clamps `dt = clampf(delta, 0.0, dt_max)`, then advances the one entry in progress; leftover `dt` past an event (impact, or an entry finishing) is dropped, never carried, so each event lands on the first frame at or after its formula time — the test tolerance is exactly one frame step per event.
- Wind-up and hold clocks scale by `plain = max(latched ? ff_mult : 1, battle_speed_on ? battle_speed_mult : 1)`; the post-impact clock (`post_impact_time`) is never scaled, by construction — the hold is the unscaled post-impact clock crossing `plan.hold`, floored so `elapsed ≥ beat_min`.
- A knockout plan's `hold` is `max(ko_hold, max over KNOCKOUT reactors of ko_landing.call(c))`; a no-reactor (Defend) plan's `hold` is `0.0`.
- `set_speed_settings()` changes the frame's speed from the next `advance()` call — a mid-entry change is well-defined because the remaining wind-up or hold runs at the new speed and the `beat_min` floor is checked against unscaled elapsed time.
- `cancel_pending_replay()` and the natural end of a replay both clear the latch unconditionally, so every replay starts unlatched (§6).
- The debug path (`windup.call(plan) == -1.0`) runs the beat at `w = beat_min − reaction_hold`, speed 1, whatever the latch or settings (§4).
- Victory and Defeat blends run on a tween at 1× (ADR-0005 §3 "Without one, it blends with a tween on itself"), never on the replay's own clock, which is why they are unaffected by a latch that was in effect when the battle ended.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-038-boss-takeover-faction-parity.md` and `story-049-boss-takeover-runs-on-one-clock.md`: the `TAKEOVER_FULL`/`TAKEOVER_SETTLE` hold durations and the boss light's blend.
- `story-040-retry-and-exit-mid-replay-clear-the-display.md`: the display reset and signal suppression on Retry/Retreat/Quit.
- `story-043-slow-frame-never-skips-a-beat.md`: the `dt_max` slow-frame clamp itself (this story only needs it to hold at default `dt`).

---

## Files

- `src/battle/battle_replay_controller.gd`
- `src/battle/beat_plan.gd`
- `tests/unit/battle/replay_time_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/replay_time_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created and passing (2026-10-30): 13/13

---

## Dependencies

- Depends on: `BattleReplayController` (ADR-0006, no epic yet — the controller this story tests does not exist in `src/battle/` yet); `PresentationConfig` (ADR-0005, `src/presentation/presentation_config.gd`, not yet built — supplies `dt_max`, `beat_min`, `ff_mult`, `battle_speed_mult`, `ko_hold`)
- Unlocks: None

---

## Completion Notes

BattleReplayController.advance() implements ADR-0006 §4/§6 (clamp, one event per call, leftover dt dropped, wind-up/hold scaled by plain speed, post-impact unscaled, beat_min floor padding the hold, debug path at beat_min - reaction_hold at speed 1, latch cleared at replay end/cancel). Deviation: PresentationConfig has no separate replay dt_max, so the controller reads follow_camera_dt_max (the knob RULE_DT_MAX already validates). Victory/Defeat 1x blends belong to the Battle mode (not built); the test asserts only that the latch is cleared before battle_ended_after_replay.

**Files**: src/battle/battle_replay_controller.gd, src/battle/beat_plan.gd, src/battle/combatant_display.gd, src/battle/replay_input_router.gd, tests/unit/battle/helpers/replay_test_kit.gd, tests/unit/battle/replay_time_test.gd
