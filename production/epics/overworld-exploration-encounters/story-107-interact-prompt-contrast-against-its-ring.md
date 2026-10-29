# Story 107: The interact prompt's mask clears 3:1 contrast against its own ring on the same poses

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Visual/Feel
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0005: Sprite & Camera Presentation (§14, per-cue capture-ID tags)
**ADR Decision Summary**: The interact prompt — the one composite element `probe()` drives (rule 3) — carries its own capture-ID tag, so the same grayscale contrast measurement used for event cues (story 106) applies to it.
**ADR Version**: ADR-0012 2026-10-23 · ADR-0005 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Same capture-pipeline dependency as story 106 (`SubViewport` AA/shadow-atlas settings set explicitly by the capture tool, probed).

**Control Manifest Rules (this layer)**:
- Required: "Interaction is one `probe()` … that drives both the prompt and `confirm`" — source: ADR-0012 §6, GDD rule 3 / AC-7a

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-44b [C] (accessibility)** On the same poses, the interact prompt's mask measures at least 3:1 contrast against its 4 px ring.

---

## Implementation Notes

*Derived from ADR-0012 §6, ADR-0005 §14 and GDD UI Requirements ("Interact prompt"):*

- Reuse story 106's capture poses (Town, overworld segment, dungeon; every reachable stage; 1080p) and its measurement method (grayscale luminance against a 4 px dilation of the element's own mask).
- Apply it to the interact prompt — the cream rounded-rectangle pip with its Outline Ink border and kind icon (UI Requirements) — on each pose where `probe()` returns an eligible target.
- Pass requires ≥ 3:1, matching the UI Requirements table's own "≥ 3:1 non-text contrast" commitment for the prompt.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The event-cue contrast measurement itself (story 106).
- The prompt's screenshot coverage across icon kinds and devices (story 108).

---

## Files

- `production/qa/evidence/captures/`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Visual/Feel (capture-measured)
**Required evidence**:
- Capture logs in `production/qa/evidence/captures/`. Gate level: BLOCKING (it measures a Visual item).
- **NOT ASSESSED** until story 134 ships (Tooling owed).

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-106-event-cue-contrast-against-its-ring.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-108-ui-screenshots-prompts-cards-and-prompts.md`
