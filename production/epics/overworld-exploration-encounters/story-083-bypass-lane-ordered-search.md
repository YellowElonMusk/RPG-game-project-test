# Story 083: The ordered search finds a bypass lane round every patrol band on every critical-path leg

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: `validate_maps.gd` runs rule 12's ordered search per critical-path leg and reachable stage, banding cells near active patrols as blocked, opening fight-free checkpoints, and splitting a leg that crosses the story encounter into two searches, to prove a bypass lane always exists.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: The search runs over a CI-side copy of the baked `WalkGrid`/`AStarGrid2D` (pinned `DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES`, octile, no jumping, `allow_partial_path = false`, probed on 4.7.2); band cells are never written through runtime `set_blocked` — they exist only for this search's own grid copy.

**Control Manifest Rules (this layer)**:
- Required: "`tools/ci/validate_maps.gd` … asserts every [D] criterion of the Overworld GDD" — source: ADR-0012 §3
- Required: "per leg and stage: the ordered bypass search, the pressure floor, the first-patrol ratio, density bands, the walk budget" — source: ADR-0012 §3
- Forbidden: "Never call `AStarGrid2D.update()` after the bake, or change `region`/`cell_size`/`offset`" — source: ADR-0012 §2 (probed)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-31 [D] (R12, bypass lane)** For every non-boss map, at every reachable stage, rule 12's **ordered search** succeeds on every critical-path leg: patrol bands and blocked cells closed; a checkpoint opened only after its fight-free source is reached earlier on the leg; `open`-payoff checkpoints closed; and a leg that crosses the story encounter split into its two searches (before it, to any cell within `interact_reach_m` of it, with bands; beyond its checkpoint with the checkpoint open). Legs ending at a symbol end within `interact_reach_m` of it. Nothing else is exempt.

---

## Implementation Notes

*Derived from ADR-0012 §3 and GDD rule 12 ("Bypass lane"):*

- **Bands.** Every cell whose centre lies within `symbol_chase_m + cell_m/√2` of any active patrol segment is treated as blocked for this search, as is every already-blocked cell (baked wall, active route-blocker).
- **Checkpoints.** A closed checkpoint counts as open once its requirement's fight-free `obtained_at` source (rule 0) is reachable earlier on the same leg, through the band-blocked grid. A checkpoint behind an `open` payoff stays closed — it needs a fight.
- **Story encounter split.** A leg crossing the Static story encounter splits into two searches: leg start → any cell within `interact_reach_m` of it (bands applied); then the cell beyond its checkpoint → leg end (that checkpoint open). Nothing else is exempt from the bands.
- **Leg ends.** A leg ending at a symbol (story encounter or boss) ends at any cell within `interact_reach_m` of it; a leg ending at a CampSpot ends in its safe zone.
- Each search's own shortest path is `L_bypass(leg, stage)`. On the boss chamber, which has no patrols, `L_bypass = L_crit`.
- Run this for every non-boss map, at every reachable stage derived from the ChapterFlow step list (`occupation_stage`).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The no-route-round-the-story-encounter proof on the dungeon (story 084).
- The dungeon's pressure floor and the first-encounter map's teaching-bypass ceiling, which reuse this search's `L_crit`/`L_bypass` (stories 085, 086).

---

## Files

- `tools/ci/validate_maps.gd`
- `tests/unit/overworld/data/bypass_lane_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic (Config/Data validation)
**Required evidence**:
- `tests/unit/overworld/data/bypass_lane_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-082-patrol-legality-at-every-reachable-stage.md`, `story-074-map-exit-and-critical-path-reference-integrity.md` (AC-30a, rule 0 groundwork for the ordered search), `story-080-entry-point-exit-clearance.md` (AC-30f, map exits as leg ends)
- Unlocks: `production/epics/overworld-exploration-encounters/story-084-story-encounter-not-routable-around.md`, `production/epics/overworld-exploration-encounters/story-085-dungeon-pressure-floor.md`, `production/epics/overworld-exploration-encounters/story-086-first-patrol-bypass-ratio-and-teaching-speaker.md`, `production/epics/overworld-exploration-encounters/story-087-patrol-visibility-before-the-notice-radius.md`
