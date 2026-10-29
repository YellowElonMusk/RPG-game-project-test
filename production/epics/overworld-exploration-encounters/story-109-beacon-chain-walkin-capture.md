# Story 109: Each junction node shows the next beacon in the leg's chain

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Visual/Feel
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: — (not yet implemented)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time. No TR names the beacon chain directly; TR-017 — Presentation, on-screen guarantees via the shipped camera — is the closest match.)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0005: Sprite & Camera Presentation (§14 overworld profiles)
**ADR Decision Summary**: ADR-0012 leaves navigation-assist beacons as GDD rule 19 content with no dedicated script in its Key Interfaces; ADR-0005 fixes the follow camera formula and `chase_visibility` that any walk-in capture is framed by.
**ADR Version**: ADR-0012 2026-10-23; ADR-0005 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No new engine surface — this story captures existing geometry through the shipped follow camera. Inherits ADR-0005's camera risk (post-cutoff camera/lighting APIs) rather than any new probe.

**Control Manifest Rules (this layer)**:
- Required: "Marker ground positions come from the `x`/`z` of their transform relative to the map root... never read `global_*`" (ADR-0012 §3) — beacon banners are markers and must be read the same way.
- Forbidden: none specific to this story beyond the physics-node ban (ADR-0012 §2, §3).
- Guardrail: none (capture-time check, not a runtime budget).

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-45e [VF] (R19, beacon chain)** For each map, each leg and each reachable stage, the level-review tool places the leader at every junction node of the leg. Each capture shows the **next** beacon in the chain with at least 50% of its mask visible in the capture-ID pass (both Tooling owed). Retained screenshots plus the art-director sign-off.

---

## Implementation Notes

*Derived from ADR-0012 and GDD rule 19:*

Rule 19 commits to a diegetic beacon chain as the accessibility navigation assist: lantern banners whose last beacon in a leg always marks that leg's end (exit, story encounter, boss or café). This story is the proof obligation, not the authoring — it runs the walk-in procedure (test plan O-07) against already-authored junction nodes and beacon chains and retains the result.

- From every junction node (GDD rule 19 "Junctions"; defined precisely by AC-45f / story 110), the **next** beacon in the current leg's chain must be on screen.
- `beacon_h_m ≥ wall_h_max + 0.5` (invariant I18) is what makes this physically possible — a banner clears any wall into the camera's view — but this story measures the outcome, not the height knob.
- Procedure (test plan O-07): the level-review tool (story 135) places the leader at the junction node facing along the leg, lets followers snap and the follow camera settle, then the capture tool (story 134's capture-ID tags) renders the ID pass twice — normal and with set geometry hidden. Visible fraction = beacon mask pixels (normal) ÷ beacon mask pixels (unoccluded). Pass at visible fraction ≥ 0.5.
- Beacons light for the current leg only; banners on other legs are unlit set dressing and must not satisfy the measurement.
- Retain every placement's screenshot, both ID passes and the measurement row under `production/qa/evidence/captures/walkin-[map]-[stage]/`, listed on the art-director sign-off sheet.
- Until story 134 (capture-ID tags) and story 135 (the level-review tool) ship, this AC reports **NOT ASSESSED**, never a pass.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 110 (`story-110-beacon-junction-coverage-validation.md`): defines and CI-validates which cells are junction nodes.
- Story 112 (`story-112-leg-beacon-chain-and-objective-line.md`): which beacons are lit for the current leg, and the objective line / optional arrow.
- Story 134 (`story-134-capture-id-tags-for-overworld-cues.md`): the `exit_beacon` capture-ID tag and the hidden-geometry ID pass this story's measurement depends on.
- Story 135 (`story-135-level-review-walkin-tool.md`): the tool that lists junction nodes and drives the placements.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- No new source files — this story runs the O-07 walk-in procedure against shipped map/leg/beacon data and the tools from stories 134–135.
- `production/qa/evidence/captures/walkin-[map]-[stage]/` (retained screenshots, ID passes, measurement rows)
- `production/qa/evidence/signoff-overworld.md` (art-director sign-off entry)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: a retained screenshot in `production/qa/evidence/` plus sign-off in `production/qa/evidence/signoff-overworld.md` (art-director verdict per clause, test plan O-10). BLOCKING, but **NOT ASSESSED** until stories 134 and 135 ship (test plan's NOT ASSESSED rule).

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-110-beacon-junction-coverage-validation.md`, `production/epics/overworld-exploration-encounters/story-134-capture-id-tags-for-overworld-cues.md`, `production/epics/overworld-exploration-encounters/story-135-level-review-walkin-tool.md`, `production/epics/sprite-camera-presentation/story-023-follow-camera-matches-the-formula.md` (the follow camera the walk-in is framed by)
- Unlocks: None
