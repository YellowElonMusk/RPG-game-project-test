# Story 112: Only the current leg's beacon chain is lit, and the objective line matches the step

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: — (not yet implemented)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time. No TR names the beacon chain or objective line directly; TR-017 — Presentation — is the closest match.)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0005: Sprite & Camera Presentation (§14 overworld profiles)
**ADR Decision Summary**: ADR-0012 leaves which beacons light as GDD rule 19 content, driven by `WorldState.chapter_step` / `OverworldMode`; ADR-0005 owns how the lit/unlit banners actually render.
**ADR Version**: ADR-0012 2026-10-23; ADR-0005 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No new engine surface; walk-grid path following for the optional arrow reuses the baked `WalkGrid`/`AStarGrid2D`, already probed (ADR-0012 Engine Compatibility items 3, 5, 10).

**Control Manifest Rules (this layer)**:
- Required: "The current chapter step is `WorldState.chapter_step`, written only by `OverworldMode`; the static step list is interim `ChapterSteps` data" (ADR-0012 §8).
- Required: "Blocked cells change only through batched `WalkGrid.set_blocked(cells, on)`" (ADR-0012 §2) — the optional arrow's path-following must read the grid, never bypass it with a straight line through walls.
- Forbidden: a colour-only cue (GDD rule 19's "shape glyph, never a colour-only cue") — not an engine rule, but a hard requirement on the arrow's rendering.

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-45c [L] (R19)** On each map, only the current leg's beacon chain is lit, and its last beacon is on the leg's end (exit, story encounter, boss or café). The objective line equals the step's `objective_text`. With the setting on, the arrow points along the walk-grid path's next segment toward the beacon, and is hidden while the beacon is on screen.

---

## Implementation Notes

*Derived from ADR-0012 and GDD rule 19:*

- Lit beacons: only the chain belonging to the **current** leg (`WorldState.chapter_step` names the current `{map_id, leg_id}`, rule 0's "current leg" term). Banners on every other leg stay unlit set dressing.
- Leg end: the last beacon in a lit chain must sit on the leg's end — a `MapExit`, the story encounter, the boss, or the café camp (rule 0's leg `to` definition).
- Objective line: the Menu's one-line objective must equal the current chapter step's `objective_text` (rule 19, "Objective line"; ChapterFlow is the interim source until Dialogue, Banter & Quests is designed).
- Optional arrow (default off, "Show next destination" setting): when on, it points **along the walk-grid path's next segment** toward the beacon — never a straight line through walls — and is hidden while that beacon is already on screen (rule 19 "Optional marker"). It carries a shape glyph, never a colour-only cue (guardrail 5: legible without UI).
- The arrow is a screen-edge indicator, not a 3D gizmo; its path-following must read the same baked `WalkGrid` the leader's pathing would use, so it never contradicts what `AStarGrid2D` would return.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 109 (`story-109-beacon-chain-walkin-capture.md`): the on-screen visual proof from every junction node.
- Story 110 (`story-110-beacon-junction-coverage-validation.md`): where junction nodes are, and I18's height invariant.
- Story 111 (`story-111-map-name-card-timing.md`): the map name card, a separate UI element on a different trigger.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/overworld/overworld_mode.gd` (current-leg beacon activation, objective line, optional-arrow pathing)
- `src/overworld/world_state.gd` (`chapter_step` read, interim `ChapterSteps` data read)
- `tests/unit/overworld/beacon_chain_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/overworld/beacon_chain_test.gd` — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-110-beacon-junction-coverage-validation.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-109-beacon-chain-walkin-capture.md`
