# Story 038: every faction's boss takeover is lavish on its own terms, with no faction left behind

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-005`, `TR-presentation-024`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: A `boss_<faction>` profile carries the faction's dusk flood swatch on the `SkyCard`; `set_key_fill_ratio_boss`, `blend_boss`, `boss_hold`, `boss_retry_hold` and `flood_chroma_frac` are the same across every faction's preset, and actors take no ambient, fill or set light so the flood cannot tint the squad.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Depends on the capture tool's ID pass (sky tagging), the set-light shadow mask (Verification item — "the hardest set contrast" clause is itself marked Pending in the GDD pending the shadow mask), and the glow-input hook (cross-check against AC-32). Several of this AC's `[C]` clauses are explicitly `(Pending: capture tool)` until `story-002-capture-tool.md` is Done.

**Control Manifest Rules (this layer)**:
- Required: "`SetLight`: a `DirectionalLight3D`, culled to `SET`, the **only** shadow caster in the scene" (Stages and lighting, ADR-0005 §3–§5) — relevant to the "hardest set contrast" clause's shadow-mask measurement.
- Required: "`SkyCard`... draws the GDD's stars: single-texel points (`T × T` px, snapped like sprites), placed above the horizon band, tagged `star` in the ID pass, twinkling on `mode_time`" (Stages and lighting, ADR-0005 §3–§5).
- Forbidden: "Never pitch the battle camera down to frame the ground while keeping the `Environment` sky — leans sprites back, and the sky doesn't follow `frustum_offset`" (ADR-0005) — the reason a `SkyCard`, not the `Environment` sky, is what this story's sky-pixel checks measure.

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-34 [C]+[VF]** (P-09, P-11, P-17) (Pending: capture tool) One boss takeover per faction, captured on the last frame of the hold. Parity is **lavishness, not lightness or chroma**: each faction's dusk swatch sits in its own place, and Terminal Cyan's gamut-capped chroma is expected. **[L] the same structure for every faction:** in every `boss_<faction>` preset, `blend_boss`, `boss_hold`, `boss_retry_hold`, `set_key_fill_ratio_boss` and `flood_chroma_frac` have the same values; the set light's direction equals the stage's Battle preset's; the set and fill light hues are within `flood_hue_tol` of the faction's signature hue; the actor key and rim equal the Battle preset's; every swatch's L* range is at or below `flood_l_max`, and its chroma equals `min(flood_chroma_frac × C*_signature, C*_max)`. **[C] the flooded sky:** on the ID pass's sky pixels, shrunk by 2 px at the sky's edges: at least `sky_match_min` match the flood's hue and chroma; above the horizon band, no non-star sky pixel is lighter than the swatch's upper L* bound (inside the band, plus `flood_l_gradient`; nowhere darker than the lower bound minus `flood_l_gradient`); the mean L* of non-star sky pixels is at most `flood_l_max`; the sky's L* standard deviation is at least 2. **[C] stars:** at least `star_count_min` stars visible above the horizon band, covering at most `star_share_max`, each exactly one texel. **[C] the sky is seen and is not the stage's own:** `sky_share ≥ sky_share_min`, and the swatch at `L*_mid` is at least `flood_native_de_min` from the stage's native sky. **[C] enemy against flood:** every enemy's costume band is at least `enemy_flood_de_min` from its ring. **[C] hardest set contrast** (Pending: the set-light shadow mask): lit-set/shadowed-set luminance ratio is higher than that stage's Battle capture. **[C] cross-checks:** the faction shape is in view (AC-37); the squad is untinted (AC-67); the HUD is untinted (AC-53). **[VF] side-by-side review:** the art director reviews all faction takeovers together — no faction's takeover is less lavish, uglier or villain-coded than another's, the horizon glow reads, and the blob shadows match the specified look.

---

## Implementation Notes

*Derived from ADR-0005 Decision §3 (`SkyCard`), §5 (`LightingProfile` sky fields) and the "Pending" note in the GDD itself:*

- **Structural parity first.** The `[L]` clause is a pure data check across every `boss_<faction>` profile — it can and should be written as a headless unit test independent of the capture tool, asserting `blend_boss`, `boss_hold`, `boss_retry_hold`, `set_key_fill_ratio_boss` and `flood_chroma_frac` are byte-identical across factions, and that key/rim equal the Battle preset's.
- **Capture-measured clauses** all go through `tools/capture/presentation_capture.gd`'s ID pass (for sky and star pixel classification) and set-light shadow mask (for the hardest-set-contrast clause). The GDD itself marks the swatch values and the shadow-mask clause as **Pending** until Step 1 (Open Question 7) and the capture tool's shadow-mask pass exist respectively — this story's automated suite must mark those sub-checks Pending rather than fail when their prerequisite is missing, exactly as the GDD specifies.
- **Parity is lavishness, not lightness or chroma** — the `[VF]` side-by-side review is the actual arbiter of "no faction looks worse than another"; the `[L]`/`[C]` clauses only guarantee the *mechanism* treats every faction identically (same knobs, same formula), not that the result reads as equally lavish, which is a judgement call. Terminal Cyan's gamut-capped chroma is explicitly expected to differ and is not a failure.
- **Cross-checks against AC-37, AC-67 and AC-53** are assertions this story's test re-runs against the same captures, not re-implementations — if those stories (41, outside this writer's range for 67/53) are not yet Done, this story's cross-check sub-clauses stay Pending too, named explicitly in this story's evidence rather than silently skipped.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-036-capture-one-screen-per-lighting-state.md`: the general per-state capture and read-order/glow checks (this story is boss-takeover-specific and far more detailed).
- `story-041-boss-stage-frames-a-colorblind-shape.md`: AC-37's own faction-shape-in-view check (only cross-checked here, not re-implemented).
- `story-049-boss-takeover-runs-on-one-clock.md`: the takeover's timing (this story only needs the *last frame of the hold*, a fixed point in that timeline).

---

## Files

- `tools/capture/presentation_capture.gd` (consumed, not authored)
- `src/presentation/diorama_stage.gd`
- `src/presentation/lighting_profile.gd`
- `tests/unit/presentation/boss_takeover_parity_structural_test.gd`
- `tests/integration/presentation/boss_takeover_parity_capture_test.gd`
- `production/qa/evidence/story-038-boss-takeover-faction-parity/`
- `production/qa/evidence/story-038-boss-takeover-faction-parity-evidence.md`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: a retained screenshot in `production/qa/evidence/` + sign-off in `production/qa/evidence/story-038-boss-takeover-faction-parity-evidence.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-002-capture-tool.md` (the capture tool); `story-001-windowed-engine-spike.md` (settles the swatch values, Open Question 7, Step 1); every `boss_<faction>` profile authored (MVP: `boss_bureaucratia`, `boss_megacorp`); boss stages (content, not yet authored)
- Unlocks: None
