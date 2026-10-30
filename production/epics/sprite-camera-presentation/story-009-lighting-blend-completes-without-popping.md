# Story 009: A lighting blend reaches p=1 exactly on its last frame and never pops

> **Epic**: Sprite & Camera Presentation
> **Status**: Complete (2026-10-30)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: A blend requested with a `clock` runs from that clock, never a tween (the takeover blend); without one, it blends with a tween on itself, freezing under the Menu with everything else — and mode entry itself gives `p = 1` on its first frame, with no NaN.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff API; the blend's clock is an injected `Callable`, matching ADR-0006's clock-injection pattern.

**Control Manifest Rules (this layer)**:
- Required: A blend requested with a `clock` runs from that clock, never a tween (the takeover blend) — source: ADR-0005
- Forbidden: World shaders (the sky card's clouds included) read `mode_time` only, never `TIME` — the blend's own clock must never be `TIME` — source: ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- **AC-7 [L]** (P-06) GIVEN a boss-takeover, victory or defeat blend with `dt = 1/60` and a `blend_time` of 26.5 frames (counting the request frame as frame 0):
  - on frame 26, `p < 1 − 1e-4`;
  - on frame 27, `p = 1` and the blend reports complete;
  - on every frame, every continuous parameter equals `lerp(L_from, L_to, p)` within 1e-4.

  Mode entry gives `p = 1` on its first frame, with no NaN in any parameter.

---

## Implementation Notes

*Derived from ADR-0005 Decision §3:*

- With a `clock`, the stage evaluates `lighting_blend` from `clock.call()` every frame and runs no tween of its own — this covers the boss-takeover blend.
- Without one, it blends with a tween on itself (Victory, Defeat, and the capped-Retry blend, at 1×), which freezes under the Menu with everything else in the mode.
- Mode entry applies the profile at `blend_time = 0` (story 008), which is the `p = 1`-on-first-frame case this AC also covers — no NaN is produced at `blend_time = 0`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008 (`production/epics/sprite-camera-presentation/story-008-mode-entry-applies-lighting-before-reveal.md`): which profile is applied on which mode entry
- Story 026 (`production/epics/sprite-camera-presentation/story-026-lighting-blend-formula-is-exact.md`): the `lighting_blend` formula's exact `p = 0.5` midpoint and discrete-parameter stepping

---

## Files

- `src/presentation/diorama_stage.gd`
- `tests/unit/presentation/lighting_blend_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/lighting_blend_test.gd` — must exist and pass

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-008-mode-entry-applies-lighting-before-reveal.md`
- Unlocks: `production/epics/sprite-camera-presentation/story-026-lighting-blend-formula-is-exact.md`

---

## Completion Notes

**Completed**: 2026-10-30. `DioramaStage` now blends: `request_profile()`/`apply_profile()` capture the current values as `L_from`; with a `clock`, `refresh_clock_blend()` (called from `_process`) runs the blend from `clock.call()` and no tween is created; without one, a `tween_method` tween on the stage drives `t_blend`. `blend_time = 0` applies `p = 1` immediately (no tween, no NaN). `blend_completed` fires on the `p = 1` frame. Tests drive both paths frame by frame (`Tween.custom_step`): frame 26 `p < 1 - 1e-4`, frame 27 `p = 1` and complete, every parameter within 1e-4 of `lerp(L_from, L_to, p)`.

**Deviations**: none. `current_values` (the blended `LightingProfile`) is public so the Director and tests can read every parameter; only lights and rim are pushed to nodes so far, as before.

**Files**: `src/presentation/diorama_stage.gd`, `tests/unit/presentation/lighting_blend_test.gd`.
