# Story 073: Upright-card occlusion holds under pitched cameras

> **Epic**: Sprite & Camera Presentation
> **Status**: Done (2026-10-31): [L] PASS (`card_depth_test.gd`); [C] Overworld capture PASS with both negative controls failing as expected; Camp [C] blocked (no Camp 3D scene); lead sign-off pending
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-31 (card plane amended by story 039)

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: §2's card-depth computation casts each quad corner's view ray through the upright card at the foot anchor and relies on perspective-correct interpolation with no `DEPTH` write, verified pixel-exact under both the level battle camera and the pitched Overworld camera (item 10); this story is the pure-function unit test of that depth formula plus the capture-measured proof that it occludes correctly in the pitched Overworld/Camp cameras specifically.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: The clip-space quad's depth is exact per pixel because the card is planar and the rasterizer interpolates clip space perspective-correctly, with early-z on (verified item 10, 2026-10-22). Under a pitched camera, `fragment()` derives the texel UV from `FRAGCOORD` rather than relying on perspective-correct UV interpolation on a tilted card, which would otherwise give non-uniform texels on screen (§2).

**Control Manifest Rules (this layer)**:
- Required: Depth is exact per pixel, with no `DEPTH` write, because the card is planar and the rasterizer interpolates clip space perspective-correctly; early-z stays on (ADR-0005 §2)
- Required: Under a pitched camera, `fragment()` derives the texel UV from `FRAGCOORD` and the pixel rectangle (ADR-0005 §2)
- Required: The capture tool's ID pass isolates per-class pixels on the same frame (ADR-0005 §13)

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-68 [L]+[C]** (upright-card occlusion, pitched cameras), in the Overworld and Camp, for a sprite standing 0.5 m in front of a fixture wall:
  - **[L]** (P-03): the pure card-depth function returns, for every fixture view ray through the sprite's pixel rectangle, the view-space depth (metres) of that ray's intersection with the upright card through `SpriteProjection.card_plane_point()` (the ground point under the rounded bottom edge; amended 2026-10-31 by story 039, ADR-0005 §2), within 1e-4 of the analytic value.
  - **[C]** (P-09; Pending: capture tool): on an Overworld capture of the fixture, every ID-pass pixel of the sprite's upper half is present in front of the wall, and every ID-pass pixel of its bottom `2` texels behind a fixture prop placed in front of its feet is absent.

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines:*

The `[L]` half tests `SpriteProjection`'s pure card-depth function directly: for a battery of view rays through the sprite's pixel rectangle under a pitched camera, it must return the analytic ray–upright-card intersection depth within 1e-4 m, with the sprite standing 0.5 m in front of a fixture wall.
- The analytic value is the closed-form ray–plane intersection against the upright card (the vertical plane through the ground point under the sprite's rounded bottom edge, `card_plane_point()`, whose normal is the camera's forward direction projected onto the ground, §2) — the test computes this independently of the production function to avoid asserting a function against itself.
- The `[C]` half captures the same fixture in the Overworld (and separately in Camp) and reads the ID pass: the sprite's upper half must be present in front of the wall (correctly occluding it), while its bottom two texels — behind a fixture prop placed in front of its feet — must be absent (correctly occluded by the prop). Both directions of occlusion are checked in one capture.
- This story covers the pitched-camera case specifically; the level battle camera's equivalent guarantee is implicit in story 063's pixel-snap test and the ADR's own item 10 verification, not re-tested here.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-063-pixel-snap-in-every-mode.md`: the screen-space pixel-snapping of the same quad, under both level and pitched cameras
- `story-052-no-emissive-behind-actor.md`: a different, light-source-specific occlusion failure mode

---

## Files

- `src/presentation/sprite_projection.gd`
- `tests/unit/presentation/card_depth_test.gd`
- `tests/unit/presentation/card_occlusion_check_test.gd`
- `tools/capture/card_occlusion_check.gd`, `tools/capture/card_occlusion_capture.gd`
- `production/qa/evidence/upright-card-occlusion/`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- `tests/unit/presentation/card_depth_test.gd` — must exist and pass (the `[L]` half)
- A retained capture-tool output in `production/qa/evidence/upright-card-occlusion/` + sign-off in `production/qa/evidence/upright-card-occlusion-evidence.md` (the `[C]` half)

**Status**: [x] Created 2026-10-31: `tests/unit/presentation/card_depth_test.gd` (3 cases) + `card_occlusion_check_test.gd` (6 cases) pass; capture `tools/capture/card_occlusion_capture.gd` (check `tools/capture/card_occlusion_check.gd`) exit 0, PASS; evidence `production/qa/evidence/upright-card-occlusion/` + `upright-card-occlusion-evidence.md` (sign-off pending)

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-001-windowed-engine-spike.md` (the spike verifies pixel-exact card depth under the pitched Overworld camera); `production/epics/sprite-camera-presentation/story-002-capture-tool.md` (the capture tool, for the `[C]` half)
- Unlocks: None
