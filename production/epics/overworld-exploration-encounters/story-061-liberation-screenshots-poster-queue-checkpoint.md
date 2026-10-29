# Story 061: Retained liberation screenshots — poster, queue, checkpoint, Reduce Motion

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Visual/Feel
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine; ADR-0005: Sprite & Camera Presentation (capture tooling, Reduce Motion)
**ADR Decision Summary**: Local liberation's on-screen removal is captured before/after through the presentation capture tool, including one frame mid-fade with Reduce Motion enabled, since the removal plays inside an in-mode or reverse-wipe fade that ADR-0005 owns.
**ADR Version**: ADR-0012 2026-10-23; ADR-0005 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Capture-tool dependent; no new runtime API. Risk follows ADR-0005's Engine Compatibility row (HIGH).

**Control Manifest Rules (this layer)**:
- Required: The lighting profile is resolved before the stage enters the tree — source: ADR-0012 §7, ADR-0005
- Forbidden: Never use a physics body, area, cast or collision shape in the Overworld, 2D or 3D — source: ADR-0012 §2, §3
- Guardrail: Overworld load: one single-pass bake plus one component-labelling pass, inside the fade — source: ADR-0012 Performance (Load Time)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-26b [VF] (R9)** Retained before / after screenshot pairs of one poster, one queue and one checkpoint liberated in Paris, plus one Reduce Motion frame captured mid-fade.

---

## Implementation Notes

*Derived from GDD rule 9 and the [VF] evidence tag:*

- Capture one before/after pair each for a poster, a queue and a checkpoint liberated on a Paris map, through the presentation capture tool (ADR-0005 Step 1c), timed against the on-screen removal window this epic's story-060 implements (`transition_finished` through `transition_finished + liberation_duration_s`).
- Capture one additional frame mid-fade with Reduce Motion enabled, to confirm the removal still reads correctly with ambient motion zeroed.
- Record art-director sign-off in `production/qa/evidence/signoff-overworld.md` per the `[VF]` evidence tag.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-060-liberation-removal-timing-on-screen-and-off-screen: the timing this story captures (AC-26a)
- story-065-stage-visual-capture-saturation-and-contrast: stage-level capture measurements (AC-27)

---

## Files

- `production/qa/evidence/captures/` (retained screenshots)
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

- Depends on: `production/epics/overworld-exploration-encounters/story-060-liberation-removal-timing-on-screen-and-off-screen.md`, `production/epics/sprite-camera-presentation/story-002-capture-tool.md`
- Unlocks: None
