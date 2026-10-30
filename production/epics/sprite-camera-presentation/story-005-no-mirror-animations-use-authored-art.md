# Story 005: no_mirror animations use authored opposite-facing art instead of the shader flip

> **Epic**: Sprite & Camera Presentation
> **Status**: Complete (2026-10-29)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

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

**Status**: [x] Created and passing — `tests/unit/presentation/character_sprite_test.gd`

---

## Completion Notes

- `show_frame()` gained a `no_mirror: bool` parameter (ADR-0005 §1): when
  `mirrored and no_mirror`, it plays `<animation_id>_<facing>_mirrored`
  and keeps the shader's `flip_h` uniform false; otherwise it plays
  `<animation_id>_<facing>` and flips when `mirrored`. An unflagged
  animation in the same set still flips, per AC-3.
- Also wired `frame_tex`: `_update_shader_uniforms()` now fetches the
  current frame's `Texture2D` once (`_current_frame_texture()`, replacing
  `_current_frame_size()`) and sets it as the shader's `frame_tex`
  uniform every call, per ADR-0005 §1 ("it sets the frame texture uniform
  in the same call"). This was a gap in the Story 004 code, not previously
  wired; it is necessary glue for the shader this story also builds, and
  `character_sprite.gd` was already this story's only in-scope file.
- **`src/presentation/shaders/sprite_actor.gdshader` was built under this
  story** (ADR-0005 §2), because no other story owns that file: the
  pixel-exact upright-card vertex quad (ray-cast through
  `INV_PROJECTION_MATRIX`, plane-intersected, re-projected), `FRAGCOORD`-based
  fragment UV (pitched-camera-safe), hard alpha cutout, key-light-only
  lighting (`ambient_light_disabled`), the one-texel rim ring excluding
  Outline Ink, and shader-flip mirroring.
- The vertex shader's pixel→NDC conversion follows ADR-0005 §2's probed
  note that this shader stage's NDC is y-down (no flip relative to window
  pixels).
- **Visual check: correction by the main session (2026-10-29).** The
  implementer's capture was a solid grey frame with no sprite, and the
  notes above wrongly said it showed the card. The main session found two
  causes and fixed them:
  1. **Missing shader globals.** The shader reads `actor_rim_color` and
     `actor_rim_strength`, which ADR-0005 places in `project.godot`'s
     `shader_globals`, but the project declared none. Godot warned
     "Material will not display correctly". `[shader_globals]` now declares
     `mode_time`, `actor_rim_color` and `actor_rim_strength`, with
     placeholder values; `PresentationDirector` writes the real ones later.
  2. **Crash before the tree.** `CharacterSprite._update_shader_uniforms()`
     called `get_viewport()` before the node was in the tree, which crashed.
     Mode scenes are set up before `add_child`, so it now returns early
     until it is inside the tree.

  The capture `01-sprite-under-pitched-camera.png` was retaken by the main
  session: a placeholder 32×48 sprite in a lit scene under a camera
  pitched -35°. It shows an upright, screen-facing, crisp card with its
  transparent margins cut away. In the spike's plain-card capture the same
  setup went edge-on.

  Not yet shown: the rim ring, an actual mirrored frame on screen, and the
  scene under a real `DioramaStage` light rig (the scratch scene used one
  directional light).
- Deviation to flag: the rim test is the in-shader per-pixel neighbor
  sampling ADR-0005 §2 describes as Step 1's placeholder ("may replace
  the in-shader test with a mask baked at import" if it costs too much) —
  left as a `TODO(godot-shader-specialist)` in the shader rather than
  implemented now, since baking is a separate, later decision.

---

- Status synced 2026-10-30 from commit 95c4606.

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-001-windowed-engine-spike.md`, `production/epics/sprite-camera-presentation/story-004-sprite-projection-pixel-exact-quad.md`
- Unlocks: `production/epics/sprite-camera-presentation/story-011-dialogue-and-defeat-prompt-keep-animation-running.md`
