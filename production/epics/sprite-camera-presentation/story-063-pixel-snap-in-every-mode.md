# Story 063: A moving sprite stays pixel-snapped in every mode

> **Epic**: Sprite & Camera Presentation
> **Status**: Complete (2026-10-30)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: §2's `SpriteProjection` computes the quad rectangle in whole screen pixels, bottom-centre at the foot anchor's projection rounded half-away-from-zero, so a sprite moving by a sub-pixel amount every frame must still land on a whole-pixel quad on every frame, in both the level battle camera and the pitched Overworld/Camp cameras.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: The clip-space quad is pixel-exact with `frustum_offset` non-zero, verified under both the level battle camera and the pitched Overworld camera (verification item 10, 2026-10-22) — this story is the headless unit test of that already-verified rounding behaviour across continuous sub-pixel movement, not a new rendering path.

**Control Manifest Rules (this layer)**:
- Required: On-screen size and position come only from `T`/the pixel rectangle; the quad is never rotated or rescaled (ADR-0005 §1–§2)
- Required: `x_left = x_a − floor(frame_w·T / 2)` so an odd pixel width never starts on a half pixel (ADR-0005 §2)
- Guardrail: The quad's size never changes while only the foot anchor's sub-pixel position changes

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-58 [L]** (P-03) (pixel snap in every mode) GIVEN a sprite whose foot anchor moves 0.37 screen pixels per frame for 120 frames, in the Overworld and in Battle, THEN its quad's bottom-centre is a whole pixel on every frame, and its size never changes.

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines:*

This drives `SpriteProjection.screen_rect()` with a foot anchor advancing by 0.37 px/frame for 120 frames, under both the level battle camera's `CameraState` and the pitched Overworld camera's, and asserts the returned rectangle's bottom-centre rounds to a whole pixel every frame while `frame_w·T` and `frame_h·T` never change.
- Rounding is half-away-from-zero on the anchor's projected position (§2); the test should include frames whose unrounded position lands exactly on a half pixel to exercise that tie-break.
- The quad's size is derived only from `frame_w·T`/`frame_h·T`, never from the anchor's position, so size invariance across 120 frames is really a test that nothing in the rounding path leaks into the size calculation.
- Covering both a level and a pitched camera in one story reuses the same pure function and `CameraState` construction from story 051/055's camera work — no new camera code is introduced here.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-073-upright-card-occlusion-under-pitched-cameras.md`: the occlusion/depth side of the pitched-camera quad, as opposed to its screen-space snapping
- `story-055-resize-recomputes-punch-and-camera.md`: `T`'s recomputation on a window resize

---

## Files

- `src/presentation/sprite_projection.gd`
- `tests/unit/presentation/pixel_snap_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/presentation/pixel_snap_test.gd` — must exist and pass

**Status**: [x] Created and passing -- `tests/unit/presentation/pixel_snap_test.gd` (presentation suite 99/99, 2026-10-30)

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-001-windowed-engine-spike.md` (the spike verifies the clip-space quad is pixel-exact under both the level and pitched cameras)
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-30 (tag scp3)

Added SpriteProjection.project_to_screen() (unrounded) and round_pixel() (public half-away-from-zero); screen_rect uses them unchanged. Test drives a foot anchor 0.37 px/frame for 120 frames under the level battle camera and the pitched Overworld camera, even and odd widths, plus a non-default config: bottom-centre equals the rounded projection every frame and size never changes; frames 1 and 101 land on half pixels.

**Files**: src/presentation/sprite_projection.gd, tests/unit/presentation/pixel_snap_test.gd
