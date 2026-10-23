# Story 012: `ContentBootstrap.run()` registers `StatsValidators` bound to `StatsConfig` for `character`, `enemy` and `move`, so an out-of-range shipped-shape value errors at boot

> **Epic**: Content Migration
> **Status**: Blocked — BLOCKED: needs `src/battle/stats/stats_validators.gd` and `stats_config.gd` (ADR-0007 Migration Step 1; the Stats epic is not yet created)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-stats-005`, `TR-content-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Stats & Damage Resolution (§7; Migration Step 5). Also ADR-0004: Content Boot Ordering — Registration Before Validation (§1 step 3) and ADR-0001: Content Data Definitions Storage & Loading Format (as amended by ADR-0007 §7).
**ADR Decision Summary**: Numeric ranges are owned by Stats & Damage Resolution and checked by `StatsValidators` with `StatsConfig` bound, registered through `ContentBootstrap`; they are never literals in the catalog. ADR-0007 Step 5 lands this registration "with ADR-0001's migration".
**ADR Version**: ADR-0007 2026-10-22 · ADR-0004 2026-10-23 · ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `Callable.bind()` binds the config to the static validator; long-standing API.

**Ownership**: ADR-0007 Step 5 puts the registration in this migration. The validators themselves are the Stats epic's.

**Control Manifest Rules (this layer)**:
- Required: "Numeric ranges (e.g. `max_hp` 1–999) are owned by Stats & Damage Resolution and checked by its validators (`StatsValidators.*`, with `StatsConfig` bound), registered through `ContentBootstrap`. They are never written as literals in `ContentCatalog`."
- Forbidden (*Core*): "`src/data/` never imports `src/battle/stats/` (validators are bound in `ContentBootstrap`)."
- Guardrail: validators run once at boot.

---

## Acceptance Criteria

*Migration criterion from ADR-0007 §7 / Migration Step 5, scoped to this story:*

- [ ] GIVEN `ContentBootstrap.run()` on a fixture holding an enemy with `stat_block.max_hp = 1000`, a move with `cost = -1` and a `damage` effect with `power = 101`, THEN exactly three errors name those records and fields (`stat_block.max_hp`, `cost`, `effects`), and the same fixture with in-range values loads READY; and story 021's test stays green with the new registrant.

---

## Implementation Notes

*Derived from ADR-0007 §7 / Step 5 and the QA gate:*

- Three `register_record_validator` lines in `src/boot/content_bootstrap.gd`, each with `StatsConfig.load_or_default(...)` bound. `src/data/` imports nothing from `src/battle/stats/`; the binding happens in `src/boot/`.
- **Depends on story 010** (QA finding): without the `damage` type registered, the fixture's `damage` effect is an unknown type and produces a fourth error.
- Content-catalog story 016 proved the mechanism with test doubles and noted AC-26 closes fully only when the real validators re-run its boundaries. Re-run 016's boundary fixtures for `stat_block` and `Move.cost` against the real validators here, and record the hand-off as closed in 016's Completion Notes. `reward.*` boundaries are story 020.
- Run once with a non-default `StatsConfig` (`max_hp_range` 1–500), so `max_hp = 600` errors. That proves the bounds aren't literals (TR-content-011).
- `ContentBootstrap.run(catalog, data_root := "res://data")` as in content-catalog story 002 (return-type annotation owed to technical-director, ADR-0004). Tests use a fresh `ContentCatalogService.new()`; assert on error entries (fixture records are unreferenced and warn).
- ADR-0007 §7's `power_range` covers only `damage`/`heal`, so `direct_damage` (18), `heal_party` (5) and `heal_single` (10) are not range-checked (Q4). All three are inside 1–100 anyway. Flag it for the Stats epic; do not widen it here.
- When this lands, re-run story 021's test with the new registrant; it must stay green.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The Stats epic: `StatsValidators` and `StatsConfig` themselves.
- Story 020: the `reward.*` ranges.
- Story 021: the full migrated-set validation.

---

## Files

- `src/boot/content_bootstrap.gd` (three `register_record_validator` lines with `StatsConfig` bound)
- `tests/unit/battle/fixtures/stats_registration/…`
- `tests/unit/battle/battle_stats_validator_registration_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, revision applied: dependency on story 010). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Three range errors at boot; in-range twin loads.
  - **Test: three range errors.**
    - Given: an enemy with `max_hp 1000`, a move with `cost -1`, and a `damage` effect with power 101.
    - When: `ContentBootstrap.run(fresh_catalog, fixture_root)`.
    - Then: exactly 3 errors, on (`stat_block.max_hp`, `cost`, `effects`), each naming its record.
    - Edge cases: the in-range twin is READY. Re-run content-catalog 016's boundary fixtures (1/999/0 and 1000/−1) against the real validators. Run once with a non-default `StatsConfig` (`max_hp_range` 1–500), so 600 errors.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_stats_validator_registration_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-010-register-migrated-effect-types.md`; `production/epics/content-catalog/story-016-field-range-validators.md`; the Stats epic's `StatsValidators` story (not yet created; path TBD)
- Unlocks: `production/epics/content-migration/story-020-enemy-reward-range-validation.md`, `story-021-migrated-set-validates-clean.md`
