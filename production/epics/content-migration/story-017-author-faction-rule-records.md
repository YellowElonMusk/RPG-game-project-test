# Story 017: `rule_bureaucratia_permit` and `rule_megacorp_billing` exist as `faction_rule` records whose params, `ref_ids`, texts and colours reproduce the shipped rules

> **Epic**: Content Migration
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-005`, `TR-factionrules-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: Faction Rule Modifiers (§5, record type and "What moves to data"; Migration Step 4). Also ADR-0013: Localization (§4, `texts` in `LOC_FIELDS`, contexts `<rule_id>.texts.<key>`).
**ADR Decision Summary**: Each shipped rule's tuning, named-attack choices, player-visible text and colours move to a `faction_rule` record; ID-valued params are resolved through `ref_ids` by the generic reference pass, and the `rule_class` resolves through `FactionRuleRegistry`.
**ADR Version**: ADR-0011 2026-10-22 · ADR-0013 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `String.format(Dictionary)` fills `{key}` placeholders; long-standing API. `params` value types round-trip in `.tres` (probed by ADR-0011).

**Control Manifest Rules (this layer)**:
- Required: "`Faction.rule_id` is an ordinary reference to a `faction_rule` record, checked by the generic reference pass, and the record's `rule_class` resolves through `FactionRuleRegistry`."
- Required: "Every string-typed record export is listed in exactly one of the record script's `LOC_FIELDS` or `NON_LOC_FIELDS`…; every `LOC_FIELDS` value has balanced `{placeholder}` braces."
- Forbidden: "Never add a cross-record validator phase" (ID-valued params are resolved through `ref_ids`).
- Guardrail: none.

---

## Acceptance Criteria

*Migration criterion from ADR-0011 §5 and Migration Step 4, scoped to this story:*

- [ ] GIVEN `data/faction_rules/rule_bureaucratia_permit.tres` and `rule_megacorp_billing.tres`, WHEN `ContentBootstrap.run()` loads them with stories 013–016's records present, THEN each passes its class validator (story 011) and the reference pass with no error naming it; its `rule_class`, `params` (including `role.*` keys), `ref_ids` (as a set), `texts` keys and `colors` equal the pinned table below; and filling `banner_locked_other` with `{rounds_left: 3}` and `{rounds_left: 2}`, `banner_locked_one` with `{rounds_left: 1}`, and MegaCorp `banner`/`tooltip` with `{bill_mp: 1}` reproduces `CharacterizationExpected`'s story 007 strings byte-exact.

---

## Implementation Notes

*Derived from ADR-0011 §5, the draft's Q5/Q6 resolutions and the QA gate (RC-3):*

- **Pinned contents** (content moved as-is, never retuned):

  | | `rule_bureaucratia_permit` | `rule_megacorp_billing` |
  |---|---|---|
  | `rule_class` | `&"bureaucratia_permit"` | `&"megacorp_billing"` |
  | `params` | `permit_rounds` 3, `low_hp_threshold` 0.5, `hunker_jab_move` "move_pen_jab", `focus_attack_move` "move_red_tape", `late_fee_move` "move_late_fee", `mass_audit_move` "move_mass_audit", `final_notice_move` "move_final_notice" | `bill_mp` 1, `laser_scan_move` "move_laser_scan", `upsell_move` "move_upsell", `layoffs_move` "move_layoffs", `hostile_takeover_move` "move_hostile_takeover", `role.enemy_security_drone` "laser_scan", `role.enemy_middle_manager` "upsell" (Q5) |
  | `ref_ids` | the five move IDs + `enemy_clerk`, `enemy_supervisor` | the four move IDs + `enemy_security_drone`, `enemy_middle_manager`, `enemy_ceo` |
  | `texts` | `banner_locked_one` / `banner_locked_other` ("…It arrives in {rounds_left} round." / "…rounds."; Q6), `banner_unlocked`, `tooltip_locked`, `tooltip_unlocked` | `banner`, `tooltip` (both with `{bill_mp}`), `note_suspended` |
  | `colors` | `banner_unlocked` "#b07a12" | none |

- **Placeholder name.** The shipped placeholder is `rounds_left = PERMIT_ROUNDS - round_number + 1`. ADR-0011 §5's example uses `{unlock_round}`, a different quantity. Keep the shipped meaning (`rounds_left`), because the pinned text says "arrives in 3 rounds" in round 1. Note the divergence for technical-director to annotate.
- **Two banner keys (Q6).** One template can't reproduce both "3 rounds" and "1 round"; the rule picks `banner_locked_one`/`_other` by count (story 027). The `tr_n()` alternative waits on ADR-0013's helper.
- Copy each string from the shipped code, including the em dashes and "PERMIT GRANTED — All-out war!", and never retype it. The template-fill check against story 007's pins is the safety net.
- The identity colours live on the Faction record (story 013), not here. The rule reads them through the faction (ADR-0011 §1).
- The neutral fallback rule's sentences stay in code (`tr("…", &"rule.fallback.banner")`, ADR-0011 §1). Not migrated.
- **Expected values (RC-3).** Params, `ref_ids` and template keys go in `MigratedRecordsExpected` (not under story 009's gate); the filled strings and colour assert against the frozen `CharacterizationExpected`.
- `ContentBootstrap.run(catalog, data_root := "res://data")` as in content-catalog story 002, on a fresh `ContentCatalogService.new()`. Land with story 013 in one commit (`Faction.rule_id` dangles otherwise).
- Records go under `data/faction_rules/<id>.tres`, reference their script under `src/data/records/` by path, and are never written by code at runtime.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 011: the class validators.
- Story 026: rules configured from these records.
- Story 027: presentation read from these records.

---

## Files

- `data/faction_rules/rule_bureaucratia_permit.tres`, `data/faction_rules/rule_megacorp_billing.tres`
- `tests/unit/battle/fixtures/migrated_records_expected.gd` (rule block)
- `tests/unit/battle/battle_migrated_records_test.gd` (rule cases, including the template-fill check)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, revisions applied: `MigratedRecordsExpected` (RC-3), concrete fill values per round). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Rule records load, match the table and reproduce the pinned strings.
  - **Test: rule records load.**
    - Given: stories 013–016's records present.
    - When: `ContentBootstrap.run(fresh, "res://data")`.
    - Then: no error names either rule.
  - **Test: contents.**
    - Then: `rule_class`, `params` (including `role.*` keys), `ref_ids` (as a set) and `colors` equal the expected values.
  - **Test: template fill.**
    - When: filled as in the criterion.
    - Then: the results equal the 007 pins, compared as bytes.
    - Edge cases: `banner_unlocked` contains "PERMIT GRANTED — All-out war!" exactly. Brace balance passes `LocFieldsValidator` (if registered).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Config/Data
**Required evidence**:
- Config/Data: smoke check pass (`production/qa/smoke-*.md`). Gate level: ADVISORY.
- Supporting: the rule cases in `tests/unit/battle/battle_migrated_records_test.gd` pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-006-characterize-faction-rule-decisions.md`, `story-007-characterize-faction-rule-presentation.md`, `story-011-register-shipped-rule-classes.md`, `story-013-author-faction-records.md`, `story-014-author-enemy-named-attack-moves.md`, `story-015-author-bureaucratia-enemies.md`
- Unlocks: `production/epics/content-migration/story-021-migrated-set-validates-clean.md`, `story-026-faction-rule-decisions-from-records.md`, `story-027-faction-rule-presentation-from-records.md`
