# Story 061: PresentationConfig's load rules are validated at boot

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-014`, `TR-presentation-021`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: §5's `PresentationConfig` load validation is the GDD's full chained-knob rule list (Formulas, `replay_time`, "Load-time validation"); §9 registers it as a boot validator so each rule becomes a content error naming that rule.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff API; this is pure boot-time data validation. The full set of chained-range knobs must be exercised at both extremes (every knob at its minimum, every knob at its maximum) in addition to per-rule boundary fixtures, since a corner case at one extreme can satisfy one rule while violating another.

**Control Manifest Rules (this layer)**:
- Required: `PresentationConfig`'s load validation is the GDD's full chained-knob rule list; each rule is a boot content error naming the rule (ADR-0005 §5, §9)
- Required: Every knob lives in presentation data, never code, with load-time validation of chained ranges (ADR-0005 §5, §9)

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-56 [L]** (P-06) (config validation) Fixture configs, each breaking one load rule by a clear margin (at least 0.01), end boot in a content error naming that rule:
  - `battle_speed_mult > ff_mult − 0.25`;
  - `reaction_hold > beat_min − 0.10`;
  - `reaction_hold > ko_hold`;
  - `D ≥ reaction_hold`;
  - `dt_max ≥ beat_min`;
  - `boss_retry_hold > blend_boss + boss_hold`;
  - `victory_hold < blend_victory`;
  - `defeat_hold < blend_defeat`;
  - `set_brightness_battle > set_brightness_boss`;
  - `set_brightness_victory_settle > set_brightness_victory`;
  - `set_brightness_victory < set_brightness_boss + 0.05`;
  - a capped variant with a red transition, or a reserved sequence over the limit at the largest `ff_mult`;
  - a `set_key_fill_ratio_boss` at or below a non-boss preset's ratio;
  - `flash_rate_max > 3`, or a `flash_luma_delta` or `flash_area_min` other than its constant;
  - an overworld camera failing the horizon check at 4:3.

  A config exactly on each boundary passes. Every corner of the range-chained knobs passes, and so do one config with every knob at its minimum and one with every knob at its maximum. Those two leave out the two rules the ranges cannot guarantee (the set key:fill ratio against non-boss presets, and the overworld horizon check), which are tested by their own fixtures above.

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines:*

Each of the fourteen rules gets its own fixture `PresentationConfig` that breaks exactly that rule by at least 0.01, asserting a content error naming the rule; a fixture exactly on each boundary must pass. Two further fixtures set every chained knob to its minimum, and every chained knob to its maximum, and must both pass — except for the set key:fill ratio and overworld horizon checks, which the ranges can't guarantee at the extremes and are covered by their own dedicated fixtures instead.
- `battle_speed_mult`, `ff_mult`, `reaction_hold`, `beat_min`, `ko_hold`, `D`, `dt_max`, `blend_boss`, `boss_hold`, `boss_retry_hold`, `blend_victory`, `victory_hold`, `blend_defeat`, `defeat_hold` and the `set_brightness_*` fields are all cross-field rules on one `PresentationConfig` resource (§5).
- `flash_rate_max`, `flash_luma_delta` and `flash_area_min` are constants with fixed required values, not ranges (§12) — any deviation is a content error, not a range check.
- The overworld camera's horizon check at 4:3 and `set_key_fill_ratio_boss` are validated against the Overworld GDD rules and ADR-0005 §14's stage-light rule respectively, not against `PresentationConfig`'s own numeric ranges alone.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-062-boss-intro-animation-required.md`: boot validation of sprite-set content, a different validator family
- `story-066-impact-and-landing-frame-data-required.md`: animation frame-data boot validation

---

## Files

- `src/presentation/presentation_config.gd`
- `data/presentation/presentation_config_fixtures/`
- `tests/unit/presentation/presentation_config_validation_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/presentation/presentation_config_validation_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: None
