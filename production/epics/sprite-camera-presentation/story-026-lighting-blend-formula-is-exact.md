# Story 026: lighting_blend reaches p=0.5 at half its duration and never jumps by more than one frame-step

> **Epic**: Sprite & Camera Presentation
> **Status**: Complete (2026-10-30)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-004`, `TR-presentation-021`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: `lighting_blend` is a pure formula producing `p` from elapsed time against `blend_time`; a blend requested mid-blend restarts from the current values rather than the old target, `blend_time = 0` gives `p = 1` with no NaN, and discrete parameters step cleanly between frames rather than interpolating.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff API; this is a pure, headless-testable formula shared by both the tween-driven path (Victory/Defeat/capped-Retry) and the clock-driven path (the takeover blend).

**Control Manifest Rules (this layer)**:
- Required: `LightingProfile` and `PresentationConfig` are data (`.tres`); every lighting/FOV/camera/texel/timing value, `blend_time` included, comes from them, never literals — source: ADR-0005
- Required: A blend requested with a `clock` runs from that clock, never a tween — source: ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- **AC-22 [L]** (P-06) **lighting_blend**:
  - at `t_blend = blend_time / 2`, called directly, `p = 0.5`;
  - a blend requested mid-blend starts from the current values, and no frame-to-frame change exceeds the formula's largest single-frame step;
  - `blend_time = 0` gives `p = 1` with no NaN;
  - with a 26.5-frame blend, a discrete parameter has its old value on frame 13 and its new value on frame 14.

---

## Implementation Notes

*Derived from ADR-0005 Decision §3:*

- `lighting_blend` is the pure function underlying both blend paths described in §3: the clock-driven takeover blend and the self-tween path for Victory, Defeat and the capped-Retry blend.
- "A blend requested mid-blend starts from the current values" means re-request must capture the in-progress blended values as the new `L_from`, never jump back to the blend's original starting point.
- Discrete (non-interpolated) parameters step exactly at the frame where `p` crosses their switch point — the 26.5-frame example (also used by story 009's AC-7) pins frame 13 to the old value and frame 14 to the new one.
- `blend_time = 0` is the mode-entry case (story 008/009): it must resolve to `p = 1` immediately, with no division-by-zero NaN anywhere in the formula.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008 (`production/epics/sprite-camera-presentation/story-008-mode-entry-applies-lighting-before-reveal.md`): which profile is requested on which mode entry
- Story 009 (`production/epics/sprite-camera-presentation/story-009-lighting-blend-completes-without-popping.md`): the boss-takeover/victory/defeat blend's own completion timing

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

- Depends on: `production/epics/sprite-camera-presentation/story-009-lighting-blend-completes-without-popping.md`
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-30. `DioramaStage.blend_progress(t, blend_time)` (static, pure) and `DioramaStage.lighting_blend(from, to, p)` implement the GDD formula: smoothstep `p`, `blend_time <= 0` returns 1; floats and Vector3 lerp, colors lerp in linear space (`srgb_to_linear`), bool flags switch at `p >= 0.5`, `p >= 1` returns an exact copy of the target. Tests: `p = 0.5` at half duration for the config's blend lengths and a non-default config; a mid-blend re-request starts from the captured values, and each frame's change stays within the largest single-frame `p` step times the span; with a 26.5-frame blend, discrete flags are old on frame 13 and new on frame 14.

**Deviations**: none.

**Files**: `src/presentation/diorama_stage.gd`, `tests/unit/presentation/lighting_blend_test.gd`.
