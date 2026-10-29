# Story 055: A window resize recomputes the punch and the camera headlessly

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-007`, `TR-presentation-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: §2's `SpriteProjection.T` and §6's battle camera `size`/follow-camera footprint and dead zone are all recomputed from the viewport size on `size_changed`; §6's punch maps screen pixels to `frustum_offset` using the current window height, so a resize must recompute both without resetting the punch's own elapsed clock.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: The texel height must be read as `get_viewport().size.y` (full window pixels under ADR-0008's refit), never `get_visible_rect()` (logical units); any `size_changed` listener must be idempotent, since it fires twice per refit (ADR-0005 §1, ADR-0008 §9, control manifest). The test drives resize through an injected viewport size so it runs headless, per the AC itself.

**Control Manifest Rules (this layer)**:
- Required: Read the texel height as `get_viewport().size.y`, never `get_visible_rect()`; every `size_changed` listener must be idempotent (ADR-0005 §1, ADR-0008 §9)
- Required: Battle camera `size` changes only on a window resize; position, rotation and `near` never change in a fight (ADR-0005 §6)
- Guardrail: The punch's offset stays in whole pixels after a resize, with its elapsed `t` unchanged

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-51 [L]** (P-03, P-07) (resize) The resize is driven through an injected viewport size, so the test runs headless.
  - GIVEN a punch running at 1920×1080, WHEN the window is resized to 2560×1440, THEN on the next frame `T` is 4 and `A_peak` is recomputed from the new height, with the punch's elapsed `t` unchanged and the offset in whole pixels.
  - GIVEN the Overworld, WHEN the window is resized from 16:9 to 21:9 and then to 4:3, THEN the footprint and dead zone are recomputed from the new fields of view each time.

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines:*

Both halves of this AC reuse existing pure functions driven by an injected viewport size rather than a live `size_changed` signal, so the test runs headless (§2 `SpriteProjection`, §6 camera/follow-camera formulas).
- `SpriteProjection.T = max(1, floor(viewport_height / texel_base_lines))` is recomputed from the new height; the punch's `A_peak` (screen-pixel amplitude) scales with it, but the punch's own elapsed `t` is untouched — only its spatial scale changes, not its timing (§6 hit-punch).
- The resulting offset is still rounded to whole pixels after the recompute (§2's pixel-snap guarantee carries through a resize).
- The Overworld follow camera's footprint clamp and dead zone are rebuilt from the new field of view at each aspect, including the widened `F_v_eff` below 16:9 (§6), on every resize in sequence (16:9 → 21:9 → 4:3), not only the first.
- Every `size_changed`-driven recompute must be idempotent, since the refit fires the signal twice per resize (ADR-0008 §9) — the test should call the recompute twice at one new size and assert identical output.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-054-follow-camera-holds-under-the-menu.md`: the Menu-freeze behaviour of the same camera
- UI stretch/refit mechanics themselves (ADR-0008 §9) — this story only consumes the resulting viewport size

---

## Files

- `src/presentation/sprite_projection.gd`
- `src/presentation/follow_camera.gd`
- `tests/unit/presentation/resize_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/presentation/resize_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-001-windowed-engine-spike.md` (the spike probes the perspective follow-camera path at 16:10 and 4:3)
- Unlocks: None
