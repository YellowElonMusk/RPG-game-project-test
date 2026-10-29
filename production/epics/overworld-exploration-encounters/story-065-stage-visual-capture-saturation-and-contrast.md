# Story 065: Stage-visual captures meet saturation, luminance and contrast targets

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Visual/Feel
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-017`, `TR-overworld-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine; ADR-0005: Sprite & Camera Presentation (lighting profile resolution, capture-tool masks)
**ADR Decision Summary**: Each map's lighting profile is resolved per map × faction × stage before the stage enters the tree; this story measures the resulting captures against the art bible's desaturated-set / saturated-actor and rising-luminance gradient targets.
**ADR Version**: ADR-0012 2026-10-23; ADR-0005 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Capture-tool masks (set vs. sprite pixels) measured per ADR-0005 Step 1c; the first `OmniLight3D` in a scene adds one surface pipeline and enabling its shadow adds one specialization pipeline (probed, 4.7.2) — relevant only if a capture triggers a new profile's first light.

**Control Manifest Rules (this layer)**:
- Required: The lighting profile is resolved per map × faction × stage, or the liberated profile, before the stage enters the tree — source: ADR-0012 §7, TR-overworld-017
- Forbidden: Never use a physics body, area, cast or collision shape in the Overworld, 2D or 3D — source: ADR-0012 §2, §3
- Guardrail: Overworld load: one single-pass bake plus one component-labelling pass, inside the fade — source: ADR-0012 Performance (Load Time)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-27 [C] (stage visuals)** On Paris captures at stages 1–3, using the capture tool's masks: the mean HSV saturation of set pixels is below that of sprite pixels; stage 3's mean scene luminance is at least stage 1's; `actor_contrast_min` ≥ 3.0.

---

## Implementation Notes

*Derived from GDD rule 8 (art bible §2 gradient) and the `[C]` evidence tag:*

- Capture each of Paris's three occupation stages through the presentation capture tool's masks, which separate set pixels from sprite pixels.
- Measure: mean HSV saturation of set pixels below mean HSV saturation of sprite pixels (the desaturated-set, saturated-actor rule); stage 3's mean scene luminance at least stage 1's (the occupation gradient brightens toward Saturated); `actor_contrast_min` ≥ 3.0.
- Log results to `production/qa/evidence/captures/` per the `[C]` evidence tag; `[C]` is BLOCKING because it is the mechanism that measures Visual items.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-066-region-liberation-presentation-override-on-load: the liberated override that reverses this gradient (AC-27b)
- story-067-liberated-paris-screenshots-golden-hour: the liberated-state screenshots (AC-27c)

---

## Files

- `production/qa/evidence/captures/`
- `data/maps/map_overworld_segment.tres`, `data/maps/map_town.tres`, `data/maps/map_dungeon.tres`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Visual/Feel (capture-measured)
**Required evidence**:
- Capture log in `production/qa/evidence/captures/` per the `[C]` evidence tag

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-058-marker-activation-slots-by-stage-and-cap.md`, `production/epics/sprite-camera-presentation/story-002-capture-tool.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-066-region-liberation-presentation-override-on-load.md`
