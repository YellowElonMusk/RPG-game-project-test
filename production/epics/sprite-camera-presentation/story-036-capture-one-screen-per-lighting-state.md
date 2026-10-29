# Story 036: one capture per lighting state passes read order and shows no glow on actors

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: Actors are lit only by their key, a rim on the texel ring, and tagged practicals — never ambient, fill or set light — enforced by `render_mode ambient_light_disabled` and cull masks; the capture tool's ID pass and glow-input hook measure `read_order` and glow per state at boot-validated thresholds.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: The glow-input hook (reading glow before tonemapping, via a compositor hook) is Verification Required item (15) — "**Still to verify in Step 1**" — and is explicitly allowed to come back "Pending" (ADR-0005 §13 Migration Plan: "or a recorded 'Pending' if item (15) fails"). This story's [C] clauses that depend on the hook must be written to accept that Pending outcome without failing the story.

**Control Manifest Rules (this layer)**:
- Required: "Actors use `render_mode ambient_light_disabled`. Only lights whose cull mask includes `ACTORS` light them" (Sprites, ADR-0005 §1–§2).
- Required: "The rim is added only on the rim texel ring (opaque, non-outline texels 4-adjacent to Outline Ink bordering transparency); never on the outline" (Sprites, ADR-0005 §1–§2).
- Required: "The capture tool sets `SubViewport` MSAA, screen-space AA and the positional shadow atlas size explicitly — a `SubViewport` does not inherit the project's settings (observed)" (FlashGate and the capture tool, ADR-0005 §12–§13).

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-32 [C]+[VF]** (P-09, P-10, P-17) (Pending: capture tool) One capture per lighting state (Title, Overworld, Battle, each faction's boss takeover, Camp, the Victory burst's peak, Defeat) at 1920×1080. Battle and one boss takeover are also captured at 1280×720, 2560×1440 and 2560×1080 (21:9). **[C] Read order:** every actor passes `read_order` in every valid sector, with emissive and below-the-feet ring pixels excluded. An invalid capture is a tool error, never a pass or a fail. The 720p capture must be valid. **[C] No glow on actors** (Pending: the glow-input hook): from the engine's glow input, before tonemapping, the brightest actor pixel is below that state's glow threshold, including at the Victory burst's peak. Glow bloom is 0 in every preset. **[VF] Sign-off:** the art director signs off the read order (actors first, rule UI second, set last) and the set's saturation.

---

## Implementation Notes

*Derived from ADR-0005 Decision §13 (the capture tool) and §2 (the sprite shader's lighting):*

- This story runs `tools/capture/presentation_capture.gd` (`story-002-*`) once per named lighting state, at the resolutions AC-32 specifies, producing one capture file per (state, resolution) pair.
- `read_order` is measured from the ID pass with emissive and below-the-feet-ring pixels excluded from the comparison — the capture tool's ID pass (per-class override materials, same frame) is what makes this measurable at all; an invalid capture (missing a required pass, wrong viewport settings) is a **tool error**, which this story's test harness must distinguish from a genuine pass/fail.
- "No glow on actors" depends on the glow-input hook reading the engine's glow buffer before tonemapping (Verification Required item 15) — if Step 1 records that item as failing, this clause's automated check stays **Pending** in this story's evidence, and the glow threshold is instead tuned by eye with a conservative margin (ADR-0005 Risks) until the hook exists.
- Glow bloom at 0 in every preset is a `LightingProfile` load-rule (§5, §9) already enforced at boot — this story's capture-based check is a second, independent confirmation on the shipped presets, not the only place that rule is tested.
- The `[VF]` sign-off (read order and set saturation) is a human judgement step: the art director reviews the retained captures and records sign-off in `production/qa/evidence/story-036-capture-one-screen-per-lighting-state-evidence.md` — this cannot be automated away.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-038-boss-takeover-faction-parity.md`: the boss-takeover-specific sky, star and flood checks (this story only needs one valid capture per boss takeover, not its full parity analysis).
- `story-039-texel-scale-holds-across-resolutions.md`: the texel-grid and whole-pixel-block checks at multiple resolutions.
- Building the capture tool itself (`story-002-*`, writer A).

---

## Files

- `tools/capture/presentation_capture.gd` (consumed, not authored, by this story)
- `tests/integration/presentation/read_order_capture_test.gd`
- `production/qa/evidence/story-036-capture-one-screen-per-lighting-state/`
- `production/qa/evidence/story-036-capture-one-screen-per-lighting-state-evidence.md`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: a retained screenshot in `production/qa/evidence/` + sign-off in `production/qa/evidence/story-036-capture-one-screen-per-lighting-state-evidence.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-002-*` (the capture tool); `story-001-*` (the spike settles the lighting presets this story captures); every MVP lighting profile authored (`title`, `overworld`, `battle`, `boss_bureaucratia`, `boss_megacorp`, `camp`, `victory`, `defeat`)
- Unlocks: None
