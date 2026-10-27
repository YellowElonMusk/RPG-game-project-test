# Story 017: Two new-game-entry maps, a duplicate (faction, stage) pair and a human `patrol_archetype_id` each error; a registered `faction_rule` loads

> **Epic**: Content Catalog
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-27

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-001`, `TR-content-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters (§3); ADR-0011: Faction Rule Modifiers (§4 `FactionRuleRegistry`, §5 `FactionRuleData`); ADR-0004: Content Boot Ordering (§1 step 2, as amended by ADR-0011)
**ADR Decision Summary**: At most one Map sets `new_game_entry`, no two OccupationStage records share a `(faction_id, stage)` pair, and `patrol_archetype_id` is alien-only. A `faction_rule` record's `rule_class` resolves through `FactionRuleRegistry`, built by `ContentBootstrap.run()`, which registers one record validator for `faction_rule` (`rule_class` in `known_rule_classes()` and `validator_for(rule_class)` passes). There is no reflection.
**ADR Version**: ADR-0012 2026-10-23; ADR-0011 2026-10-22; ADR-0004 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: none.

**Control Manifest Rules (this layer)**:
- Required: "`map` (`map_`), `encounter` (`enc_`) and `occupation_stage` (`ostage_`) are catalog record types, and `faction` gains `patrol_archetype_id`." "Faction Rule registration: builds the `FactionRuleRegistry` (`FactionRules.register_all()`) and registers its rule-record validators" (ContentBootstrap step 2). "An ADR that adds a registrant must name its line in `ContentBootstrap.run()`."
- Forbidden: "Never resolve a faction's rule class by reflection." `src/data/` importing `src/battle/` or `src/boot/`.
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-27** GIVEN two Map records that both set `new_game_entry`, THEN an error names both. GIVEN two OccupationStage records with the same `(faction_id, stage)`, THEN an error names both. GIVEN a human_nation faction with `patrol_archetype_id` set, THEN an error names the record and field. GIVEN a `faction_rule` record `rule_ok` whose `rule_class` is registered, THEN it passes F1 and loads.

---

## Implementation Notes

*Derived from ADR-0012 §3, ADR-0011 §4 (Boot) and the QA gate (fix applied: register through the ADR-0011 path; depend on 011):*

- **Cross-record uniqueness lives in the catalog's generic pass**, not in a registered validator: registered validators are per-record and pure (ADR-0004 §4) and cannot see a second record.
  - Two Maps with `new_game_entry` set: one entry, `record_id` = the Map that sorts first, `field = "new_game_entry"`, `related_locations` = every other such Map (story 011's shape).
  - Two OccupationStage records with one `(faction_id, stage)`: one entry, same shape, `field = "stage"`. Record the field choice in the Completion Notes.
- **`patrol_archetype_id` on a `human_nation`** is the same alien-only-field check as story 018 (`signature_color`, `backup_icon_id`, `rule_id`, `patrol_archetype_id`). One entry, `field = "patrol_archetype_id"`.
- **Faction-rule registration (ADR-0011 §4 Boot).** `ContentBootstrap.run()` step 2: create a `FactionRuleRegistry`, call `FactionRules.register_all(registry)`, then register one record validator for `&"faction_rule"`. Factor the validator registration into `static func register_faction_rule_validator(catalog, registry)` on `ContentBootstrap`, so `run()` and this story's test go through **the same code path**. The registered validator returns `[{severity = &"error", field = "rule_class", …}]` when `rule_class` is not in `known_rule_classes()`, otherwise it returns the result of `validator_for(rule_class).call(record)`.
- **`FactionRuleRegistry` and `FactionRules` may not exist yet.** They belong to Faction Rule Modifiers (`src/battle/factions/faction_rule_registry.gd`, `faction_rules.gd`, ADR-0011 Key Interfaces), and no epic for that system exists yet. If they are absent: create `FactionRuleRegistry` with exactly the ADR-0011 §4 interface (`register`, `known_rule_classes`, `validator_for`; `create()` may log and return `null` until the battle epic builds factories), and leave `FactionRules.register_all()` out of `run()` behind a `# TODO(ADR-0011)` line. Flag it at `/story-readiness`. The test builds its own registry with a stub rule class.
- **Fixture for `rule_ok`.** FactionRule is not a root type, so an unreferenced `rule_ok` would raise a warning naming it. The fixture adds an alien faction with `rule_id = "rule_ok"`, and a Map with `faction_id` = that faction (Map is a root type), so nothing in the fixture warns.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 018: `signature_color` and `base_shape` faction rules.
- The real rule classes (`bureaucratia_permit`, `megacorp_billing`) and their parameter validators: Faction Rule Modifiers.
- Overworld's own per-record validators: the Overworld epic.

---

## Files

- `src/data/content_catalog.gd` — modified (new `_check_new_game_entry_uniqueness()`, `_check_occupation_stage_uniqueness()`, `_check_alien_only_fields()` and `_ALIEN_ONLY_FIELDS`, run during Validating before the registered validators)
- `src/boot/content_bootstrap.gd` — modified (new `register_faction_rule_validator()`; the step-2 call in `run()` stays behind `TODO(ADR-0011)`)
- `src/battle/factions/faction_rule_registry.gd` — created (`register`, `known_rule_classes`, `validator_for`, `create` stub)
- `tests/unit/content_data/fixtures/overworld_and_rules/` — created (14 fixtures in 5 case directories, plus `two_new_game_entry/none_set/`)
- `tests/unit/content_data/content_data_overworld_rules_test.gd` — created (6 test functions)

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fixes applied). The developer implements against these — do not invent new test cases during implementation.*

- **AC-27 / T1**: GIVEN `map_a` and `map_b` both with `new_game_entry` set, WHEN loaded, THEN `FAILED` and exactly one error entry with `field == "new_game_entry"`, `record_id == "map_a"`, and `related_locations` holding `map_b`'s path.
- **AC-27 / T2**: GIVEN `ostage_x_1` and `ostage_x_1b` both with `faction_id = "faction_alien_x"` and `stage = 1`, WHEN loaded, THEN exactly one error entry with `field == "stage"` naming the first in `location` and the other in `related_locations`.
- **AC-27 / T3**: GIVEN `faction_human_y` (`kind: human_nation`) with `patrol_archetype_id` set, WHEN loaded, THEN exactly one error entry with `record_id == "faction_human_y"` and `field == "patrol_archetype_id"`.
- **AC-27 / T4**: GIVEN a `FactionRuleRegistry` with stub rule class `&"test_rule_ok"` (validator returns `[]`), registered on the catalog through `ContentBootstrap.register_faction_rule_validator()`, and `rule_ok` (`rule_` prefix, `rule_class = &"test_rule_ok"`) referenced by an alien faction that a Map references, WHEN loaded, THEN `OK`, `READY`, no entry has `record_id == "rule_ok"`, and `get_record(&"faction_rule", "rule_ok")` is non-null.
- Edge cases: the same `rule_ok` with `rule_class = &"not_registered"` (`unregistered_rule/`) gives one error with `field == "rule_class"` (ADR-0011 Verification). Two Maps with no `new_game_entry` at all is valid.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content_data/content_data_overworld_rules_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-011-duplicate-id-one-error.md`, `production/epics/content-catalog/story-015-structure-validation.md`, `production/epics/content-catalog/story-016-field-range-validators.md`
- Unlocks: None

---

## Completion Notes
**Completed**: 2026-10-27
**Criteria**: 1/1 passing (AC-27)
**Deviations**: Advisory only — (1) `ContentBootstrap.run()` does not call `register_faction_rule_validator()` yet, held behind `# TODO(ADR-0011)` per this story's own Implementation Notes, until the Faction Rule Modifiers epic builds `FactionRules`; (2) once wired, the `valid_one_of_each` fixture's `rule_class = "delay_rule"` will need replacing with a real registered class; (3) open design question for game-designer — should the `(faction_id, stage)` uniqueness key resolve faction aliases (today it uses the raw id)? The `(faction_id, stage)` violation's field is `"stage"`, as specified.
**Test Evidence**: `tests/unit/content_data/content_data_overworld_rules_test.gd` — 7/7 passing; full `tests/unit/content_data` suite 172/172, 0 errors/failures/orphans
**Reviewed by**: `/code-review` (first pass: CHANGES REQUIRED — `FactionRuleRegistry` didn't match ADR-0011 §4's interface, and no test proved a rule validator's own error reached the report; both fixed and re-verified by parse check + full suite before close)
