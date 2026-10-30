# Story 053: The occupation stage formula is monotonic and matches the flag-to-stage table

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: Occupation stage per map is computed only on load from `base_stage` plus a flag-to-stage table, and the stage never decreases: `stage = max(stage_new, stage_stored)`.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: Pure formula over `MapData` fields and world-state flags; no engine API involved.

**Control Manifest Rules (this layer)**:
- Required: Stage computed only on map load, from `MapData.base_stage`/`stage_table` — ADR-0012 §3
- Forbidden: Never let a removed raising flag lower a stored stage — ADR-0012, GDD Edge Cases
- Guardrail: n/a

---

## Acceptance Criteria

- [x] **AC-22 [L] (`occupation_stage`)** Parametrized over `base_stage`, stage tables and flag sets (the empty set included): the stage equals the formula. A fixture removing a raising flag keeps the stage and logs a warning. Over any sequence of loads, the stage never decreases.

---

## Implementation Notes

*Derived from the GDD Formulas section (`occupation_stage`):*

`stage_new = clamp(max({base_stage} ∪ {s : (f, s) ∈ stage_table, f ∈ flags}), 1, 3); stage = max(stage_new, stage_stored); stage_stored ← stage`.

- Parametrize the test over `base_stage` (1–3), several `stage_table` shapes, and flag sets **including the empty set** — the empty-set case must reduce to `stage_new = base_stage` (the GDD's own example: the overworld segment's table `{permits_mandatory: 2}` with the flag unset still yields `base_stage`).
- Compute expected values from the formula itself (never a literal), per the harness's standing rule, and run the parametrized set once more with a non-default `OverworldConfig`/table shape.
- Fixture a flag **removal** between loads (simulating a migration or data error): assert the stage holds at its previously stored value (`stage_stored` wins the `max`) and a development warning is logged — this is the Edge Cases branch ("If a flag would lower a stage").
- Drive a sequence of several loads with flags added and removed in different orders; assert the stage is monotonically non-decreasing across the whole sequence, not just across any single pair of loads.

---

## Out of Scope

- `story-054-stage-change-waits-for-next-load.md`: when a flag set mid-visit takes effect.
- Marker activation (`marker_activation`) and stage-raise CI scheduling checks: separate stories elsewhere in this epic.

---

## Files

- `src/overworld/overworld_mode.gd`
- `src/data/records/map_data.gd`
- `tests/unit/overworld/occupation_stage_formula_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/occupation_stage_formula_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `story-017-zone-rate-zero-on-every-mvp-map.md` (AC-8, `MapData` record validation foundation)
- Unlocks: `story-054-stage-change-waits-for-next-load.md`
