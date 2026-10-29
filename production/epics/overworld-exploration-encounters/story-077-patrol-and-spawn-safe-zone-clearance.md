# Story 077: No spawn point or patrol segment crowds a safe zone or a return marker

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-29)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: `validate_maps.gd` measures every symbol's spawn point and every patrol segment — the closing segment of a `loop` path included — against `safe_radius_m` of EntryPoints/CampSpots/MapExit rectangles, and against `symbol_chase_m + body_radius` of every return marker.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Pure geometric-distance check over baked marker and patrol data; no post-cutoff API touched.

**Control Manifest Rules (this layer)**:
- Required: `tools/ci/validate_maps.gd` asserts patrol segments clear of safe zones and symbol-legal at every reachable stage — source: ADR-0012 §3
- Forbidden: Never store a scene path on `MapData` — source: ADR-0012 (Alternative 5)
- Guardrail: Overworld load: one single-pass bake plus one component-labelling pass, inside the fade — source: ADR-0012 Performance (Load Time)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-30c [D] (R12)** No spawn point or patrol segment (closing segment included) lies within `safe_radius_m` of any EntryPoint or CampSpot (segment-to-point) or MapExit trigger rectangle (segment-to-rectangle), or within `symbol_chase_m + body_radius` of any return marker.

---

## Implementation Notes

*Derived from GDD rule 12 ("Safe zones"):*

- Distance is measured segment-to-rectangle for exits and segment-to-point otherwise, with the closing segment of a `loop` path included, so a chase or push can never stop inside a return marker's margin once grace ends.
- This is the data-level floor rule 12's "Symbols never enter safe zones" runtime guarantee depends on: `SAFE` cells are not symbol-legal, so the patrol itself must never have been authored to overlap one in the first place.
- `validate_maps.gd` runs this per symbol, per map, naming the symbol and the violated margin on failure.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-073-checkpoint-requirement-and-critical-path-reachability: the bypass-lane/pressure-floor checks that build on this clearance (AC-31 range, outside this writer's assignment)

---

## Files

- `tools/ci/validate_maps.gd`
- `data/maps/*`
- `tests/unit/overworld/data/patrol_and_spawn_safe_zone_clearance_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic (Data validation)
**Required evidence**:
- `tests/unit/overworld/data/patrol_and_spawn_safe_zone_clearance_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-020-patrol-loop-and-pingpong-traversal.md` (patrol path authoring)
- Unlocks: `production/epics/overworld-exploration-encounters/story-078-overworld-reference-integrity-check.md`
