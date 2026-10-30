# Story 098: `OverworldConfig.validate()` rejects exactly the knob combination that breaks its invariant

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
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
**ADR Decision Summary**: `OverworldConfig.validate()` checks every load-time invariant I1–I18 at boot and in CI, and every error names its invariant's ID.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: Pure arithmetic over `Resource` fields; no engine surface beyond `OverworldConfig extends Resource`.

**Control Manifest Rules (this layer)**:
- Required: "Records never contain file paths; tuning comes from `OverworldConfig` or records, validated by `OverworldConfig.validate()` (invariants I1–I18, each error names its ID)" — source: ADR-0012 §9

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-38 [L] (invariants)** The default config passes. One fixture per invariant I1–I13 and I15–I18 breaks only that invariant, and its error names that ID (for I15, `symbol_chase_m` 3.5 with `notice_path_cap_m` 4.5; for I16, `notice_path_cap_m` 5 with `symbol_giveup_m` 6; for I17, `turn_pause_s` 0.5; for I18, `beacon_h_m` 3.0 with `wall_h_max` 3.0). For example: `f_chase` 0.9 (I1), `encounter_grace_s` 0.5 (I3), `symbol_giveup_m` 5 with `symbol_chase_m` 3.5 (I4), `flee_grace_s` 2 with `walk_speed` 3.0 and `symbol_giveup_m` 8 (I5), and `dt_max` 0.3 with `walk_speed` 4.0 (I11).

---

## Implementation Notes

*Derived from ADR-0012 §9 and GDD Formulas ("Load-time invariants"):*

- The default `OverworldConfig` passes `validate()` with zero errors.
- Build one fixture per invariant I1–I13 and I15–I18 (I14, `chase_visibility`, is covered separately by story 099) that breaks **only** that invariant; assert the returned `PackedStringArray` names that invariant's ID and no other.
- Use the GDD's own worked fixtures where it gives exact values: I15 `symbol_chase_m` 3.5 with `notice_path_cap_m` 4.5; I16 `notice_path_cap_m` 5 with `symbol_giveup_m` 6; I17 `turn_pause_s` 0.5; I18 `beacon_h_m` 3.0 with `wall_h_max` 3.0; I1 `f_chase` 0.9; I3 `encounter_grace_s` 0.5; I4 `symbol_giveup_m` 5 with `symbol_chase_m` 3.5; I5 `flee_grace_s` 2 with `walk_speed` 3.0 and `symbol_giveup_m` 8; I11 `dt_max` 0.3 with `walk_speed` 4.0.
- For the remaining invariants (I2, I6–I10, I12, I13) construct the narrowest single-field or paired-field break from each invariant's own inequality (Formulas, "Load-time invariants" table) and assert the same single-ID isolation.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- I14 (`chase_visibility`), which needs the presentation camera's footprint (story 099).
- The invariants' downstream behavioural guarantees (give-up timing, swept contact) — those are stories 100–102.

---

## Files

- `src/overworld/overworld_config.gd`
- `tests/unit/overworld/config_invariants_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/config_invariants_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: None within this epic (exercises `OverworldConfig` directly)
- Unlocks: `production/epics/overworld-exploration-encounters/story-099-chase-visibility-validates-at-every-aspect.md`, `production/epics/overworld-exploration-encounters/story-100-swept-contact-at-every-approach-angle.md`

## Completion Notes (2026-10-30)

- `OverworldConfig.validate(dt_max, stage_records)` checks I1–I13 and I15–I18. Each failure starts with its ID and names the knobs.
- New knobs, at the GDD defaults: `t_react`, `escape_max_s`, `cell_m`, `beacon_h_m`, `wall_h_max`, and the overworld/dungeon `D_min`/`D_max`. Also new: `t_escape(d0)`, and `DT_MAX_DEFAULT` standing in for Presentation's `dt_max`.
- I13 runs over the `occupation_stage` records (a kind missing at the higher stage counts as 0).
- `validate_maps` (CI) now runs it against the catalog's stage records.
- Test: `tests/unit/overworld/config_invariants_test.gd`. The invariants share knobs, and the GDD's own example values (I4 and I15) also break neighbours (I12, I15–I17). So the test has two parts:
  - One hand-worked narrow fixture per ID, which must produce exactly one error with that ID.
  - The GDD examples, each of which must name its ID.
- Not done: the boot-time call. GameRoot does not build an `OverworldConfig` from data yet.
- Mutations checked: I1's bound loosened, I16 losing its walk term, I13 disabled, and I8's strict `<` made `<=` each fail a test here.
