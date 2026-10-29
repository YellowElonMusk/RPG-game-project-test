# Story 080: Every EntryPoint sits clear of every MapExit rectangle, facing into the map

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-29)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-012`, `TR-overworld-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: `validate_maps.gd` checks every EntryPoint lies at least `body_radius + entry_clearance_m` outside every MapExit rectangle and faces into the map, so a held `move` on arrival never bounces the leader straight back out.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Pure geometric check over baked marker data; no post-cutoff API touched.

**Control Manifest Rules (this layer)**:
- Required: Exits fire only on entering their rectangle and EntryPoints sit clear of them — source: ADR-0012 §3 (`TR-overworld-012`)
- Forbidden: Never store a scene path on `MapData` — source: ADR-0012 (Alternative 5)
- Guardrail: Overworld load: one single-pass bake plus one component-labelling pass, inside the fade — source: ADR-0012 Performance (Load Time)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-30f [D] (R11, map exits)** Every EntryPoint lies at least `body_radius + entry_clearance_m` outside every MapExit rectangle and faces into the map.

---

## Implementation Notes

*Derived from GDD rule 11 ("Map exits"):*

- "Every EntryPoint lies at least `body_radius + entry_clearance_m` outside every MapExit rectangle, and faces into the map. A held `move` therefore never bounces the leader straight back out."
- `validate_maps.gd` checks this distance and the facing-into-the-map constraint for every EntryPoint against every MapExit rectangle on its map, naming the offending pair on failure.
- This is the data-level floor the runtime re-entry rule (story-081) depends on: without this clearance, a leader arriving at an EntryPoint could already overlap the very exit it just used.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-081-map-exit-reentry-requires-leaving-the-rectangle: the runtime enter-edge exit-firing rule (AC-30g)
- story-074-map-exit-and-critical-path-reference-integrity: exit target existence/reciprocity, not geometry (AC-30a)

---

## Files

- `tools/ci/validate_maps.gd`
- `data/maps/*`
- `tests/unit/overworld/data/entry_point_exit_clearance_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic (Data validation)
**Required evidence**:
- `tests/unit/overworld/data/entry_point_exit_clearance_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [x] Created and passing (6 cases); `tools/ci/validate_maps.gd` exits 0 on res://data and 1 on a broken EntryPoint facing (checked 2026-10-29)

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-074-map-exit-and-critical-path-reference-integrity.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-081-map-exit-reentry-requires-leaving-the-rectangle.md`
