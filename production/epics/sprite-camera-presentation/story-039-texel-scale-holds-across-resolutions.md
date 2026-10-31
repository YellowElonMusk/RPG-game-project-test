# Story 039: every sprite's texels are whole, uniform pixel blocks at every shipped resolution

> **Epic**: Sprite & Camera Presentation
> **Status**: Done (2026-10-31): capture PASS (whole-pixel texels and lit spread at all 5 sizes; Battle and Overworld coverage at 16:9/21:9/4:3; Overworld floor extended per camera footprint; feet-into-floor MSAA cut fixed via the rounded-bottom-edge card plane, ADR-0005 §2 amended), art-director sign-off pending
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-31

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: `SpriteProjection` computes `T = max(1, floor(viewport_height / texel_base_lines))` and a whole-pixel quad rectangle per sprite per frame; the clip-space quad's screen footprint is exactly the pixel rectangle, with depth exact per pixel and no `DEPTH` write — verified pixel-exact on 4.7.2 with `frustum_offset` non-zero, level and pitched.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Verification Required item (10) — the clip-space quad's pixel-exactness under `frustum_offset` — was **Retired 2026-10-22**, probed pixel-exact at both level (battle) and pitched (Overworld) camera cases. The §2 fallback (a per-frame `pixel_size` screen-aligned billboard) stays documented in reserve in case the Step 1 Steam Deck run shows a regression; this story's captures must record which path actually shipped.

**Control Manifest Rules (this layer)**:
- Required: "On-screen size comes only from `T = max(1, floor(viewport_height / texel_base_lines))`. No `pixels_per_unit` render parameter" (Sprites, ADR-0005 §1–§2).
- Required: "Read the texel height as `get_viewport().size.y` (full window pixels under ADR-0008's refit), never `get_visible_rect()` (logical units)" (FlashGate and the capture tool, ADR-0005 §1, ADR-0008 §9).
- Forbidden: "Never size a sprite by a world-space `pixel_size` on a Y-locked billboard (superseded revision 1: mixed pixel scale, the art bible's #1 failure)" (ADR-0005).

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [x] **AC-35 [C]+[VF]** (P-09, P-12, P-17) ([C] PASS 2026-10-31; [VF] art-director sign-off pending) **[C] Coverage:** Battle and Overworld at 16:9 (1920×1080), 21:9 (2560×1080) and 4:3 (1440×1080). Every actor's silhouette lies fully inside the frame, and no pixel of the ID pass is the sentinel clear class. **[C] Whole-pixel texels:** the same Battle scene in the unlit-albedo mode at 1280×720, 1920×1080, 2560×1440 and 3840×2160, plus 1600×900, for every sprite, near and far, including those nearest the frame's corners: every texel covers exactly a `T × T` block of screen pixels on the expected grid; each block is one color, so no texel is blended or split; the near and far rows' blocks are the same size. **[C] Lit spread:** in the normal lit mode, each block's internal ΔE spread is at most 3. **[VF] Sign-off:** the art director confirms the texels look crisp at every size, the sprites don't read as leaning against or cutting into the set, and the constant-size rows read as near and far.

---

## Implementation Notes

*Derived from ADR-0005 Decision §2 (`SpriteProjection`, the clip-space quad) and §13 (the capture tool's unlit-albedo mode):*

- `T` must be recomputed on every `size_changed`, reading `get_viewport().size.y` — **full window pixels**, never `get_visible_rect()`'s logical units (ADR-0008's UI refit changes the window's logical/physical relationship, and this rule exists precisely so the texel grid tracks the real framebuffer, not the UI's 640×360 base).
- The unlit-albedo capture mode (built by `story-002-capture-tool.md`) strips lighting so each texel's color is exactly the source art's palette color, letting this story's test assert "each block is one color" with simple equality rather than a tolerance — the separate "lit spread" clause (ΔE ≤ 3) is checked only in the normal lit mode, as a distinct pass.
- "Near and far rows' blocks are the same size" is the direct, automated proof that on-screen size is independent of world distance (ADR-0005's core guarantee, §2 "Size comes from `T`, not the world") — a regression here (e.g. a stray `pixels_per_unit` or scale applied anywhere) would show up as unequal block sizes between a near-row and far-row sprite at the same resolution.
- Coverage at 21:9 and 4:3 exercises the `KEEP_HEIGHT`-always rule (ADR-0005 §6): the frame widens or narrows, but the texel grid and actor silhouettes must stay fully inside it at every tested aspect, not just 16:9.
- If Step 1 records that the clip-space quad regressed on the Steam Deck and the §2 fallback (per-frame `pixel_size` billboard) shipped instead, this story's captures are taken against whichever path is actually in `src/presentation/`, and the evidence notes which one.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-050-camera-holds-every-slot-in-view-at-every-aspect.md`: the battle camera's own aspect-handling formula (this story consumes it, it does not re-derive it).
- `story-036-capture-one-screen-per-lighting-state.md`: read-order and glow checks (unrelated to texel geometry).
- Building the capture tool's unlit-albedo mode itself (`story-002-capture-tool.md`, writer A).

---

## Files

- `src/presentation/sprite_projection.gd` (`card_plane_point()`, 2026-10-31)
- `src/presentation/shaders/sprite_actor.gdshader` (card plane through the rounded bottom edge)
- `src/presentation/follow_camera.gd` (`map_overflow()`, `MAX_SUPPORTED_ASPECT`)
- `src/overworld/overworld_map.gd`, `src/overworld/overworld_mode.gd` (floor sized to the camera footprint)
- `tests/unit/overworld/overworld_map_floor_coverage_test.gd`, `tests/unit/presentation/sprite_projection_card_plane_test.gd`
- `tools/capture/presentation_capture.gd` (consumed, not authored)
- `tests/integration/presentation/texel_scale_capture_test.gd`
- `production/qa/evidence/story-039-texel-scale-holds-across-resolutions/`
- `production/qa/evidence/story-039-texel-scale-holds-across-resolutions-evidence.md`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: a retained screenshot in `production/qa/evidence/` + sign-off in `production/qa/evidence/story-039-texel-scale-holds-across-resolutions-evidence.md`

**Status**: [x] Created 2026-10-31: `production/qa/evidence/story-039-texel-scale-holds-across-resolutions-evidence.md` (capture: `tools/capture/texel_scale_capture.gd`, check: `tools/capture/texel_grid_check.gd`); sign-off pending. Re-run 2026-10-31 after the Overworld floor + card-plane fixes: PASS (exit 0).

---

## Dependencies

- Depends on: `story-001-windowed-engine-spike.md` (the spike settles whether the clip-space quad or the fallback billboard ships); `story-002-capture-tool.md` (the capture tool's ID pass and unlit-albedo mode)
- Unlocks: None
