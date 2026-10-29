# Story 006: The battle camera only changes through frustum_offset: lens shift plus the hit-punch

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-002`, `TR-presentation-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: The battle camera is level (`PROJECTION_FRUSTUM`, pitch 0, `keep_aspect = KEEP_HEIGHT` always); its position, rotation and `near` never change in a fight, `size` changes only on resize, and `frustum_offset` carries the stage's base lens shift plus the hit-punch.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `frustum_offset` is in near-plane units and +y moves the image down — VERIFIED 2026-10-22 (item 11), residual re-measurement against `battle_framing`'s `y_h` happens in story 001's spike. `KEEP_WIDTH` under `PROJECTION_FRUSTUM` is a confirmed BLOCKING regression on 4.7.2 (CPU/GPU projections disagree) — never used.

**Control Manifest Rules (this layer)**:
- Required: Battle camera: `PROJECTION_FRUSTUM`, pitch 0, `keep_aspect = KEEP_HEIGHT` ALWAYS. `size` recomputes on `size_changed`; `frustum_offset` carries lens shift + hit-punch — source: ADR-0005
- Required: The camera's position, rotation and `near` never change in a fight; `size` changes only on a window resize — source: ADR-0005
- Forbidden: Never set the battle camera's `h_offset`/`v_offset` (they stay 0), and never use a translation or rotation shake — source: ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- **AC-4 [L]** (P-07) GIVEN a full battle with hit-punches, THEN the battle camera's position and rotation never change and its pitch is 0. Its `size`, `near` and `keep_aspect` (always `KEEP_HEIGHT`) never change except on a window resize. Only its lens shift changes, and on every frame it equals the stage's base shift plus the `hit_punch` offset.

---

## Implementation Notes

*Derived from ADR-0005 Decision §6:*

- `size = h_near = 2 · near · tan(battle_fov / 2) · max(1, (16/9) / aspect)`, recomputed on the viewport's `size_changed`.
- Lens shift places the horizon at the stage's `horizon_frac`: `frustum_offset.y = −(0.5 − horizon_frac) · h_near`.
- The punch adds `(px_x · h_near / H, −px_y · h_near / H)` to `frustum_offset`, where `(px_x, px_y)` is the GDD's `hit_punch` offset in screen pixels, y down.
- `SpriteProjection`'s `CameraState` builds its matrix via `Projection.create_frustum_aspect(size, aspect, frustum_offset, near, far, false)`, never `Camera3D.get_camera_projection()`; no test uses `unproject_position()` on a FRUSTUM camera.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007 (`production/epics/sprite-camera-presentation/story-007-camp-and-title-cameras-never-move.md`): Camp and Title's fixed cameras
- Story 012 (`production/epics/sprite-camera-presentation/story-012-one-hit-punch-per-beat-on-impact.md`): when and how often the punch is triggered
- Story 024 (`production/epics/sprite-camera-presentation/story-024-hit-punch-formula-is-pixel-exact.md`): the `hit_punch` offset formula itself

---

## Files

- `src/presentation/sprite_projection.gd`
- `src/presentation/diorama_stage.gd`
- `tests/unit/presentation/battle_camera_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/battle_camera_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-001-windowed-engine-spike.md`, `production/epics/sprite-camera-presentation/story-004-sprite-projection-pixel-exact-quad.md`
- Unlocks: `production/epics/sprite-camera-presentation/story-007-camp-and-title-cameras-never-move.md`, `production/epics/sprite-camera-presentation/story-012-one-hit-punch-per-beat-on-impact.md`, `production/epics/sprite-camera-presentation/story-022-battle-framing-keeps-every-slot-in-view.md`, `production/epics/sprite-camera-presentation/story-024-hit-punch-formula-is-pixel-exact.md`
