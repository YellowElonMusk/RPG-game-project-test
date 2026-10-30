# Story 099: `chase_visibility` (I14) passes the shipped camera at 4:3, 16:9 and 21:9, including the tilt-shift blur bounds

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-017`, `TR-overworld-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0005: Sprite & Camera Presentation (§6 `follow_camera` footprint)
**ADR Decision Summary**: The overworld camera's ground footprint (from `sprite-camera-presentation.md`'s `follow_camera`) must guarantee `R_vis ≥ see_m` at 4:3, 16:9 and 21:9, with the tilt-shift blur bounds measured from the leader rather than the camera focus, validated as part of `OverworldConfig.validate()`'s I14.
**ADR Version**: ADR-0012 2026-10-23 · ADR-0005 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Camera projection geometry and depth-of-field are HIGH-risk, post-cutoff rendering areas (ADR-0005 Engine Compatibility: 4.5 Shader Baker/SMAA, 4.6 glow/AgX, 4.7 HDR output). `d_cam(s)`'s view-space-depth semantics (not Euclidean distance) are confirmed by ADR-0005 Step 1; `CameraAttributesPractical` DOF parameters are listed there as NOT SOURCEABLE pre-cutoff and still to verify.

**Control Manifest Rules (this layer)**:
- Required: "the overworld camera must satisfy `chase_visibility` at 4:3, 16:9 and 21:9 including tilt-shift blur bounds measured from the leader" — source: ADR-0012 §7, TR-overworld-017
- Required: "Records never contain file paths; tuning comes from `OverworldConfig` or records, validated by `OverworldConfig.validate()` (invariants I1–I18, each error names its ID)" — source: ADR-0012 §9

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-39 [L] (`chase_visibility`, I14)** With presentation's example camera (pitch 30°, F_v 20°), h 10 m fails and names the binding aspect and edge. h 11.5 m passes at 4:3, 16:9 and 21:9 at the default dz and tau. Blur fixtures: `dof_far_begin` below `d_cam(+s_blur)` fails; `dof_near_end` above `d_cam(−s_blur) − H_max·sin(pitch)` fails; a fixture that passes when measured from the focus but fails with the leader at the dead-zone edge (`s_blur` vs `see_m`) fails. The shipped config passes at all three aspects.

---

## Implementation Notes

*Derived from ADR-0012 §7 and GDD Formulas ("chase_visibility"):*

- Using presentation's example camera (pitch 30°, F_v 20°, dz 10%, tau 0.17): h 10 m must fail and the error must name the binding aspect and edge — 16:9 and 21:9 bind on the near edge (5.40 − 0.54 − 0.595 = 4.27 < `see_m` 4.70), 4:3 binds on the side (4.26).
- h 11.5 m must pass at all three aspects (4:3 side 4.99, 16:9 near 5.00, 21:9 near 5.00).
- Blur fixtures: `dof_far_begin` set below `d_cam(+s_blur)` must fail; `dof_near_end` set above `d_cam(−s_blur) − H_max·sin(pitch)` must fail. A fixture that would pass if the blur bound were measured from the camera **focus** but fails once measured from the **leader** at the dead-zone edge (`s_blur` vs `see_m`) must fail — this is the rev-3 correction the Formulas section calls out explicitly.
- The shipped config (the one `project.yaml`/`OverworldConfig` actually ships) must pass at 4:3, 16:9 and 21:9.
- This story proves the camera-geometry half of rule 12's visibility guarantee; the set-occluder half is story 087's `[VF]` capture proof, which assumes this story's result.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Set-occluder visibility (story 087).
- The other seventeen invariants (story 098).

---

## Files

- `src/overworld/overworld_config.gd`
- `tests/unit/overworld/chase_visibility_validation_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/chase_visibility_validation_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-098-config-invariants-i1-i18.md`, `production/epics/sprite-camera-presentation/story-023-follow-camera-matches-the-formula.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-087-patrol-visibility-before-the-notice-radius.md`

## Completion Notes (2026-10-30)

- `ChaseVisibility.validate(cfg, presentation, profile)` is I14. At each aspect it reports the binding edge (`R_vis = min R_e`). When the profile blurs, it checks:
  - `dof_near_end <= d_cam(-s_blur) - H_max*sin(pitch)`
  - `dof_far_begin >= d_cam(+s_blur)`
  - with `s_blur = see_m + dz_y + walk_speed*tau`, measured from the leader, and `d_cam(s) = h/sin(pitch) + s*cos(pitch)`.
- `edge_reach_at` now shares `_edges()`. The GDD numbers reproduce exactly: 4.26/4.27/4.27 at 10 m, 4.99/5.00/5.00 at 11.5 m, 4.68 at the ceilings, and `s_blur` 5.84.
- **Decision (OQ-1, taken autonomously per the standing rule):** the shipped follow camera height goes from 10.0 to 12.0 m, the GDD's proposal. 10.0 m failed I14 at every aspect. 12.0 m passes at any dz/tau in range.
  - New `PresentationConfig.overworld_card_height_max_m` (`H_max`), a 2.0 m placeholder.
  - The shipped overworld profiles (far blur at 30 m, no near blur) pass: `d_cam(+s_blur)` is about 29.3 m at 4:3. That margin is thin; flagged for Presentation.
- `validate_maps` (CI) runs I14 on the shipped camera with both overworld profiles. Boot-time validation waits on GameRoot building configs from data.
- The camera change makes story 087's walk-in captures (taken at 10 m) stale; they were recaptured at 12 m.
- Mutations checked: blur measured from the focus, `H_max` dropped, and the dead zone not projected on the side normal each fail a test here.
