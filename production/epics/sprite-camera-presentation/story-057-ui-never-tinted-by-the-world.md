# Story 057: The UI layer is never tinted by the world's tonemapper

> **Epic**: Sprite & Camera Presentation
> **Status**: Done (2026-10-31): capture PASS, lead sign-off pending
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-31

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-024`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: §5's faction dusk flood and tonemapper/exposure/AgX settings live entirely on the world-rendered `LightingProfile`; rule 11 (TR-presentation-024) requires that faction colour, and by extension any world tonemapping, never reaches the UI layer, which the capture tool's UI-alone pass (§13) exists to verify.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: The capture tool's UI-alone pass (§13) renders the UI layer with no world tonemapper applied, as the reference to diff the composited frame against. A fixture build that routes the UI through the world's tonemapper is the story's required negative control — it must fail this check, proving the check actually discriminates.

**Control Manifest Rules (this layer)**:
- Required: The capture tool sets `SubViewport` MSAA, screen-space AA and the positional shadow atlas size explicitly, and renders the UI layer alone as one of its passes (ADR-0005 §13)
- Required: Faction colour appears only on the sky, set and fill during a boss takeover; never on actors, neutral states, fades or UI (ADR-0005 §2, §3, §5)

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [x] **AC-53 [C]** (P-09) (UI never tinted; Pending: capture tool) For Battle, each faction's boss takeover, Defeat and the Victory peak, the final presented frame (HUD, a command menu, the Defeat card and damage numbers at full opacity) matches the UI layer rendered alone within ΔE 1 on every pixel where the UI is opaque. A fixture build that routes the UI through the world's tonemapper fails, as a negative control.

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines:*

This story runs the capture tool's UI-alone pass (§13) against the composited frame for five scenes (Battle, each faction's boss takeover, Defeat, the Victory peak) and diffs them at every pixel where the UI is opaque, within ΔE 1. No production rendering code is expected to change if the UI is already drawn on its own `CanvasLayer` outside the world's `WorldEnvironment`/tonemapper chain (ADR-0008 §9 HUD layering); this story is the capture-measured proof of that separation.
- The negative control is a deliberately broken fixture build that routes the UI canvas through the world tonemapper, included specifically so the check can be shown to fail on it.
- Covers five scenes in one story: Battle, both factions' boss takeovers, Defeat, and the Victory peak — all reuse the same capture procedure.
- Full-opacity HUD, command menu, Defeat card and damage numbers only; translucent UI elements are out of scope for the ΔE comparison.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-072-squad-never-tinted-by-the-boss-flood.md`: the same faction-colour rule, applied to actors instead of the UI
- `story-002-capture-tool.md` (writer A): builds the capture tool's UI-alone pass this story depends on

---

## Files

- *(capture-only; a fixture build for the negative control, otherwise no production file changes expected)*
- `production/qa/evidence/ui-never-tinted/`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- A retained capture-tool output in `production/qa/evidence/ui-never-tinted/`
- Sign-off in `production/qa/evidence/ui-never-tinted-evidence.md`

**Status**: [x] `production/qa/evidence/ui-never-tinted/` (tool `tools/capture/ui_tint_capture.gd`, exit 0: six scenes, shipped and AgX-world max ΔE 0.16-0.85 over the opaque UI; the UI-through-world-tonemapper negative control fails in every scene, max ΔE 11.6-14.9; world sensitivity control responds) + `production/qa/evidence/ui-never-tinted-evidence.md` (lead sign-off pending); `tests/unit/presentation/ui_tint_check_test.gd` (10 cases) passes; full suite 1922/1922, exit 0 (2026-10-31)

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-002-capture-tool.md` (the capture tool; this is a [C] story)
- Unlocks: None
