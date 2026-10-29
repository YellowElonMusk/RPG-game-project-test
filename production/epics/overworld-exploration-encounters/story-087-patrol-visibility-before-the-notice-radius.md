# Story 087: Every symbol's patrol is on screen from every approach, before the leader can be noticed

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Visual/Feel
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0005: Sprite & Camera Presentation (§14, per-cue capture-ID tags)
**ADR Decision Summary**: The presentation capture tool, tagged per cue (ADR-0005 §14) and driven by the level-review tool's per-symbol approach list, captures each patrol frozen at its nearest point to every approach, with the leader placed at `see_m + 0.1 m`, to prove no set occluder hides more than half the symbol's sprite mask inside its notice radius.
**ADR Version**: ADR-0012 2026-10-23 · ADR-0005 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Capture correctness depends on ADR-0005's camera/tilt-shift geometry (HIGH risk, post-cutoff rendering changes) and on the capture tool setting its own MSAA/shadow-atlas size, since a `SubViewport` does not inherit the project's antialiasing or shadow-atlas settings (probed, ADR-0005 item 8).

**Control Manifest Rules (this layer)**:
- Required: "the overworld camera must satisfy `chase_visibility` at 4:3, 16:9 and 21:9 including tilt-shift blur bounds measured from the leader" — source: ADR-0012 §7, TR-overworld-017
- Required: "Player-facing overworld text (posters, decrees, cards, barks) is `LocText`" is not relevant here; use instead: per-cue capture-ID tags exist for the level-review and capture tools — source: ADR-0005 §14

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-32 [VF] (R12, visibility)** The level-review tool and the capture-ID tags (both Tooling owed) list, for each symbol on each shipped map at each reachable stage, its approaches: walk-grid entries into the `see_m` disc, deduplicated by 45° sector. For each approach the symbol is **frozen at the patrol point nearest the approach** and the leader is placed at `see_m + 0.1 m` from it. The capture shows the symbol unoccluded: at least 50% of its sprite mask visible in the capture-ID pass. A retained screenshot per approach, plus the art-director sign-off. This AC covers set occluders only, since AC-39 proves the camera geometry.

---

## Implementation Notes

*Derived from ADR-0012 §7, ADR-0005 §14, and GDD rule 12 ("Visibility"):*

- The level-review tool (story 135, **Tooling owed**) enumerates each symbol's approaches: distinct walk-grid entries into the `see_m` disc around its patrol, deduplicated by 45° sector, per reachable stage.
- For each approach, freeze the symbol at the patrol point nearest that approach, place the leader at `see_m + 0.1 m` from it, and capture with the per-cue capture-ID tags (story 134, **Tooling owed**; ADR-0005 §14) so the symbol's own sprite mask can be isolated in the capture-ID pass.
- Pass requires at least 50% of the symbol's sprite mask visible — i.e. no set occluder (an interior wall taller than `wall_h_max` within `see_m`, or a diorama prop) hides more than half the patrol from that approach.
- This AC is scoped to **set occluders only**. It assumes the camera geometry itself already guarantees `R_vis ≥ see_m` — that assumption is proven separately by `chase_visibility` (story 099, AC-39).
- A retained screenshot per approach plus the art-director's sign-off, recorded in `production/qa/evidence/signoff-overworld.md`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The `chase_visibility` camera-geometry proof itself (story 099).
- The level-review tool's and capture-ID tags' own build (stories 134, 135 — Tooling owed).

---

## Files

- `production/qa/evidence/captures/` (retained screenshots; no code files — the tooling that produces them is built by stories 134 and 135)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- A retained screenshot per symbol per approach per reachable stage, in `production/qa/evidence/`, plus art-director sign-off in `production/qa/evidence/signoff-overworld.md`. Gate level: BLOCKING.
- **NOT ASSESSED** until stories 134 and 135 ship (Tooling owed).

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-135-level-review-walkin-tool.md` (the level-review tool), `story-134-capture-id-tags-for-overworld-cues.md` (per-cue capture-ID tags), `production/epics/sprite-camera-presentation/story-002-capture-tool.md` (the presentation capture tool), `production/epics/overworld-exploration-encounters/story-086-first-patrol-bypass-ratio-and-teaching-speaker.md`, `production/epics/overworld-exploration-encounters/story-099-chase-visibility-validates-at-every-aspect.md`
- Unlocks: None in this epic beyond the level-review tooling it consumes
