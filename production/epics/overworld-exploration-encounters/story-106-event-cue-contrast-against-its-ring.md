# Story 106: Every accessibility cue clears 3:1 contrast against a 4px dilation of its own mask

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Visual/Feel
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0005: Sprite & Camera Presentation (§14, per-cue capture-ID tags)
**ADR Decision Summary**: Every `[A11Y]`-marked event cue carries its own capture-ID tag (ADR-0005 §14), so the presentation capture tool's grayscale conversions can measure each cue's luminance contrast against a 4 px dilation of its own mask, independent of color.
**ADR Version**: ADR-0012 2026-10-23 · ADR-0005 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Grayscale/luminance measurement runs over the capture tool's output; a `SubViewport` does not inherit the project's MSAA or shadow-atlas settings (probed, ADR-0005 item 8), so the capture tool sets them explicitly — this story depends on that, not on new engine surface of its own.

**Control Manifest Rules (this layer)**:
- Required: Presentation's data-out row supplies "the notice, chase, stun and liberation cues" per map × faction × stage — source: ADR-0012 §7, Interactions with Other Systems table

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-44a [C] (accessibility)** Each cue node carries a capture-ID tag (Tooling owed: ADR-0005 §14 tags in the §13 capture tool). On grayscale conversions of the test plan's named capture poses (Town, overworld segment and dungeon, at every reachable stage, at 1080p), each of these cues has a luminance contrast of at least 3:1 against a ring formed by a 4 px dilation of its mask: the notice slip, the chase "!" tag, the stunned pose, the checkpoint open and closed states, the safe-zone paving edge, map exits with the beacon, and the camp sign.

---

## Implementation Notes

*Derived from ADR-0005 §14 and GDD Visual/Audio Requirements ("Event feedback", `[A11Y]`):*

- Every listed cue — the notice slip, the chase "!" tag, the stunned pose, the checkpoint open/closed states, the safe-zone paving edge, map exits with the beacon, and the camp sign — carries its own capture-ID tag (story 134, **Tooling owed**; ADR-0005 §14).
- Run the test plan's named capture poses (Town, overworld segment, dungeon; every reachable stage; 1080p) through the capture tool, convert to grayscale, and measure each tagged cue's luminance contrast against a ring formed by a 4 px dilation of its own mask.
- Pass requires ≥ 3:1 for every cue in every named pose — this is the "non-color backup" half of the `[A11Y]` commitment (Visual/Audio Requirements: "every cue has a non-color backup").

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The interact prompt's own contrast measurement (story 107, same method, different element).
- The capture tool and its capture-ID tagging mechanism themselves (story 134 — Tooling owed).

---

## Files

- `production/qa/evidence/captures/` (retained screenshots; no code files — the capture-ID tagging is story 134's)

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

- Depends on: `story-134-capture-id-tags-for-overworld-cues.md` (per-cue capture-ID tags), `production/epics/sprite-camera-presentation/story-002-capture-tool.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-107-interact-prompt-contrast-against-its-ring.md`
