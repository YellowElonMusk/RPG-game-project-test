# Story 004: SpriteProjection returns an exact, pixel-snapped quad at the foot anchor for any camera and frame size

> **Epic**: Sprite & Camera Presentation
> **Status**: Complete (2026-10-29)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: `SpriteProjection` is a pure, static, headless-testable function computing `T = max(1, floor(viewport_height / texel_base_lines))` and a whole-pixel quad rectangle bottom-centred on the rounded foot-anchor projection; `CharacterSprite`'s shader inputs must equal its output on every frame.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: The clip-space quad is pixel-exact with `frustum_offset` non-zero, with upright-card depth, level and pitched — VERIFIED 2026-10-22 (item 10). Story 001's spike sets `humanoid_height_px` and settles item (13), manual `AnimatedSprite3D` frame stepping, which this story's `CharacterSprite` integration relies on.

**Control Manifest Rules (this layer)**:
- Required: On-screen size comes only from `T = max(1, floor(viewport_height / texel_base_lines))`. No `pixels_per_unit` render parameter — source: ADR-0005
- Required: `SpriteProjection` is a pure, static, headless-testable function; `vertex()` writes `POSITION` directly for a clip-space quad on the upright card — source: ADR-0005
- Forbidden: Never size a sprite by a world-space `pixel_size` on a Y-locked billboard (superseded revision 1) — source: ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- **AC-2 [L]** (P-03) For any foot anchor, camera and frame size, the sprite projection returns:
  - a quad of exactly `frame_w × T` by `frame_h × T` pixels, with its bottom-centre at the projected foot anchor rounded half away from zero;
  - with `T` equal to 2, 3, 4, 6 and 2 at heights of 720, 1080, 1440, 2160 and 900.

  Every `CharacterSprite`'s shader inputs equal that function's output on every frame, in Battle and the Overworld, including at the near and far ends of a stage and at the frame's corners. Every sprite set:
  - is filtered nearest;
  - has node scale (1, 1, 1) and rotation 0 before, during and after a hit-punch and a replay;
  - has a humanoid frame height of `humanoid_height_px`, with large-alien heights integer multiples of it.

---

## Implementation Notes

*Derived from ADR-0005 Decision §1–§2 and Key Interfaces:*

- `SpriteProjection` (`src/presentation/sprite_projection.gd`, static, headless-testable) computes `T`, the whole-pixel rectangle (`x_left = x_a − floor(frame_w·T / 2)` so an odd pixel width never starts on a half pixel), and the upright-card normal (camera forward projected onto the ground).
- `viewport_height` is `get_viewport().size.y` (full window pixels under ADR-0008's refit); `T` is unaffected by the refit remainder while `f ≤ 6`.
- `CharacterSprite` passes the rectangle, viewport size, anchor and card normal as shader uniforms in the same call that changes `animation` or `frame`; this story's test compares those uniforms against `SpriteProjection`'s direct output.
- `vertex()` writes `POSITION`, `VERTEX` and `NORMAL` directly; the corner comes from `VERTEX_ID`, never `UV` (a `SpriteFrames` built from an `AtlasTexture` hands atlas-region UVs).
- Node `scale` stays `(1, 1, 1)` and the node is never rotated, before, during or after a hit-punch and a replay.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005 (`production/epics/sprite-camera-presentation/story-005-no-mirror-animations-use-authored-art.md`): mirroring and `no_mirror` fallback
- Story 006 (`production/epics/sprite-camera-presentation/story-006-battle-camera-lens-shift-only.md`): the battle camera's own `frustum_offset` behaviour

---

## Files

- `src/presentation/sprite_projection.gd`
- `src/presentation/character_sprite.gd`
- `tests/unit/presentation/sprite_projection_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/sprite_projection_test.gd` — must exist and pass

**Status**: [x] Created and passing — `tests/unit/presentation/sprite_projection_test.gd`, 18 cases, part of the 614/614 full-suite green run (2026-10-29)

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-001-windowed-engine-spike.md`
- Unlocks: `production/epics/sprite-camera-presentation/story-005-no-mirror-animations-use-authored-art.md`, `production/epics/sprite-camera-presentation/story-006-battle-camera-lens-shift-only.md`, `production/epics/sprite-camera-presentation/story-022-battle-framing-keeps-every-slot-in-view.md`

---

## Completion Notes

*Implemented 2026-10-29.*

- `src/presentation/sprite_projection.gd`: static `texel_scale`, `screen_rect`, `card_normal`, `card_depth`, plus a nested `CameraState` value class (`from_frustum`, `from_perspective`, `from_camera3d` factories) exactly matching the Key Interfaces block. `screen_rect` implements the GDD `texel_scale` formula verbatim, including round-half-away-from-zero (written out explicitly, not via the engine's `round()`) and the odd-width `x_left` rule.
- **Engine trap found and fixed**: `Projection` has no `.xform()` method on 4.7.2 (parser error: "Function 'xform()' not found in base Projection") — the engine-reference docs are silent on this class. Replaced both call sites with `projection * Vector4(x, y, z, 1.0)` (confirmed working via a probe script) followed by a manual `/w` perspective divide. Worth adding to `deprecated-apis.md` or a Projection note for the next agent who reaches for `.xform()`.
- `src/presentation/presentation_config.gd`: a minimal stub (`texel_base_lines`, `humanoid_height_px`) per the task's allowance — ADR-0005 §5's full `PresentationConfig` (profile table, sprite-set table, every Tuning Knob, load validation) is explicitly a later story's scope.
- `src/presentation/character_sprite.gd`: `setup()`, `show_frame()`, `step_ambient()`, `reset_to_idle()` per Key Interfaces; calls `SpriteProjection` each update and writes `sprite_rect`/`viewport_size`/`foot_anchor`/`card_normal`/`flip_h` via `set_shader_parameter()` on its own `ShaderMaterial` instance. `no_mirror` animation substitution is left to Story 005 (out of scope here); authoring `sprite_actor.gdshader` itself is `godot-shader-specialist`'s domain and not created by this story — `_update_shader_uniforms()` no-ops safely without one.
- `tests/unit/presentation/sprite_projection_test.gd`: 18 cases — `texel_scale` at all five GDD reference heights (parametrized) plus the floor and minimum-1 edge cases; `screen_rect` dimension formula, the round-half-away-from-zero bottom-centre anchor (via an odd viewport forcing an exact .5 pixel), and the GDD's own 33-texel/1080p worked example; `card_normal` level/pitch-invariant/yaw-following; one `card_depth` on-axis sanity check (full AC-68 coverage deferred, out of this story's scope).
- Full suite: 614/614 green (596 baseline + 18 new), `--headless --import` clean.
- Status synced 2026-10-30 from commit e81e268.
