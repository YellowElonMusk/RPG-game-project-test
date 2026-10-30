# Story 014: A hit-punch never changes an actor's world position

> **Epic**: Sprite & Camera Presentation
> **Status**: Complete (2026-10-30)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: The hit-punch is a camera-only `frustum_offset` shift; a `CharacterSprite`'s own `scale` stays `(1, 1, 1)` and it is never rotated or repositioned, so every actor's world position in metres is unchanged on every frame of a punch.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff API; this is the direct corollary of forbidding a translation shake (§6) and of the sprite node's fixed `scale`/rotation (§1).

**Control Manifest Rules (this layer)**:
- Required: Every character, enemy and comedy-VFX sprite's `scale` stays `(1, 1, 1)`, and it is never rotated — source: ADR-0005
- Forbidden: Never set the battle camera's `h_offset`/`v_offset`, and never use a translation or rotation shake — a translation moves near and far depths by different amounts; the punch is `frustum_offset` only — source: ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- **AC-12 [L]** (P-04) GIVEN a punch, THEN every actor's world position (in metres) is unchanged on every frame.

---

## Implementation Notes

*Derived from ADR-0005 Decision §1 and §6:*

- The punch is implemented entirely as a camera `frustum_offset` addition (story 006, story 012); no code path may move, scale or rotate a `CharacterSprite` node to produce it.
- A translation shake was explicitly rejected (Alternative, §6): it moves near and far depths by different amounts, which would make this AC fail by construction — the architecture already forbids the approach this test guards against.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 012 (`production/epics/sprite-camera-presentation/story-012-one-hit-punch-per-beat-on-impact.md`): when a punch is triggered

---

## Files

- `src/presentation/hit_punch.gd`
- `src/presentation/diorama_stage.gd`
- `tests/unit/presentation/hit_punch_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/hit_punch_test.gd` — must exist and pass

**Status**: [x] `tests/unit/presentation/hit_punch_test.gd` created and passing (2026-10-30)

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-012-one-hit-punch-per-beat-on-impact.md`
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-30. No code path touches a sprite: the punch is `frustum_offset` only. `test_punch_never_moves_an_actor_world_position` drives three punches (normal and knockout, three directions) through `DioramaStage.set_punch_offset_px` with three `CharacterSprite`s at different depths, asserting every frame that each sprite's global transform is unchanged, scale is ONE and rotation zero, the camera transform is unchanged and `h_offset`/`v_offset` stay 0, and that the view did move (non-vacuous). `character_sprite.gd` needed no change.
