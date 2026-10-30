# Story 023: The follow camera's dead zone, tau and ground-footprint clamp match the formula exactly

> **Epic**: Sprite & Camera Presentation
> **Status**: Complete (2026-10-29)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: The Overworld's perspective `FollowCamera` moves position only, at a fixed yaw and pitch, with `keep_aspect = KEEP_HEIGHT` and `fov` widened below 16:9 by the same `F_v_eff` rule as the battle camera; the GDD's `follow_camera` formula, dead zone, `tau`, `dt_max` clamp and ground-footprint clamp are implemented exactly.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Story 001's spike probes the perspective camera path at 16:10 and 4:3, which this formula's aspect/footprint cases depend on; the Overworld ADR (ADR-0012, no epic yet) decides what the camera follows, which this story takes as an injected target.

**Control Manifest Rules (this layer)**:
- Required: `LightingProfile` and `PresentationConfig` are data (`.tres`); every lighting/FOV/camera/texel/timing value comes from them, never literals — source: ADR-0005
- Forbidden: Never add a second `Camera3D` or `WorldEnvironment` to a mode scene that already has a `DioramaStage` — source: ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- **AC-20 [L]** (P-07) **follow_camera**:
  - an offset inside the dead zone moves the camera 0, and each frame's movement equals the formula within 1e-4 m;
  - with a static target starting outside the dead zone, runs at 60 fps and at 30 fps agree within 1e-3 m at every shared 1/30 s step, and the camera never passes the target;
  - a frame with `dt = 0.5` moves the camera exactly as `dt = dt_max` does;
  - with the dead zone at 0 and a static target 2 m away, at `tau` = 0.15, 0.17 and 0.18 and 60 fps, at least 75% of the distance is covered by frame 15;
  - **footprint:** the Formulas example camera gives `a_near`, `a_far` and `w_far` of 5.40, 10.15 and 9.03 m at 16:9, within 1e-2. With the target driven into every edge and corner of a 60 × 40 m map, at 16:9, 21:9 and 4:3, the ground hits of the view's four corner rays lie inside the map on every frame;
  - **horizon:** a camera config with `pitch − F_v_eff(4:3)/2` 0.1° below `horizon_margin` fails at load, even though it passes at 16:9.

---

## Implementation Notes

*Derived from ADR-0005 Decision §6:*

- `FollowCamera` moves position only, at fixed yaw and pitch; `keep_aspect = KEEP_HEIGHT` and `fov` widens below 16:9 by the same `F_v_eff` rule the battle camera uses (§6), so both cameras share one aspect-widening formula.
- The dead zone, `tau`-based ease and `dt_max` clamp are all pure formula behaviour, headless-testable against an injected target position and `dt` — no scene-tree dependency needed for the frame-rate-agreement and dead-zone cases.
- The footprint clamp keeps the view's four ground-ray corner hits inside the map bounds at every tested aspect; the `horizon_margin` load-time check guards against a camera config that would show above the map's horizon at a narrower aspect even though it passes at 16:9.
- The GDD's "Overworld ADR decides what it follows" (§6) means this story takes the followed target as an injected value/`Callable`, not a direct reference to party or map state.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The Overworld's own party-anchor and map-bounds systems (ADR-0012, no epic yet) — this story implements the camera formula against an injected target only

---

## Files

- `src/presentation/follow_camera.gd`
- `tests/unit/presentation/follow_camera_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/follow_camera_test.gd` — must exist and pass

**Status**: [x] `tests/unit/presentation/follow_camera_test.gd` — 15/15 passing; full suite 631/631 green

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-001-windowed-engine-spike.md`, the Overworld (ADR-0012, no epic yet)
- Unlocks: None

---

## Completion Notes

- `src/presentation/follow_camera.gd`: `FollowCamera extends Camera3D`. Pure static functions implement every formula piece exactly (`effective_vertical_fov_degrees` = `F_v_eff`, `horizontal_fov_degrees` = `F_h`, `compute_footprint` → `Footprint` value object, `validate_horizon` fixed at 4:3, `clamp_or_centre`, `dead_zone`, `ease_step`, `clamp_to_footprint`). Instance methods `advance()`/`snap_to()` drive `cam_ground` against an injected target, `aspect` and map bounds; `apply_fov()`/`apply_transform()` are thin, documented best-effort mappings onto the live `Camera3D` (untested convention — yaw=0 is world -Z — since the Overworld's own ground-to-world axis convention isn't decided yet, ADR-0012). `from_config()` reads the new `PresentationConfig.follow_camera_*` fields and runs the horizon guard.
- `src/presentation/presentation_config.gd`: extended (not in the story's own Files list, but named explicitly by the build brief and invited by the story-004 stub's own header, "widen this file in place here") with a `Follow Camera` export group: `follow_camera_height/pitch_degrees/fov_degrees/dead_zone_fraction/tau/dt_max/horizon_margin_degrees`, matching GDD defaults.
- Deviations/assumptions: (1) `dz.y`'s "footprint half-extent" is interpreted as `(a_near + a_far) / 2` (the GDD states this only for `x` = `w_far` explicitly); (2) the node's ground→world transform convention (`apply_transform`) is a placeholder the Overworld may override, not covered by an AC.
- Verified: the GDD worked example (`a_near=5.40, a_far=10.15, w_far=9.03` at 16:9) reproduces exactly; 60fps/30fps ease agreement is exact by construction (exponential decay is step-size-invariant); 75%-by-frame-15 holds at tau 0.15/0.17/0.18; horizon guard checks 4:3 specifically, not 16:9.

**Test Evidence Status**: `tests/unit/presentation/follow_camera_test.gd` — 15/15 passing. Full suite: 631/631 green (`$TEMP/scp023_full.log`).

- Status synced 2026-10-30 from commit 9558205.
