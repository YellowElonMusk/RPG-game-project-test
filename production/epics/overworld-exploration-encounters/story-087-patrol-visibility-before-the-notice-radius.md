# Story 087: Every symbol's patrol is on screen from every approach, before the leader can be noticed

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30): signed off by the art director (the user)
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

- [x] **AC-32 [VF] (R12, visibility)** The level-review tool and the capture-ID tags (both Tooling owed) list, for each symbol on each shipped map at each reachable stage, its approaches: walk-grid entries into the `see_m` disc, deduplicated by 45° sector. For each approach the symbol is **frozen at the patrol point nearest the approach** and the leader is placed at `see_m + 0.1 m` from it. The capture shows the symbol unoccluded: at least 50% of its sprite mask visible in the capture-ID pass. A retained screenshot per approach, plus the art-director sign-off. This AC covers set occluders only, since AC-39 proves the camera geometry.

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

**Status**: [x] Created and signed off

---

## Dependencies

- Depends on: `story-135-level-review-walkin-tool.md` (the level-review tool), `story-134-capture-id-tags-for-overworld-cues.md` (per-cue capture-ID tags), `production/epics/sprite-camera-presentation/story-002-capture-tool.md` (the presentation capture tool), `production/epics/overworld-exploration-encounters/story-086-first-patrol-bypass-ratio-and-teaching-speaker.md`, `production/epics/overworld-exploration-encounters/story-099-chase-visibility-validates-at-every-aspect.md`
- Unlocks: None in this epic beyond the level-review tooling it consumes

## Progress Notes (2026-10-30)

- Built the parts of the owed tooling this AC needs: `PatrolApproaches` (story 135: approaches per 45-degree sector, the `see_m` disc measured along the walk grid so walls cut it) and `tools/level_review/walkin_capture.gd` (story 134 in miniature: per approach, four passes give the symbol mask and the share a set occluder hides). `OverworldConfig.see_lead_s` and `see_m()` added.
- Shipped maps: 23 approaches, all 100% visible, none clipped by the frame (`production/qa/evidence/story-087-patrol-visibility/report.md`). The gate was watched failing (0%, exit 1) with the segment east Clerk moved behind the row-12 wall block.
- The first capture run showed the dungeon first-room Clerk cut off by the camera clamp at the east wall (framing, AC-39, not an occluder); it moved from x 21.5 to 20.5. The report now flags any mask touching the frame edge.
- 2026-10-30: recaptured at the new 12.0 m camera height (story 099, OQ-1): 24 approaches, all 100% visible, none clipped. I opened a sample myself (segment east s0, dungeon first room s4, hall s7): the Clerk is unoccluded in each, and the first-room one sits near the right edge but inside the frame.
- Art-director sign-off recorded in `production/qa/evidence/signoff-overworld.md` (2026-10-30).
- 2026-10-30 (level-design pass, stories 086/119/103): recaptured after the segment's west Clerk moved and the dungeon gained four Clerks. 46 approaches, 0 failures. The new dungeon north-west Clerk is near the frame's top edge on its 270° approach; please look at that capture when signing off.
