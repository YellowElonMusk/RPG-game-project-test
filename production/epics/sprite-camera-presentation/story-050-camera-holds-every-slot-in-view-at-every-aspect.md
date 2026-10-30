# Story 050: every actor slot stays inside the battle camera's view at every supported aspect ratio

> **Epic**: Sprite & Camera Presentation
> **Status**: Complete (2026-10-30)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: The battle camera uses `keep_aspect = KEEP_HEIGHT` always (never `KEEP_WIDTH` under `PROJECTION_FRUSTUM` on 4.7.2, since the CPU and GPU projections disagree there); `size` widens below 16:9 so the 16:9 horizontal view is kept, meaning the vertical view is `battle_fov` at 16:9 and wider, and wider still below it.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `KEEP_WIDTH` under `PROJECTION_FRUSTUM` is explicitly forbidden on 4.7.2 (probed, review 6: CPU/GPU projections disagree). The aspect formula `size = h_near = 2 · near · tan(battle_fov/2) · max(1, (16/9)/aspect)` and the `SpriteProjection.CameraState` matrix (built via `Projection.create_frustum_aspect()`, never `Camera3D.get_camera_projection()`) are the only sanctioned path for this measurement.

**Control Manifest Rules (this layer)**:
- Required: "**Battle camera: `PROJECTION_FRUSTUM`, pitch 0, `keep_aspect = KEEP_HEIGHT` ALWAYS.** Never `KEEP_WIDTH` under `PROJECTION_FRUSTUM` on 4.7.2... `size` recomputes on `size_changed`" (Cameras, ADR-0005 §6).
- Required: "`SpriteProjection`'s `CameraState` builds its matrix via `Projection.create_frustum_aspect()`, never `Camera3D.get_camera_projection()`. No test uses `unproject_position()` on a FRUSTUM camera" (Cameras, ADR-0005 §6).
- Forbidden: "Never use `keep_aspect = KEEP_WIDTH` under `PROJECTION_FRUSTUM` on 4.7.2 — CPU and GPU projections disagree (probed)" (ADR-0005).

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-46 [L]** (P-07) (aspect) GIVEN window sizes of 16:9, 21:9, 16:10 and 4:3, THEN every actor slot's quad lies inside the battle camera's view, and the camera keeps the 16:9 horizontal view below 16:9 and the 16:9 vertical view above it.

---

## Implementation Notes

*Derived from ADR-0005 Decision §6 (Cameras — Battle, size and aspect):*

- `size = h_near = 2 · near · tan(battle_fov / 2) · max(1, (16/9) / aspect)`, recomputed on the viewport's `size_changed` — at 16:9 and wider, this reduces to the plain `battle_fov` vertical view (the `max(1, …)` term is 1); below 16:9 (Steam Deck's 16:10, and 4:3), the vertical view widens so the *16:9 horizontal view* is preserved, which is this AC's `F_v_eff` rule stated in plain terms.
- This story's test computes, for each of the four named aspect ratios, every actor slot's projected quad (via `SpriteProjection`'s pure functions, headless — no rendering) and asserts every corner lies within `[-1, 1]` NDC (or the equivalent screen-rect bounds) under that aspect's `size`.
- "The camera keeps the 16:9 horizontal view below 16:9 and the 16:9 vertical view above it" is the two-sided statement of `KEEP_HEIGHT`'s effect: at 21:9 (wider than 16:9), the *horizontal* view exceeds 16:9's, while the vertical view stays at `battle_fov`; at 16:10 and 4:3 (narrower than 16:9), the vertical view exceeds `battle_fov` so the horizontal view stays pinned to 16:9's. The test must check both directions, not just the narrow-aspect case.
- The CPU-side projection matrix must come from `Projection.create_frustum_aspect(size, aspect, frustum_offset, near, far, false)` exactly as `SpriteProjection.CameraState` builds it (ADR-0005 §6) — this story's test must not call `Camera3D.get_camera_projection()` or `unproject_position()` on a FRUSTUM camera, both of which are confirmed to disagree with the GPU's actual rendering on 4.7.2 under `KEEP_WIDTH` and are therefore unreliable even incidentally.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-046-no-two-actor-slots-share-a-depth.md`: depth-collision validation (a separate, non-aspect concern).
- `story-039-texel-scale-holds-across-resolutions.md`: texel-grid correctness at multiple resolutions (this story is purely about frustum containment, not pixel-block geometry).
- The Overworld follow camera's own aspect widening (`story-031`, a different camera entirely).

---

## Files

- `src/presentation/sprite_projection.gd`
- `tests/unit/presentation/battle_camera_aspect_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/battle_camera_aspect_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created and passing -- `tests/unit/presentation/battle_camera_aspect_test.gd` (presentation suite 99/99, 2026-10-30)

---

## Dependencies

- Depends on: `story-001-windowed-engine-spike.md` (settles `battle_fov`, `near`, and re-measures the lens shift against `battle_framing`'s `y_h` at 16:9 and 16:10); `story-046-no-two-actor-slots-share-a-depth.md` (slot depths this story's containment check also needs)
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-30 (tag scp3)

Every shipped stage's slot quads lie inside the frame at 16:9, 21:9, 16:10 and 4:3 (default and non-default config). The CameraState matrix (create_frustum_aspect) keeps tan(F_h/2) at its 16:9 value below 16:9 and tan(F_v/2) at battle_fov at and above it, with a wider horizontal view at 21:9.

**Files**: src/presentation/battle_framing.gd, tests/unit/presentation/battle_camera_aspect_test.gd
