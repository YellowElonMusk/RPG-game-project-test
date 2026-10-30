# Story 078: Every encounter, symbol, flag, payoff, remark, decree-gag and item reference resolves

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: `validate_maps.gd` extends ADR-0001's generic reference-resolution pass to every Overworld-specific reference kind: `enc_`, `symbol_id`, `liberation_flag`, `victory_payoff`, `recruit_remark`, decree-gags and items.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Pure reference-resolution pass over the loaded catalog; no post-cutoff API touched.

**Control Manifest Rules (this layer)**:
- Required: `tools/ci/validate_maps.gd` asserts unique marker IDs and that every reference resolves (`enc_`, `map_`, `symbol_id`, flags, payoffs, items, `obtained_at`, `recruit_remark`, decree gags) — source: ADR-0012 §3
- Forbidden: Never store a scene path on `MapData` — source: ADR-0012 (Alternative 5)
- Guardrail: Overworld load: one single-pass bake plus one component-labelling pass, inside the fade — source: ADR-0012 Performance (Load Time)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-30d [D] (references)** Every `enc_`, `symbol_id`, `liberation_flag`, `victory_payoff`, `recruit_remark`, decree-gag and item reference resolves.

---

## Implementation Notes

*Derived from ADR-0012 §3's generic reference pass (an additive amendment to ADR-0001):*

- `validate_maps.gd`'s reference pass is run against every Overworld record kind listed in ADR-0012 §3's marker and record tables: `EncounterSymbol.enc_id`/`symbol_id`, `Clutter.liberation_flag`, `EncounterData.victory_payoff`, any marker's `recruit_remark`, `Interactable.decree_gag`'s raising flag, and every item ID a `pickup` or `victory_payoff` names.
- One named error per unresolved reference, keyed to the record and field it was found on, so a broken reference is never silently treated as absent.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-074-map-exit-and-critical-path-reference-integrity: map/exit/leg/step references specifically (AC-30a)
- story-055-paris-map-stage-and-decree-registry-rules: the story-flag **registry** check itself (AC-23b)

---

## Files

- `tools/ci/validate_maps.gd`
- `data/maps/*`, `data/encounters/*`
- `tests/unit/overworld/overworld_references_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic (Data validation)
**Required evidence**:
- `tests/unit/overworld/overworld_references_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: None
- Unlocks: `production/epics/overworld-exploration-encounters/story-079-no-physics-nodes-in-shipped-maps.md`

## Completion Notes (2026-10-30)

- `MapValidator.check_references()` runs in `validate_maps` (CI) with the rule-18 registry (`OverworldConfig.flag_registry_path`). It gives one named error per broken reference:
  - Symbols: `encounter_id`, and symbol IDs unique per map.
  - Gags: `liberate_symbol`, `liberation_flag`, `decree_first_sight`, and `decree_stage` (a registered flag in the map's `stage_table` must raise to it).
  - Checkpoints: `requirement_item_id`, `requirement_flag`, `linked_encounter_id`.
  - Each placed encounter's `victory_payoff`: known type; `open` names a checkpoint on the map; `item` names an item record; `clue` names a facet.
- `recruit_remark`: no marker has the field yet (squad recruitment is undesigned), so there is nothing to resolve. Add it to this pass when it lands.
- Mutation checked: dropping the `liberate_symbol` check fails a test here.
