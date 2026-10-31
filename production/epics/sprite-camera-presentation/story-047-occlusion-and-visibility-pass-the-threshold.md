# Story 047: every battle stage keeps every actor slot visible above the occlusion threshold

> **Epic**: Sprite & Camera Presentation
> **Status**: Done (2026-10-31): [L] PASS, [VF] captures retained, art-director sign-off pending
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: Occlusion is per-pixel exact via the upright-card depth with no `DEPTH` write, under a level shift-lens battle camera that never moves, rotates, zooms or changes FOV — exact occlusion is a positive consequence of the clip-space-quad design, verified pixel-exact on 4.7.2.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Verification Required item (10) (the clip-space quad's pixel-exactness under `frustum_offset`, level and pitched) was Retired 2026-10-22 — occlusion itself is engine-confirmed. This story measures the *consequence* (visible-share per slot across formations), not the projection mechanism again.

**Control Manifest Rules (this layer)**:
- Required: "**Exact occlusion.** Upright-card occlusion is per-pixel exact with no `DEPTH` write, so early-z stays on" (Consequences, ADR-0005).
- Required: "**No shadows.** Actors have `cast_shadow = OFF`. They get a blob shadow instead" (Sprites, ADR-0005 §1–§2) — relevant because a blob shadow must not itself contribute to occlusion measurement between actors.
- Guardrail: n/a — this is a geometric visibility measurement, not a frame-time or draw-call budget.

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-43 [L]+[VF]** (P-07, P-17) (occlusion and visibility) **[L]** every shipped battle stage, with every slot filled, passes `visible_share ≥ actor_visible_min` for every slot. **[VF]** for each battle stage at its default camera, one capture with every slot filled: no actor is hidden by set geometry or by another actor beyond the limit, and the back row reads, signed off by the art director.

---

## Implementation Notes

*Derived from ADR-0005 Decision §2 (upright-card depth, exact occlusion) and §3 (`DioramaStage`'s set geometry):*

- `visible_share` is the fraction of a slot's silhouette that is not occluded by set geometry or another actor, from the battle camera's fixed viewpoint — the `[L]` half of this AC is a headless computation against each stage's formation data and set geometry bounds (not a rendered screenshot), comparable to `story-042`'s slot-depth check but for visibility fraction rather than depth collision.
- `actor_visible_min` is a `PresentationConfig` knob (data, never a literal in the validator) — the test must read it from the fixture config, not hardcode the threshold, so a future tuning pass does not require touching this test.
- Because occlusion is per-pixel exact with no `DEPTH` write (§2), `visible_share` can be computed analytically from the upright-card geometry and the set's known occluders, without rendering — but the `[VF]` half still requires an actual rendered capture, because "the back row reads" is a human-legibility judgement (contrast, silhouette separation) that a geometric fraction alone cannot certify.
- "Every slot filled" means the formation's worst case for mutual occlusion (every actor present, none missing) — a stage that only passes with fewer actors present must fail this check, since battles are not guaranteed to have empty slots.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-046-no-two-actor-slots-share-a-depth.md`: depth-collision validation itself (a prerequisite for meaningful occlusion, not re-tested here).
- `story-039-texel-scale-holds-across-resolutions.md`: texel-grid correctness (unrelated to visibility share).
- Authoring the set geometry or formation data for any specific stage (content production).

---

## Files

- `src/presentation/diorama_stage.gd`
- `data/presentation/presentation_validators.gd`
- `tests/unit/presentation/visible_share_test.gd`
- `production/qa/evidence/story-047-occlusion-and-visibility-pass-the-threshold/`
- `production/qa/evidence/story-047-occlusion-and-visibility-pass-the-threshold-evidence.md`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: a retained screenshot in `production/qa/evidence/` + sign-off in `production/qa/evidence/story-047-occlusion-and-visibility-pass-the-threshold-evidence.md`

**Status**: [x] `production/qa/evidence/story-047-occlusion-and-visibility-pass-the-threshold/` (battle_default_all_slots.png, battle_boss_all_slots.png) + `production/qa/evidence/story-047-occlusion-and-visibility-pass-the-threshold-evidence.md` (art-director sign-off pending); `tests/unit/presentation/visible_share_test.gd` (9 cases) passes; full suite 1922/1922, exit 0 (2026-10-31)

---

## Dependencies

- Depends on: `story-046-no-two-actor-slots-share-a-depth.md`; `story-002-capture-tool.md` (the capture tool, for the `[VF]` capture); every shipped battle stage's set geometry authored
- Unlocks: None
