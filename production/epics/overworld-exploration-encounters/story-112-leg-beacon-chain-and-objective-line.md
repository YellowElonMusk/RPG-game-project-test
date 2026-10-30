# Story 112: Only the current leg's beacon chain is lit, and the objective line matches the step

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

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

- [x] **AC-45c [L] (R19)** On each map, only the current leg's beacon chain is lit, and its last beacon is on the leg's end (exit, story encounter, boss or café). The objective line equals the step's `objective_text`. With the setting on, the arrow points along the walk-grid path's next segment toward the beacon, and is hidden while the beacon is on screen.

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

*Changed by /dev-story (2026-10-30):*

- `src/overworld/beacon_guide.gd` (new: current leg, lit chain, chain progress, leader-legal A* arrow direction, arrow visibility, `Arrow` state)
- `src/overworld/overworld_mode.gd` (`refresh_beacons`, `lit_chain`, `next_beacon`, `objective_line`, `current_leg_id`, `next_destination_arrow`, injected `show_next_destination` / `beacon_on_screen`)
- `src/overworld/waypoint_beacon.gd` (`lit` flag + `lit_changed`)
- `src/overworld/overworld_config.gd` (`beacon_reach_m`, `next_destination_glyph`)
- `tests/unit/overworld/beacon_chain_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/overworld/beacon_chain_test.gd` — must exist and pass.

**Status**: [x] Created and passing — `tests/unit/overworld/beacon_chain_test.gd`, 16/16; full suite 1196/1196 (2026-10-30)

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-110-beacon-junction-coverage-validation.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-109-beacon-chain-walkin-capture.md`

---

## Completion Notes

**Completed**: 2026-10-30
**Criteria**: AC-45c covered by `tests/unit/overworld/beacon_chain_test.gd` (16 tests, all passing; suite 1196/1196).

- **Lit chain**: `BeaconGuide.apply_lit()` sets `WaypointBeacon.lit` only on the current leg's chain (`world_state.chapter_step` -> `ChapterStep.{map_id, leg_id}`; nothing lit when the step is on another map). `OverworldMode.refresh_beacons()` runs on the map-entry commit and each exploring frame (idempotent, keyed on map + leg). The leg-end placement of the last beacon stays story 110's validation; this story asserts the lit chain is ordered and ends on that marker.
- **Objective line**: `OverworldMode.objective_line()` returns the current step's text. **Deviation (naming)**: the field is `ChapterStep.objective`, not `objective_text`.
- **Arrow**: `show_next_destination` (default false, injected; `TODO(settings)`), `beacon_on_screen` Callable injected by the view (`TODO(ui)`). Next beacon = first not reached (`OverworldConfig.beacon_reach_m`, new knob, 1.5 m). Direction = first segment of an `AStarGrid2D` path over `WalkGrid.is_walkable()` (re-synced per `revision()`). **Deviation**: the grid's own A* is symbol-legal (excludes SAFE cells the leader can stand in), so `BeaconGuide` keeps a leader-legal twin with identical settings. Glyph = `OverworldConfig.next_destination_glyph` (U+25B2, rotated by direction).
- **Out of scope / TODO(ui)**: the drawn screen-edge widget and the lit/unlit banner visuals (ADR-0005).
- Status synced 2026-10-30 from commit ac013dc.
