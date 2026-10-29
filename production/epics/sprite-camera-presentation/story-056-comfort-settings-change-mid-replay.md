# Story 056: Comfort settings changed mid-replay apply from the next frame

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-022`, `TR-presentation-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Battle Replay Ownership; ADR-0005: Sprite & Camera Presentation; ADR-0009: Save/Load & Settings
**ADR Decision Summary**: ADR-0006 §6's `set_speed_settings(battle_speed_on, speed_up_boss)` is called on settings change and applies from the next `advance()`, scaling only the remaining wind-up or hold at the new speed; ADR-0009 §7 delivers that call through the Battle mode's injected `PresentationSettings` view, built in the composition root.
**ADR Version**: ADR-0006 2026-10-22, ADR-0005 2026-10-22, ADR-0009 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff API; this is pure state-machine logic in `BattleReplayController` plus a settings-view callback wiring. The Menu freezes `advance()` entirely (ADR-0002/ADR-0005 §7), so "the Menu closes" is the first `advance()` call after the freeze lifts, and the speed change must already be in effect by then.

**Control Manifest Rules (this layer)**:
- Required: A speed change partway through an entry applies from the next `advance()`; its remaining wind-up or hold runs at the new speed, with the `beat_min` floor checked against elapsed unscaled time (ADR-0006 §6)
- Required: No consumer holds `SettingsService` directly; the Battle mode gets `PresentationSettings` through `pre_setup`, and the replay speed settings are fields of that view (ADR-0009 §7)
- Forbidden: `SettingsService` importing or knowing about any Presentation or Feature type (ADR-0009 §7)

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-52 [L]** (P-04) (settings changed mid-replay) GIVEN a replay frozen by the Menu mid-wind-up, WHEN Faster battle animations is turned On and the Menu closes, THEN wind-ups play at `battle_speed_mult` from the next frame. WHEN instead "Speed up boss entrances" is turned On during a frozen first-encounter takeover, THEN the takeover plays at the plain-beat speed from the next frame, and the indicator turns active.

---

## Implementation Notes

*Derived from ADR-0006 and ADR-0009 Implementation Guidelines:*

The controller never polls settings itself; the Battle mode's `PresentationSettings` view calls `controller.set_speed_settings(battle_speed_on, speed_up_boss)` on the view's `changed` signal (ADR-0009 §7). Because `advance()` is never called while the Menu is open, the setting change is recorded but has no observable effect until the first post-close `advance()`, which is exactly when the AC's "from the next frame" takes effect.
- `set_speed_settings` updates the controller's stored flags only; the speed formula (`plain = max(latched ? ff_mult : 1, battle_speed_on ? battle_speed_mult : 1)`, ADR-0006 §6) is evaluated fresh on every `advance()`, so no cached per-entry speed needs invalidating.
- `TAKEOVER_FULL` uses `plain` only when `speed_up_boss` is on; turning it on mid-hold must take effect on the very next `advance()`, same as a wind-up's speed.
- `press_effective_changed` must re-fire if the setting change flips `is_press_effective()` (a `TAKEOVER_FULL` with `speed_up_boss` just turned on becomes press-effective), which drives the indicator's active/passive state per ADR-0006 §3/§6.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-074-replay-indicator-and-refusal-pulse-screenshots.md`: the indicator's visual states themselves
- The settings screen's UI and persistence (ADR-0009 §7, not this epic)

---

## Files

- `src/battle/battle_replay_controller.gd`
- `tests/integration/presentation/settings_mid_replay_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/integration/presentation/settings_mid_replay_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `BattleReplayController` (ADR-0006, no epic yet); the settings service (ADR-0009, not built)
- Unlocks: None
