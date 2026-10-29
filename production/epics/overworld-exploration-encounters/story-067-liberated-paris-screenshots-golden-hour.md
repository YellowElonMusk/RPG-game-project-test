# Story 067: Retained liberated-Paris screenshots — golden hour, no faction dressing, no celebration

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Visual/Feel
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine; ADR-0005: Sprite & Camera Presentation (liberated lighting profile, interior fill removal)
**ADR Decision Summary**: The liberated presentation is captured and signed off against the art bible's "liberation runs the gradient in reverse" principle: golden-hour light, no faction dressing, and no celebration tableau.
**ADR Version**: ADR-0012 2026-10-23; ADR-0005 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Capture-tool dependent; no new runtime API. Risk follows ADR-0005's row (HIGH).

**Control Manifest Rules (this layer)**:
- Required: The lighting profile is resolved before the stage enters the tree — source: ADR-0012 §7, ADR-0005
- Forbidden: Never use a physics body, area, cast or collision shape in the Overworld, 2D or 3D — source: ADR-0012 §2, §3
- Guardrail: Overworld load: one single-pass bake plus one component-labelling pass, inside the fade — source: ADR-0012 Performance (Load Time)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-27c [VF] (R17)** Retained screenshots of each Paris map at its highest stage and again after region liberation: golden-hour light (the Dungeon row without fluorescent fill for interiors), no faction set dressing, the skyline landmark restored, and no celebration tableau.

---

## Implementation Notes

*Derived from GDD rule 17 and rule 13 ("the scene does not celebrate"):*

- Capture each Paris map at its highest reachable stage, then again after region liberation, through the presentation capture tool.
- Verify: golden-hour exterior light; for interiors, the Dungeon lighting row with its fluorescent faction fill removed; every faction set-dressing addition gone, the Paris skyline landmark restored (its in-trays removed); no celebration tableau — at least one grumbler NPC and one "Bureaucratia had a point" item remain visible (rule 13).
- Record art-director sign-off in `production/qa/evidence/signoff-overworld.md` per the `[VF]` evidence tag.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-066-region-liberation-presentation-override-on-load: the logic this story captures (AC-27b)
- story-076-permit-counter-telegraph-screenshot: a different [VF] walk-in, unrelated to liberation (AC-30i)

---

## Files

- `production/qa/evidence/captures/`
- `production/qa/evidence/signoff-overworld.md`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- A retained screenshot in `production/qa/evidence/` + sign-off in `production/qa/evidence/signoff-overworld.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-066-region-liberation-presentation-override-on-load.md`, `production/epics/sprite-camera-presentation/story-002-capture-tool.md`
- Unlocks: None
