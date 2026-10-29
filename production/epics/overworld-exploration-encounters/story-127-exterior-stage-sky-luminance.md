# Story 127: Exterior stage sky luminance stays at or above L* 60

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Visual/Feel
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: — (not yet implemented)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: ADR-0012's occupation-stage data (lighting profile keyed by faction × stage) drives the fill that could darken the sky; ADR-0005 §14 resolves the actual lighting profile and owns the capture-ID tooling this measurement needs.
**ADR Version**: ADR-0012 2026-10-23; ADR-0005 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Reuses the ADR-0012/ADR-0005 lighting-profile resolution already probed (item 9: first `OmniLight3D` pipeline cost); no new engine surface for this story itself.

**Control Manifest Rules (this layer)**:
- Required: none directly (a capture-measured validation, not a coded rule).
- Guardrail: none.

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-54 [C] (stage visuals)** On Paris captures of every exterior stage, the mean CIELAB L* (sRGB, D65) of the top 25% (by row of its bounding box) of the sky mask (capture-ID `SKY`; Tooling owed) is at least 60.

---

## Implementation Notes

*Derived from GDD § Occupation stages (Bureaucratia Paris):*

- The lighting rule (user ruling, 2026-10-22): the key light stays Storybook Amber at every stage; stages flatten the scene by **raising the faction-tinted fill**, never by darkening it. At Saturated (3), "the sky's upper gradient tinted but kept at L* ≥ 60, so the boss dusk flood (L* ≤ 35) stays a separate event."
- Measure: the `SKY` capture-ID mask's top 25% of rows (by its bounding box), mean CIELAB L* in sRGB/D65, must be ≥ 60 — on **every exterior stage** Paris ships (test plan O-06: `CP-TOWN-S1`, `CP-SEG-S2`; the liberated poses are measured and logged, not gated).
- This explicitly excludes interiors (the dungeon uses the Dungeon row, cool ambient with a travelling light pool — not an exterior stage) and excludes the boss dusk flood, which is a deliberate separate event below this floor.
- Procedure: render the named pose (test plan O-06) through the capture tool with the `SKY` capture-ID tag (story 134), then compute the measurement exactly as the AC states.
- Until story 134 (capture-ID tags) ships, this AC reports **NOT ASSESSED**, never a pass (test plan NOT ASSESSED rule).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 134 (`story-134-capture-id-tags-for-overworld-cues.md`): the `SKY` capture-ID tag and mask rendering itself.
- Interior lighting (the dungeon's travelling light pool) and the boss dusk flood — separate, deliberately different luminance targets, not this AC.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- No new source files — measures the existing lighting-profile output through the capture tool.
- `production/qa/evidence/captures/` (measurement log)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: capture-measured log in `production/qa/evidence/captures/`. BLOCKING, but **NOT ASSESSED** until story 134 ships.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-134-capture-id-tags-for-overworld-cues.md`, `story-065-stage-visual-capture-saturation-and-contrast.md` (AC-27, stage visuals), `production/epics/sprite-camera-presentation/story-004-sprite-projection-pixel-exact-quad.md` (projection)
- Unlocks: None
