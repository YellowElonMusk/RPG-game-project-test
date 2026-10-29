# Story 066: Impact and landing frame data is required at boot

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: §9's boot validators require `impact_frame` on every action animation and `land_frame` on every `knockout`, an `intro` no longer than `boss_hold` at 1×, and no duplicate move-specific animation names within a set — all content errors naming the set and animation.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff API; this is boot-time data validation. The ADR's own worked example ties frame durations directly to the `replay_time` formula's `w_i`/`k_i` values, which this story's fixtures reuse to prove the validator reads the same frame data the replay formulas consume.

**Control Manifest Rules (this layer)**:
- Required: `impact_frame` on every action animation, and `land_frame` on every `knockout`; `intro` no longer than `boss_hold` at 1×; no duplicate move-specific animation names within a set (ADR-0005 §9)
- Required: Every boot validation failure is a content error naming the set and animation (ADR-0005 §9)

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-61 [L]** (P-06) (impact and landing data) Each of these ends boot in a content error naming the set and animation:
  - an `attack` or `defend` with no `impact_frame`, or one equal to its frame count;
  - a `knockout` with no `land_frame`, or one equal to its frame count;
  - a boss whose `intro` lasts longer than `boss_hold` at 1×;
  - a set with two move-specific animations keyed by the same move name.

  An `attack` with frame durations 1, 1, 2, 1 at 10 fps and `impact_frame` 3 gives `w_i = 0.4` s. A `knockout` with the same durations and `land_frame` 2 gives `k_i = 0.2` s.

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines:*

Four independent validator rules, each with its own fixture sprite set: a missing or out-of-range `impact_frame` on `attack`/`defend`; a missing or out-of-range `land_frame` on `knockout`; an `intro` exceeding `boss_hold` at 1×; and a duplicate move-specific animation key within one set.
- `impact_frame`/`land_frame` equal to the animation's own frame count is explicitly invalid — "equal to its frame count" means the index is past the last real frame, with no post-impact/post-landing frames to react from.
- The worked example (durations 1,1,2,1 at 10 fps, `impact_frame` 3 → `w_i = 0.4` s; `land_frame` 2 → `k_i = 0.2` s) is the exact formula ADR-0006 §1's `windup`/`ko_landing` callables compute — this validator's fixtures should use the same numbers so a future change to either side is caught by both.
- Each failure names both the sprite set and the specific animation, not just the set, since a set can have many action/knockout animations.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-062-boss-intro-animation-required.md`: the presence of a `front` `intro` at all, as opposed to its duration
- `story-061-presentation-config-load-validation.md`: `PresentationConfig`'s own numeric load rules

---

## Files

- `src/presentation/presentation_validators.gd`
- `tests/unit/presentation/impact_landing_validation_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/presentation/impact_landing_validation_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: None
