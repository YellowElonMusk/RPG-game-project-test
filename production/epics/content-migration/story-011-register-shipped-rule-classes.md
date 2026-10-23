# Story 011: `bureaucratia_permit` and `megacorp_billing` are registered in `FactionRules.register_all()`, and each class validator accepts the shipped params and rejects a missing, wrong-typed, or unlisted-ID param with one error each

> **Epic**: Content Migration
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-factionrules-002` (secondary to the content TRs, which this enables)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: Faction Rule Modifiers (§4 registry and validators; §5 what moves to data; Validation Criteria: "Boot validation fails, with one error each"). Also ADR-0004: Content Boot Ordering — Registration Before Validation (§1 step 2).
**ADR Decision Summary**: A `faction_rule` record's `rule_class` resolves through an explicit `FactionRuleRegistry`, never reflection. Each class registers a pure validator that checks the record's params, texts and colours at boot.
**ADR Version**: ADR-0011 2026-10-22 · ADR-0004 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: ADR-0011 probed that `params` value types (`int | float | bool | String`) round-trip in `.tres`. The float `low_hp_threshold` 0.5 is exact in binary.

**Ownership**: Faction Rule Modifiers (content-catalog story 017 lists the real classes as out of scope). Drafted here because no epic for that system exists yet.

**Control Manifest Rules (this layer)**:
- Required: "Faction Rule registration: builds the `FactionRuleRegistry` (`FactionRules.register_all()`) and registers its rule-record validators."
- Forbidden: "Never resolve a faction's rule class by reflection (`ProjectSettings.get_global_class_list()`)."
- Forbidden: "Never add a cross-record validator phase."
- Guardrail: validators run once at boot.

---

## Acceptance Criteria

*Migration criterion from ADR-0011 §4/§5 and Validation Criteria, scoped to this story:*

- [ ] GIVEN the registry returned in `ContentBootstrap.run()`'s boot result, THEN `known_rule_classes()` contains both classes; a fixture `faction_rule` record of each class with the shipped params loads with no **error** entry naming it; and for each class a record with (a) `permit_rounds`/`bill_mp` missing, (b) that param typed as `String`, (c) an ID-valued param absent from `ref_ids`, and (d) a missing required `texts` key each produces exactly one error with `field` = that param or key path.

---

## Implementation Notes

*Derived from ADR-0011 §4/§5 and the QA gate (RC-4, RC-5):*

- Required params per class (Q5 flat role keys included):

  | Class | Required params (type) | ID-valued params (must be in `ref_ids`) |
  |---|---|---|
  | `bureaucratia_permit` | `permit_rounds` (int ≥ 0), `low_hp_threshold` (float 0–1) | `hunker_jab_move`, `focus_attack_move`, `late_fee_move`, `mass_audit_move`, `final_notice_move` |
  | `megacorp_billing` | `bill_mp` (int ≥ 0) | `laser_scan_move`, `upsell_move`, `layoffs_move`, `hostile_takeover_move`, and each `role.<enemy_id>` key's enemy ID |

- **Role map (Q5).** ADR-0011 §5 allows only `int | float | bool | String` param values, so MegaCorp's enemy → move role uses flat keys: `"role.enemy_security_drone": "laser_scan"`, `"role.enemy_middle_manager": "upsell"`, with both enemy IDs also in `ref_ids`. The boss branch keeps keying on `is_boss`. Confirm with technical-director at readiness.
- Required `texts` and `colors` keys are checked by the same validator (ADR-0011 §4: "checks the class's params, texts and colours"): Bureaucratia `banner_locked_one`, `banner_locked_other`, `banner_unlocked`, `tooltip_locked`, `tooltip_unlocked`, colour `banner_unlocked`; MegaCorp `banner`, `tooltip`, `note_suspended`. Placeholder brace balance is ADR-0013's `LocFieldsValidator`'s job; don't duplicate it, just require the keys.
- **Boot result (RC-5).** `ContentBootstrap.run(catalog, data_root := "res://data")` as in content-catalog story 002. ADR-0011 says `run()` returns the registry; the return-type annotation (`ContentBootResult` with `.registry`) is owed to technical-director in ADR-0004 Key Interfaces. Record the request in the Completion Notes. Tests use a fresh `ContentCatalogService.new()`.
- **Errors only (RC-4).** Fixture rule records are unreferenced and warn; assert on error entries only.
- The **factory** half of `register()` may return the shipped rule unconfigured until story 026 adds `_configure()`: the interim "in-code defaults" path ADR-0011 Step 3 allows. Say so in a `# TODO(story-026)` comment.
- Validators are pure: they look only at the record and their own constants ("A record validator must look only at its record and the boot-time registry").
- The validator's own bounds (`permit_rounds ≥ 0`, `low_hp_threshold` 0–1) are structural sanity checks owned by Faction Rule Modifiers, not balance ranges. They retune nothing.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `production/epics/content-catalog/story-017-overworld-uniqueness-and-faction-rule.md`: `FactionRuleRegistry` itself and `register_faction_rule_validator`.
- Story 017: the real `faction_rule` records.
- Story 026: `_configure()` and rules built from records.

---

## Files

- `src/battle/factions/faction_rules.gd` (`FactionRules.register_all(registry)`, two `register()` lines)
- `src/battle/factions/bureaucratia_rule_validator.gd`, `src/battle/factions/megacorp_rule_validator.gd` (pure static validators; or static functions on the rule classes if ADR-0011's implementer prefers)
- `tests/unit/battle/fixtures/rule_classes/…`
- `tests/unit/battle/battle_rule_class_registration_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, revisions applied: registry from the boot result (RC-5), errors only (RC-4), case (d) missing texts key). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Classes registered; validators accept shipped params and reject each defect once.
  - **Test: classes known.**
    - Then: `result.registry.known_rule_classes()` contains `&"bureaucratia_permit"` and `&"megacorp_billing"`.
  - **Test: shipped params pass.**
    - Given: a fixture rule per class with the params from story 017's table.
    - Then: there is no error entry naming it.
  - **Test: one error each.**
    - For each class: missing `permit_rounds`/`bill_mp`, the same param as `String`, an ID param missing from `ref_ids`, and a missing texts key.
    - Then: each gives exactly 1 error, with `field` equal to the path (e.g. `params.permit_rounds`, `params.role.enemy_middle_manager`, `texts.banner_unlocked`).
    - Edge cases: `permit_rounds = 0` passes and `-1` errors. `low_hp_threshold` 0.0 and 1.0 pass, and 1.01 errors.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_rule_class_registration_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-017-overworld-uniqueness-and-faction-rule.md`
- Unlocks: `production/epics/content-migration/story-017-author-faction-rule-records.md`, `story-026-faction-rule-decisions-from-records.md`
