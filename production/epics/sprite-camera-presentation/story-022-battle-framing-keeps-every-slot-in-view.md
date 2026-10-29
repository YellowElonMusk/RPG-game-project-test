# Story 022: battle_framing keeps every actor slot in view and the foot row on the formula's curve

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-002`, `TR-presentation-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: The `battle_framing` formula fixes each slot's foot row, visible-share and row-gap occlusion bounds, and aspect/DOF/horizon failure conditions, validated at load against the level shift-lens battle camera.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Depends on the already-verified clip-space quad (item 10) and `frustum_offset` sign (item 11); aspect behaviour below 16:9 depends on the `KEEP_HEIGHT`-always fix (story 006) and is re-measured against this formula's `y_h` in story 001's spike.

**Control Manifest Rules (this layer)**:
- Required: Battle camera: `PROJECTION_FRUSTUM`, pitch 0, `keep_aspect = KEEP_HEIGHT` ALWAYS; `size` recomputes on `size_changed` — source: ADR-0005
- Forbidden: Never pitch the battle camera down to frame the ground while keeping the `Environment` sky — leans sprites back, and the sky doesn't follow `frustum_offset` — source: ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- **AC-19 [L]** (P-07) **battle_framing**. Comparisons use a tolerance of 1e-6.
  - Each slot's foot row equals `y_foot(z)` within 0.5 px.
  - A fixture formation whose most-covered slot has `visible_share` exactly `actor_visible_min` passes; one at 0.01 below fails at load.
  - Two fixture slots directly in line pass exactly when `row_gap ≥ actor_visible_min · q`.
  - A stage also fails with `z_near ≤ 0`, with an actor quad 1 px outside the frame at any of 16:9, 21:9 and 4:3, with background blur starting 0.01 m of view depth before `z_far + dof_margin`, or (a boss stage) with `horizon_frac` 0.01 below `sky_share_min`.
  - The formula example's numbers are reproduced.

---

## Implementation Notes

*Derived from ADR-0005 Decision §3 and §6:*

- `battle_framing` is a load-time validation over a battle stage's authored slot depths, `horizon_frac`, DOF distances and the camera's `size`/`frustum_offset`-derived view bounds — it fails the stage at load, not at runtime, when any bound is violated.
- Occlusion correctness depends on the upright-card projection (§2) being pixel-exact, which is already verified; this story's job is the *framing* formula around that projection, not the projection itself.
- The 16:9/21:9/4:3 aspect cases must all use the same `KEEP_HEIGHT`-always camera sizing from story 006 — never `KEEP_WIDTH`.
- A boss stage's `horizon_frac` must additionally clear `sky_share_min`, tying this formula to the sky card's always-in-frame guarantee (§3).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004 (`production/epics/sprite-camera-presentation/story-004-sprite-projection-pixel-exact-quad.md`): the projection function itself
- Story 006 (`production/epics/sprite-camera-presentation/story-006-battle-camera-lens-shift-only.md`): the camera's own `frustum_offset` mechanics

---

## Files

- `src/presentation/diorama_stage.gd`
- `data/presentation/stages/*`
- `tests/unit/presentation/battle_framing_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/battle_framing_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-001-windowed-engine-spike.md`, `production/epics/sprite-camera-presentation/story-004-sprite-projection-pixel-exact-quad.md`, `production/epics/sprite-camera-presentation/story-006-battle-camera-lens-shift-only.md`
- Unlocks: None
