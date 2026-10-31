# Story 020: Only the set light casts shadows; every actor gets exactly one blob shadow

> **Epic**: Sprite & Camera Presentation
> **Status**: Done (4867af4)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-019`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: `SetLight` is the only shadow caster in a scene; actors have `cast_shadow = OFF` and instead get one blob shadow each, offset from the foot anchor along `SetLight`'s ground-projected direction and colored with the current preset's `shadow_color`.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff API; removes the original spike's rectangle-shadow risk and its actor shadow passes entirely (Consequences, Positive).

**Control Manifest Rules (this layer)**:
- Required: Light rig: `KeyLight` (cull `ACTORS`, no shadows), `SetLight` (cull `SET`, the ONLY shadow caster), `FillLight` (cull `SET`, no shadows) — source: ADR-0005
- Required: Actors have `cast_shadow = OFF` and get a blob shadow instead — source: ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- **AC-17 [L]** (P-06) GIVEN any scene, THEN exactly one light casts shadows (the set light), and every actor sprite casts none. Each actor has exactly one blob shadow, at its foot anchor offset by `shadow_offset` along the set light's ground-projected direction, colored with the current preset's shadow color.

---

## Implementation Notes

*Derived from ADR-0005 Decision §2–§3:*

- `KeyLight` and `FillLight` both have shadows off by construction; only `SetLight` (`DirectionalLight3D`, cull `SET`) casts, and it is the scene's one and only shadow caster.
- Blob shadows are a small unlit decal or mesh on `SET`, one per actor, placed under the foot anchor and offset along `SetLight`'s ground-projected direction by `shadow_offset`, colored with the active profile's `shadow_color`.
- This removes the original spike's rectangle-shadow risk and every actor shadow draw call — there is no fallback path where an actor casts a real shadow.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003 (`production/epics/sprite-camera-presentation/story-003-actor-key-and-rim-lighting-only.md`): which lights illuminate actors (as opposed to which cast shadows)

---

## Files

- `src/presentation/diorama_stage.gd`
- `tests/unit/presentation/blob_shadow_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/blob_shadow_test.gd` — must exist and pass

**Status**: [x] `tests/unit/presentation/blob_shadow_test.gd` -- 5/5 passing; full suite 1753/1753

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-001-windowed-engine-spike.md`, `production/epics/sprite-camera-presentation/story-003-actor-key-and-rim-lighting-only.md`
- Unlocks: None
