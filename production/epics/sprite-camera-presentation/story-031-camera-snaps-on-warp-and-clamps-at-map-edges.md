# Story 031: the follow camera snaps on a warp and stays clamped inside the map

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: The Overworld's `FollowCamera` is a perspective camera at fixed yaw and pitch, moving position only, with `keep_aspect = KEEP_HEIGHT` and `fov` widened below 16:9 by the same `F_v_eff` rule as the battle camera; the GDD's `follow_camera` formula, including its ground-footprint clamp, is implemented exactly.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: ADR-0005's §6 camera decisions are probed for the battle camera's `PROJECTION_FRUSTUM` path; the Overworld's perspective follow-camera path is explicitly flagged "Step 1 probes the perspective path at 16:10 and 4:3" — this story's clamp math can be written and unit-tested headlessly now, but its on-screen correctness at non-16:9 aspects is not yet engine-verified.

**Control Manifest Rules (this layer)**:
- Required: "**Overworld:** a perspective follow camera (`FollowCamera`) at a fixed yaw and pitch, moving position only, with `keep_aspect = KEEP_HEIGHT` and its `fov` widened below 16:9 by the same `F_v_eff` rule" (Cameras, ADR-0005 §6).
- Required: "The camera's position, rotation and `near` never change in a fight; `size` changes only on a window resize" (Cameras, ADR-0005 §6) — the battle-camera rule; this story's snap is the Overworld analogue (position changes only on the hidden swap, never a smoothed frame).
- Forbidden: "Never add a second `Camera3D` or `WorldEnvironment` to a mode scene that already has a `DioramaStage`" (ADR-0005).

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-27 [L]** (P-07) GIVEN a warp, map change or retreat, THEN the camera snaps during the hidden swap phase (zero smoothing frames). At a map edge, the ground hits of the view's four corner rays lie inside the map's bounds. GIVEN a map narrower than the footprint on one axis, THEN the camera's position on that axis equals the centre of its clamp bounds on every frame.

---

## Implementation Notes

*Derived from ADR-0005 Decision §6 (Cameras — Overworld):*

- The follow camera moves position only (never rotation, pitch or `fov`, except the fixed `F_v_eff` widening below 16:9) — a snap is therefore a direct position assignment with the smoothing `tau` bypassed for exactly one frame, not a very-fast tween.
- The hidden swap phase is Game State's SWAP (ADR-0002) — the snap must happen before the mode is revealed, so the player never sees a smoothing interpolation toward the new position.
- The ground-footprint clamp projects the view's four corner rays onto the ground plane and clamps the camera's position so all four hits stay inside the map's bounds; on an axis narrower than the resulting footprint, the clamp collapses to a single point — the map's centre on that axis — and the camera position equals it on every frame (never oscillating or picking an edge).
- This is the Overworld ADR's eventual territory for "what it follows" (ADR-0005 §6: "The Overworld ADR decides what it follows") — this story implements the camera-side formula only, against a fixture anchor position; it does not implement party-anchor following itself.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-044-dialogue-holds-the-follow-camera.md`: the Dialogue-open camera-hold behaviour.
- `story-050-camera-holds-every-slot-in-view-at-every-aspect.md`: the battle camera's aspect handling (a separate `Camera3D` on `PROJECTION_FRUSTUM`, not the Overworld's perspective follow camera).
- Party-anchor tracking itself and the Overworld's dead zone / `tau` smoothing parameters (the Overworld epic, ADR-0012, no epic yet).

---

## Files

- `src/presentation/sprite_projection.gd`
- `tests/unit/presentation/follow_camera_clamp_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/follow_camera_clamp_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-001-windowed-engine-spike.md` (the spike probes the perspective follow-camera path at 16:10 and 4:3); the Overworld (ADR-0012, no epic yet — owns what the camera follows and the map bounds data)
- Unlocks: `story-044-dialogue-holds-the-follow-camera.md`
