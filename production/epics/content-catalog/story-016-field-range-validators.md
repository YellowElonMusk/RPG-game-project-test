# Story 016: Registered range validators reject every F2 boundary outside its bound and accept it at the bound

> **Epic**: Content Catalog
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (as amended by ADR-0007 §7); ADR-0004: Content Boot Ordering (§4 `register_record_validator`, amended 2026-10-23); ADR-0012: Overworld Exploration & Encounters (§3 field bounds)
**ADR Decision Summary**: Field ranges are owned by the system whose GDD defines the field, never written as literals in `ContentCatalog`. Owners register pure per-record validators through `ContentBootstrap` → `register_record_validator()`. A validator returns `Array[Dictionary]` entries (`severity`, `field`, `message`, optional `related_locations`), and the catalog fills `record_id` and `location`.
**ADR Version**: ADR-0001 2026-10-23; ADR-0004 2026-10-23; ADR-0012 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `zone_rate` and `liberation_grumble_min` are floats. Boundary values such as 0.1 and 0.4 must compare inclusively without float drift: the test validator compares the authored value directly against the constant, and the fixture stores the exact literal.

**Control Manifest Rules (this layer)**:
- Required: "`register_record_validator(type, validator)` — `validator: func(record) -> Array[Dictionary]` returns structured entries (`severity`, `field`, `message`, optional `related_locations`) and must be pure (empty array = valid); a registration made after `load_all()` has started is rejected." "Numeric ranges (e.g. `max_hp` 1–999) are owned by Stats & Damage Resolution and checked by its validators..., registered through `ContentBootstrap`."
- Forbidden: range literals inside `ContentCatalog`; `src/data/` importing Core or Feature code.
- Guardrail: validators run once per record during Validating, never per frame.

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-26** One test per boundary: `stat_block.max_hp` 0 and 1000, `max_mp` −1 and 100, `attack`/`defense`/`speed` 0 (or −1 for `defense`) and 100, `Move.cost` −1, `reward.xp` −1 and 10000, `reward.money` −1 and 10000, `OccupationStage.stage` 0 and 4, `Map.base_stage` 0 and 4, a `stage_table` value 4, `Map.zone_rate` −0.01 and 1.01, `liberation_grumble_min` 0.09 and 0.41. Each produces an error naming the record and field. The matching minimum and maximum values each load.

---

## Implementation Notes

*Derived from ADR-0004 §4 (amended 2026-10-23), ADR-0001 as amended by ADR-0007 §7, GDD F2 and the QA gate:*

- **Scope (QA fix applied: re-scoped, not blocked).** The real bounds live in other epics' validators: `StatsValidators` bound to `StatsConfig` (ADR-0007 §7) and the Overworld's validators (ADR-0012). Neither exists yet. This story builds and proves the **mechanism**, including the structured-entry path, with test-double validators whose bounds are test constants equal to GDD F2. It proves every number in AC-26 against the mechanism. **AC-26 closes fully only when the Stats and Overworld epics re-run these boundary fixtures against their real validators**; record that hand-off in the Completion Notes and in those epics' stories. This story never writes a range literal into `src/`.
- **Mechanism (completing story 002's skeleton).** During Validating, after the generic checks, the catalog calls each validator registered for the record's type, in registration order, once per record. For each returned dictionary it sets `record_id` = the record's `id` and `location` = the record's location, keeps `severity`, `field`, `message` and `related_locations` (defaulting to `[]`), and appends it to the report. A non-`Array` return, or an entry without `severity` or `field`, becomes an error entry naming the validator's type, so a broken validator fails loudly. A registration while `state != UNLOADED` is rejected with `push_error()` and has no effect.
- **Test doubles** live in `tests/unit/content_data/helpers/f2_test_validators.gd`, with the GDD F2 bounds as named constants in that file (test fixture constants, allowed by the "No hardcoded data" exception for boundary tests).
- **Boundary list** (GDD F2; the QA report counted 22, the AC lists 24 invalid values):

| Field | Invalid (error) | Valid (loads) |
|---|---|---|
| `stat_block.max_hp` | 0, 1000 | 1, 999 |
| `stat_block.max_mp` | −1, 100 | 0, 99 |
| `stat_block.attack` | 0, 100 | 1, 99 |
| `stat_block.defense` | −1, 100 | 0, 99 |
| `stat_block.speed` | 0, 100 | 1, 99 |
| `Move.cost` | −1 | 0 (no maximum) |
| `reward.xp` | −1, 10000 | 0, 9999 |
| `reward.money` | −1, 10000 | 0, 9999 |
| `OccupationStage.stage` | 0, 4 | 1, 3 |
| `Map.base_stage` | 0, 4 | 1, 3 |
| `Map.stage_table` value | 4 | 1, 3 |
| `Map.zone_rate` | −0.01, 1.01 | 0, 1 |
| `OccupationStage.liberation_grumble_min` | 0.09, 0.41 | 0.1, 0.4 |

- The `field` for a sub-record value is the dotted path (`stat_block.max_hp`, `reward.xp`); for a `stage_table` entry it is `stage_table`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `StatsValidators` / `StatsConfig` and their bootstrap line: Stats & Damage Resolution's epic (ADR-0007 §7).
- Overworld validators (including `zone_rate == 0` on MVP maps and invariant I13): the Overworld epic (ADR-0012).
- Story 017: cross-record Overworld uniqueness rules.

---

## Files

- `src/data/content_catalog.gd` (validator invocation, entry completion, late-registration rejection)
- `tests/unit/content_data/helpers/f2_test_validators.gd`
- `tests/unit/content_data/fixtures/range_boundaries/<field>_<value>/` (one fixture per row value above; or one fixture directory per field holding one record per value, each with its own ID)
- `tests/unit/content_data/content_data_field_range_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS resolved: RC-D structured validators, boundary list, re-scope). The developer implements against these — do not invent new test cases during implementation.*

- **AC-26 / invalid values**: Each out-of-range value errors, naming record and field.
  - Given: the F2 test validators registered for `character`, `enemy`, `move`, `map` and `occupation_stage` before `load_all()`; one fixture record per invalid value in the table.
  - When: each is loaded into a fresh catalog.
  - Then: `FAILED`, and exactly one error entry with `record_id` = that record's ID and `field` = the dotted field name in the table.
  - Edge cases: `Move.cost` has no upper bound, so a very large cost (e.g. 100000) loads.
- **AC-26 / valid boundaries**: Each min and max value loads.
  - Given: one fixture record per valid value in the table.
  - When: loaded.
  - Then: `OK`, `READY`, and no entry names that record.
- **Mechanism checks** (same file):
  - A validator returning `[{severity = &"warning", field = "x", message = "m"}]` adds one warning entry with `record_id` and `location` filled in, and the catalog stays `READY`.
  - `register_record_validator()` called after a load has finished is rejected: the late validator never runs (its call counter stays 0).
  - A validator returning entries without `field` produces an error entry naming the validator's type.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content_data/content_data_field_range_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-015-structure-validation.md`
- Unlocks: `production/epics/content-catalog/story-017-overworld-uniqueness-and-faction-rule.md`
