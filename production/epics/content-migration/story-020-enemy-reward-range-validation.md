# Story 020: The enemy validator rejects `reward.xp` and `reward.money` at −1 and 10000 and accepts 0 and 9999, and the five migrated enemies pass

> **Epic**: Content Migration
> **Status**: Blocked — BLOCKED: needs `StatsValidators` (via story 012; the Stats epic is not yet created)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-stats-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Stats & Damage Resolution (§7: "`Enemy.reward` ranges (0–9999) are added to the enemy validator with the enemy-record migration"; §8, F9 out of scope)
**ADR Decision Summary**: Once enemies are records, the Stats-owned enemy validator also checks `reward.xp` and `reward.money` against ranges read from `StatsConfig`.
**ADR Version**: ADR-0007 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required (*Core*): "Every tuning number comes from `StatsConfig`, loaded only through `StatsConfig.load_or_default()`. Tests compute expected values from the config, and each formula test also runs with a non-default config."
- Required: "Numeric ranges … are never written as literals in `ContentCatalog`."
- Guardrail: validators run once at boot.

---

## Acceptance Criteria

*Migration criterion from ADR-0007 §7 (GDD AC-31), scoped to this story:*

- [ ] GIVEN `StatsValidators` registered through `ContentBootstrap.run()`, WHEN fixture enemies with `reward.xp` −1, `reward.money` 10000 (GDD AC-31), `reward.xp` 10000 and `reward.money` −1 load, THEN each produces exactly one error with `field` = `reward.xp` / `reward.money` naming the record; fixtures at 0 and 9999 for each load clean; the five `data/enemies/` records produce no `reward` entry; and story 021's test stays green with the new check.

---

## Implementation Notes

*Derived from ADR-0007 §7:*

- This closes TR-stats-005's "⚠️ partial" (EPIC.md). Update `docs/architecture/requirements-traceability.md` at `/story-done`.
- The bounds come from `StatsConfig` (`reward_xp_range`, `reward_money_range` as `Vector2i(0, 9999)` fields with GDD defaults), never literals in the validator. ADR-0007's Key Interfaces `StatsConfig` listing doesn't have the reward fields yet; adding them is the annotation ADR-0007 §7 anticipates. Flag it for technical-director.
- Add the checks to the enemy path of `validate_stat_block`, or a sibling `validate_enemy_reward`, registered for `enemy` only.
- The test lives under `tests/unit/stats/` because the code under test is Stats'. Its files are in `src/battle/stats/`, Stats' directory, so coordinate with the Stats epic (coordination rule 5). If the Stats epic exists by then, this story moves there and the content-migration side keeps only the "five migrated enemies pass" clause (folded into story 021).
- The real runtime reward (F9 `RewardTotals`) stays out of scope.
- `ContentBootstrap.run(catalog, data_root := "res://data")` as in content-catalog story 002, on a fresh `ContentCatalogService.new()`; assert error entries only (fixture enemies are unreferenced and warn).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 012: registering `StatsValidators` for `stat_block`, `cost` and `power`.
- Story 021: the full migrated-set validation.
- F9 `RewardTotals` (runtime rewards): Stats/economy epics.

---

## Files

- `src/battle/stats/stats_validators.gd` (the `reward` checks on the enemy path)
- `src/battle/stats/stats_config.gd` (`reward_xp_range`, `reward_money_range`)
- `tests/unit/battle/fixtures/reward_ranges/…`
- `tests/unit/stats/stats_reward_validation_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Reward boundaries.
  - Given: fixture enemies at xp −1, money 10000, xp 10000 and money −1.
  - When: `ContentBootstrap.run(fresh, fixture_root)`.
  - Then: each gives exactly 1 error on `reward.xp` / `reward.money`; 0 and 9999 for each load clean.
  - Edge cases: the five `data/enemies/` records give no `reward` entry. A non-default `StatsConfig` (`reward_xp_range` 0–100) makes 101 an error, which proves the bounds come from config.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/stats/stats_reward_validation_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-012-register-stats-validators.md`, `story-015-author-bureaucratia-enemies.md`
- Unlocks: `production/epics/content-migration/story-021-migrated-set-validates-clean.md` (its Done)
