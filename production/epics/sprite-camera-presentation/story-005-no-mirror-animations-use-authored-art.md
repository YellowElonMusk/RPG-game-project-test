# Story 005: no_mirror animations use authored opposite-facing art instead of the shader flip

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-020`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: Mirroring is a shader flip uniform, never `flip_h` (the override ignores it); a `no_mirror` animation instead uses an authored `<animation_id>_<facing>_mirrored` animation.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Flip-based mirroring done in the shader is Verification Required item (14), still to verify in Step 1 (story 001). This story's logic test assumes that item is closed.

**Control Manifest Rules (this layer)**:
- Required: Mirroring is a shader flip uniform, never `flip_h` (the override ignores it). A `no_mirror` animation uses an authored `_mirrored` variant instead — source: ADR-0005
- Forbidden: Never use `flip_h` to mirror a `CharacterSprite` — source: ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- **AC-3 [L]** (P-06) GIVEN an animation flagged `no_mirror`, WHEN its sprite is placed on the mirrored side, THEN its authored opposite-direction art is used and it is not mirrored, while the same set's unflagged animations are mirrored. GIVEN an unflagged set, THEN mirroring follows formation side (Battle) or movement direction (Overworld).

---

## Implementation Notes

*Derived from ADR-0005 Decision §1:*

- Facings are `front` and `back`, and `SpriteFrames` animations are named `<animation_id>_<facing>`.
- Mirroring is a shader flip uniform applied to `UV` in `fragment()`, never `flip_h`, which the `material_override` ignores.
- A `no_mirror` animation instead has an authored `<animation_id>_<facing>_mirrored` animation, used in place of the flip — `show_frame()` picks it for `no_mirror` animations.
- Which side mirrors follows formation side in Battle and movement direction in the Overworld; an unflagged set always mirrors by that rule.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 018 (`production/epics/sprite-camera-presentation/story-018-boot-validation-of-sprite-set-animations.md`): the debug-path fallback when a `no_mirror` animation has no same-facing art

---

## Files

- `src/presentation/character_sprite.gd`
- `tests/unit/presentation/character_sprite_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/character_sprite_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-001-windowed-engine-spike.md`, `production/epics/sprite-camera-presentation/story-004-sprite-projection-pixel-exact-quad.md`
- Unlocks: `production/epics/sprite-camera-presentation/story-011-dialogue-and-defeat-prompt-keep-animation-running.md`
