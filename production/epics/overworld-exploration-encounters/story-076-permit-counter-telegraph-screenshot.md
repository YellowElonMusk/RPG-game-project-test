# Story 076: Retained walk-in screenshot — the Permit Counter is on screen from the pre-dungeon camp

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Visual/Feel
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-012`, `TR-overworld-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine; ADR-0005: Sprite & Camera Presentation (camera footprint, capture tooling)
**ADR Decision Summary**: The story encounter's telegraph (rule 13a) is confirmed visually, not just numerically: a retained screenshot from the pre-dungeon CampSpot's safe-zone edge, facing the Counter, with art-director sign-off.
**ADR Version**: ADR-0012 2026-10-23; ADR-0005 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Capture-tool and level-review-tool dependent; no new runtime API. Risk follows ADR-0005's row (HIGH).

**Control Manifest Rules (this layer)**:
- Required: The lighting profile is resolved before the stage enters the tree — source: ADR-0012 §7, ADR-0005
- Forbidden: Never use a physics body, area, cast or collision shape in the Overworld, 2D or 3D — source: ADR-0012 §2, §3
- Guardrail: Overworld load: one single-pass bake plus one component-labelling pass, inside the fade — source: ADR-0012 Performance (Load Time)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-30i [VF] (R13a, telegraph)** A retained walk-in screenshot with the leader at the pre-dungeon CampSpot's safe-zone edge, facing the Counter, shows the Permit Counter on screen; art-director sign-off in `production/qa/evidence/signoff-overworld.md`.

---

## Implementation Notes

*Derived from GDD rule 13a ("Telegraphed") and the Tooling-owed note:*

- Rule 13a: "Its distance from the pre-dungeon CampSpot's safe-zone edge is at most `story_sight_m` along the walk grid, and it is on screen from that edge: checked by the visibility edge `R_e` ..., plus a [VF] walk-in (AC-30b)."
- The level-review tool places the leader at the CampSpot's safe-zone edge facing the Counter (its own listed capability: "places walk-in captures"); the presentation capture tool then takes the screenshot.
- This story is the **visual** confirmation of story-075's numeric `R_e`/`story_sight_m` check: the numeric check proves it is geometrically possible, this screenshot proves it actually reads on screen once lit and dressed.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-075-town-dungeon-story-encounter-and-boss-placement: the numeric telegraph distance/visibility check (AC-30b)

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

- Depends on: `production/epics/overworld-exploration-encounters/story-075-town-dungeon-story-encounter-and-boss-placement.md`, `production/epics/sprite-camera-presentation/story-002-capture-tool.md`, `production/epics/sprite-camera-presentation/story-023-follow-camera-matches-the-formula.md`, `production/epics/overworld-exploration-encounters/story-135-level-review-walkin-tool.md` (level-review tool)
- Unlocks: None
