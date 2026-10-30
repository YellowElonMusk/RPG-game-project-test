# Story 007: Camp and Title cameras never move

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
**ADR Decision Summary**: Camp and Title use a fixed `Camera3D` (Camp may be pitched); neither its transform nor its lens shift changes when a hit resolves or the party moves.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff API beyond the already-verified `Camera3D` basics is needed for a fixed camera; this story reuses story 006's `DioramaStage` camera plumbing without the battle-only punch path.

**Control Manifest Rules (this layer)**:
- Required: Camp and Title: a fixed `Camera3D`. Camp may be pitched — source: ADR-0005
- Forbidden: Never add a second `Camera3D` or `WorldEnvironment` to a mode scene that already has a `DioramaStage` — source: ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- **AC-5 [L]** (P-07) GIVEN Camp or Title, WHEN a hit resolves or the party moves, THEN the camera transform and lens shift are unchanged.

---

## Implementation Notes

*Derived from ADR-0005 Decision §6:*

- Camp and Title each author one fixed `Camera3D`; Camp may be pitched, unlike the level battle camera.
- Neither scene applies the punch path (§6's `frustum_offset` punch contribution is battle-only); no hit-punch or party-move signal may touch these cameras' transform or lens shift.
- Every 3D mode scene contains exactly one `DioramaStage`, which owns the camera — never a second `Camera3D` or `WorldEnvironment`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006 (`production/epics/sprite-camera-presentation/story-006-battle-camera-lens-shift-only.md`): the battle camera's lens-shift and punch behaviour

---

## Files

- `src/presentation/diorama_stage.gd`
- `tests/unit/presentation/fixed_camera_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/fixed_camera_test.gd` — must exist and pass

**Status**: [x] Created and passing -- `tests/unit/presentation/fixed_camera_test.gd` (presentation suite 99/99, 2026-10-30)

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-001-windowed-engine-spike.md`, `production/epics/sprite-camera-presentation/story-006-battle-camera-lens-shift-only.md`
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-30 (tag scp3)

A DioramaStage without configure_battle_camera() keeps a fixed camera: apply_hit_punch() and on_viewport_resized() are no-ops, so neither a hit nor a party move touches its transform or lens shift. Tested pitched (Camp) and level (Title) over 60 frames of party movement with punches.

**Files**: src/presentation/diorama_stage.gd, tests/unit/presentation/fixed_camera_test.gd
