# Story 119: Each faction's first-encounter clue sits on the critical path before the first patrol

> **Epic**: Overworld Exploration & Encounters
> **Status**: Blocked (2026-10-30): the segment's first patrol and clue placement fail the rule; needs a level-design pass
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: — (not yet implemented)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0001: Content Data Storage (amended by ADR-0012)
**ADR Decision Summary**: ADR-0012 routes every per-map data criterion through `tools/ci/validate_maps.gd`, including ordered placement checks; ADR-0001 fixes the record vocabulary this check reads.
**ADR Version**: ADR-0012 2026-10-23; ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Pure data/geometry validation over the baked `WalkGrid`'s `L_crit` arc length; no engine surface beyond the already-probed `AStarGrid2D`/`TileMapLayer` bake.

**Control Manifest Rules (this layer)**:
- Required: "`tools/ci/validate_maps.gd` runs after `validate-content.gd`, runs `ContentBootstrap.run()` first, loads and bakes every map, and asserts every [D] criterion of the Overworld GDD" (ADR-0012 §3).
- Guardrail: none.

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-50 [D] (R16)** On each faction's first-encounter map, at least one marker tagged `faction_clue` lies within `interact_reach_m` of a cell on the critical path. Distances are **arc lengths along the leg's `L_crit` path from the leg's start EntryPoint** (for the Paris segment, the Town-side one). The clue comes before the first point within any notice radius, and the first patrol lies at least `safe_radius_m + symbol_chase_m + first_patrol_clearance_m` along it. A marker tagged `optional_teach` satisfies the same ordering, and it is a proximity bark or on-screen art, never a `confirm`-only line.

---

## Implementation Notes

*Derived from GDD rule 16 ("Faction-rule clue" and "Clearance") and rule 0's `L_crit` definition:*

- Distance measure: **arc length along the leg's `L_crit` path**, measured from the leg's start EntryPoint (rule 0: `L_crit(leg, stage)` is the walk-grid shortest path between the leg's two ends, with closed checkpoints handled by rule 12's ordered search). For the Paris segment this is the Town-side EntryPoint.
- The clue: at least one marker tagged `faction_clue` on each faction's first-encounter map must lie within `interact_reach_m` of a cell on the critical path, and must come **before** the first point within any symbol's notice radius along that path.
- Clearance: the first patrol on that map must lie at least `safe_radius_m + symbol_chase_m + first_patrol_clearance_m` along the critical path, so there is room beyond the safe zone and before the first patrol for the clue to sit in (rule 16 "Clearance"; clutter is barred from safe zones, so a civilian NPC inside the safe zone may carry the clue instead).
- `optional_teach`: a marker with this tag must satisfy the same before-first-notice ordering, and — unlike a clue poster — it must be a proximity bark or on-screen art, **never gated on `confirm`** (rule 16 "Clerks are optional"). Validate that an `optional_teach` marker is not a `confirm`-only Interactable kind.
- This is a [D] check over shipped content: apply the O-04 denominator guard (assert the expected faction/map population first; an empty population is **NOT ASSESSED**).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 118 (`story-118-gag-response-behavior.md`): what happens when the clue marker is interacted with (its `clue` response behaviour).
- Story 120 (`story-120-faction-clue-narrative-signoff-and-comprehension.md`): the narrative sign-off and the playtest comprehension check for the clue's content.
- Story 123 (`story-123-optional-teach-bark-trigger.md`): the `optional_teach` bark's own trigger/re-arm logic, once this story has confirmed its placement is legal.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `tools/ci/validate_maps.gd` (faction-clue and `optional_teach` placement/ordering check)
- `tests/unit/overworld/data/faction_clue_placement_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/overworld/data/faction_clue_placement_test.gd` — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-074-map-exit-and-critical-path-reference-integrity.md` (AC-30a, critical-path leg validation), `story-082-patrol-legality-at-every-reachable-stage.md` (AC-30h, patrol legality)
- Unlocks: `production/epics/overworld-exploration-encounters/story-120-faction-clue-narrative-signoff-and-comprehension.md`, `production/epics/overworld-exploration-encounters/story-123-optional-teach-bark-trigger.md`

## Blocked Notes (2026-10-30)

Measured on the shipped segment (the Paris first-encounter map) along `L_crit` from `from_town` to `exit_to_dungeon` (L_crit 19.9 m, 64 path cells):

- First point within any notice radius: **3.4 m** (the west Clerk, patrol (9.5, 5.5)–(14.5, 5.5)). That is inside the entry's 4.5 m safe zone edge.
- First patrol along the path: **6.2 m**; the rule needs ≥ `safe_radius_m + symbol_chase_m + first_patrol_clearance_m` = 10.5 m.
- The `faction_clue` poster (8.5, 12.5) is **not within `interact_reach_m` of any critical-path cell**.

Fixing it is a segment level-design pass: move the west Clerk past 10.5 m along the path, and put the clue poster and the `optional_teach` NPC on the path before the first notice point. Do it together with story 086 (first-patrol bypass ratio and the teaching speaker) and story 103 (dungeon density). Then re-prove the bypass and pressure validators, recapture story 087's walk-ins, and update the tests that pin segment coordinates. The validator itself (arc lengths over the `L_crit` cell set, where distance-from-start plus distance-to-end equals `L_crit`) is straightforward and should land with the content.
