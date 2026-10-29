# Story 084: No walk-grid route reaches the dungeon's boss-chamber exit without crossing the story encounter

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: `validate_maps.gd` proves, with every optional checkpoint already open, that the dungeon's walk grid still has no route from its EntryPoint to the boss-chamber exit that skips the story encounter's checkpoint cells.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: A pure graph-reachability check over the CI-side `WalkGrid`/component labels (4-connected, probed ~0.83 ms per full relabel on 60×60); no `AStarGrid2D` query is required beyond connectivity, since the proof is about the grid's topology, not a shortest path.

**Control Manifest Rules (this layer)**:
- Required: "story encounter and boss placement (the `confirm`-started Static exemption, return-marker distance, telegraph from the camp's safe-zone edge); … no route round the story encounter with every optional checkpoint open" — source: ADR-0012 §3
- Required: "`tools/ci/validate_maps.gd` … asserts every [D] criterion of the Overworld GDD" — source: ADR-0012 §3
- Forbidden: "Never use a physics body, area, cast or collision shape in the Overworld … `validate_maps.gd` enforces it" — source: ADR-0012 §2, §3

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-31d [D] (R12, no route round the story encounter)** On the dungeon, with every `open` and `item` checkpoint opened, every walk-grid route from its EntryPoint to its boss-chamber exit crosses the story encounter's checkpoint cells, and every symbol whose payoff opens the dungeon shortcut is reachable only beyond that checkpoint.

---

## Implementation Notes

*Derived from ADR-0012 §3 and GDD rule 12 ("The story encounter cannot be routed round"):*

- Build the dungeon's symbol-legal walk grid with every `open`- and `item`-gated checkpoint treated as open (the maximal-bypass scenario — bands are not applied here, since the point is topology, not notice avoidance).
- Remove the story encounter's own checkpoint cells from that grid and assert the dungeon's EntryPoint and its boss-chamber exit fall in **different** symbol-legal components. That is the proof that every route crosses those cells.
- Separately, for every symbol whose `victory_payoff` is `open` and opens the dungeon shortcut, assert its marker lies in the component reachable only from beyond the story encounter's checkpoint (never from the EntryPoint side with the checkpoint removed).
- This check only runs on the dungeon map, since it is the only map carrying the region's story encounter (rule 13a) in MVP Paris.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The ordered bypass search itself and its leg-splitting rule for a story-encounter-crossing leg (story 083).
- The story encounter's own placement rules — return-marker distance, telegraph sightline (story 091, AC-33d).

---

## Files

- `tools/ci/validate_maps.gd`
- `tests/unit/overworld/data/story_encounter_unbypassable_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic (Config/Data validation)
**Required evidence**:
- `tests/unit/overworld/data/story_encounter_unbypassable_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-083-bypass-lane-ordered-search.md`, `story-078-overworld-reference-integrity-check.md` (AC-30d, reference resolution for payoff → checkpoint links), `story-079-no-physics-nodes-in-shipped-maps.md` (AC-30e, no-physics scene baseline)
- Unlocks: `production/epics/overworld-exploration-encounters/story-091-permit-counter-static-behavior.md`
