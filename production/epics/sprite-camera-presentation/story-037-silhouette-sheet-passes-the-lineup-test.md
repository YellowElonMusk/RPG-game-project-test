# Story 037: every character's silhouette passes the 2-of-3 lineup test

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-020`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: Facings are `front` and `back`, with `SpriteFrames` animations named `<animation_id>_<facing>`; mirroring is a shader flip uniform, never `flip_h`, and a `no_mirror` animation instead has an authored `<animation_id>_<facing>_mirrored` animation.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Flip-based mirroring in the shader is Verification Required item (14) — "**Still to verify in Step 1**." This story's silhouette sheet must be generated from whichever mirroring path Step 1 confirms (shader flip uniform, or the §2 fallback screen-aligned billboard) — it is a visual sign-off against shipped art, not a probe of the mirroring mechanism itself.

**Control Manifest Rules (this layer)**:
- Required: "Mirroring is a shader flip uniform, never `flip_h` (the override ignores it). A `no_mirror` animation uses an authored `_mirrored` variant instead" (Sprites, ADR-0005 §1–§2).
- Required: "Two facings with mirroring; per-animation `no_mirror`; fallbacks keep `no_mirror`" (TR-presentation-020, ADR-0005 §1, §9).
- Forbidden: "Never size a sprite by a world-space `pixel_size` on a Y-locked billboard (superseded revision 1: mixed pixel scale, the art bible's #1 failure)" (ADR-0005) — relevant because a silhouette sheet rendered off the wrong projection path would reintroduce exactly this failure mode.

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-33 [VF]** (P-17) A black-fill silhouette sheet at battle height and at 32 px, with every squad member in its `back` facing (idle and `victory`) and every enemy in its `front` facing. Each character passes the 2-of-3 lineup test.

---

## Implementation Notes

*Derived from ADR-0005 Decision §1 (Facings) and the art bible's readability rule (carried by TR-presentation-020):*

- The sheet is generated at two sizes: battle height (the shipped on-screen `T`-scaled size) and a fixed 32 px reference — both rendered black-fill (silhouette only, no interior detail), which is what the 2-of-3 lineup test judges: a character must be identifiable by outline alone from at least 2 of 3 reference angles/poses.
- Squad members are captured in `back` facing for both `idle` and `victory` (the facing the player sees for most of a battle, since the squad stands with its back to camera); enemies are captured in `front` facing (facing the squad). This matches the two-facings-with-mirroring rule: the sheet does not need the mirrored variant, only the authored facing actually used in that role.
- A `no_mirror` animation (if any squad member or enemy has one) uses its authored `<animation_id>_<facing>_mirrored` variant where the opposite facing would otherwise be needed — this sheet generation must not silently fall back to the shader flip for a `no_mirror` animation.
- This is a `[VF]`-only AC (not `[C]`) — it is generated and judged by the art director directly from the shipped `SpriteFrames` resources, not through the capture tool's automated measurement pipeline, so it carries no dependency on `story-002-*`.
- The sheet itself (one image per character, or one sheet covering the whole roster) is the retained evidence; the art director's lineup-test verdict per character is the sign-off this story's evidence file records.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-039-texel-scale-holds-across-resolutions.md`: the whole-pixel-block texel checks (a different, [C]-measured concern).
- The mirroring mechanism's own engine verification (Step 1, Verification Required item 14) — this story consumes whichever path Step 1 confirms, it does not re-verify it.
- Authoring the `back`/`front` animations themselves (art production, not engineering).

---

## Files

- `src/presentation/character_sprite.gd`
- `production/qa/evidence/story-037-silhouette-sheet-passes-the-lineup-test/`
- `production/qa/evidence/story-037-silhouette-sheet-passes-the-lineup-test-evidence.md`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: a retained screenshot in `production/qa/evidence/` + sign-off in `production/qa/evidence/story-037-silhouette-sheet-passes-the-lineup-test-evidence.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-001-*` (settles which mirroring path ships, shader flip or the fallback billboard); every squad member and enemy sprite set authored with `back`/`front` facings
- Unlocks: None
