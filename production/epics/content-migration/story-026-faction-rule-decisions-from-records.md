# Story 026: Both rules take their tuning and named attacks from their `faction_rule` record through `FactionRuleRegistry.create()`, MegaCorp picks moves by `record_id`, and the Step 0 suite passes unchanged

> **Epic**: Content Migration
> **Status**: Blocked — BLOCKED: needs ADR-0011 Migration Step 2 (`EnemyAction`, typed `choose_enemy_action()` return), which has no epic yet. Unblock by running that step first or folding it in with technical-director's agreement.
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-factionrules-002`, `TR-turnbattle-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: Faction Rule Modifiers (§2 stateless, configured once; §4 `create()` does no lookups; §5 identity by record; Migration Step 4). Also ADR-0001: Content Data Definitions Storage & Loading Format (Migration Step 3: "enemy-AI action selection … read from `ContentCatalog`").
**ADR Decision Summary**: Rules are stateless objects configured once from their faction and `faction_rule` records by the registry factory. Tuning, named attacks and MegaCorp's role map come from params; AI keys on `record_id`, never `display_name`.
**ADR Version**: ADR-0011 2026-10-22 · ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: 4.7: every non-void override must `return` on every path (hard parse error, probed). That applies to any new override on the rule subclasses.

**Control Manifest Rules (this layer)**:
- Required: "Enemy AI keys behaviour off the record `id`, never `display_name`."
- Required (Feature, ADR-0011): rules hold immutable configuration only; draw randomness only from `rng`; must not declare numeric tuning `const`s (enforced by 030/031/035).
- Forbidden: "Never resolve a faction's rule class by reflection."
- Guardrail: configuration runs once per battle build, never per decision.

---

## Acceptance Criteria

*Migration criterion from ADR-0011 §2/§4/§5 and Migration Step 4, scoped to this story:*

- [ ] GIVEN `registry.create(faction, rule)` for each faction record and its rule record, WHEN the configured rules run, THEN `permit_rounds`, `low_hp_threshold` and `bill_mp` come from `params`; every named attack comes from the move ID its param names (through `MoveAdapter`); MegaCorp's non-boss move comes from `role.<record_id>`; story 009's gate passes (006 and 008 green, unchanged); AND a fixture `rule_bureaucratia_permit` with `permit_rounds = 2` makes `specials_allowed(3) == true`, and a MegaCorp fixture with `role.enemy_security_drone = "upsell"` makes the Drone emit Upsell; AND a snapshot of every script property (`get_property_list()` values with `PROPERTY_USAGE_SCRIPT_VARIABLE`) taken after `_configure()` is unchanged after 50 seeded decision calls; AND a grep finds no `display_name` in the decision methods of `bureaucratia.gd`/`megacorp.gd`.

---

## Implementation Notes

*Derived from ADR-0011 §2/§4/§5 and the QA gate (RC-8):*

- **Data vs leftover constant (RC-8).** Story 006 alone can't tell a correct read of 3 from a leftover constant 3. The non-default fixtures (`permit_rounds = 2`, the swapped Drone role) are what prove the numbers come from data; they are in the criterion, not optional.
- **Statelessness** (ADR-0011 §2): the rule may hold the configured `Move`s it built in `_configure()` (immutable config), but never a counter or a remembered target. The property-snapshot test plus identical outputs across repeated calls with the RNG reseeded prove it (ADR-0011 Validation Criteria).
- Rules are configured from records **passed in** by the registry factory (`create()` does no lookups; the caller does). They don't read the catalog at decision time. That replaces story 023's interim autoload read.
- `_configure(faction: FactionData, rule: FactionRuleData)` on each subclass; `static func from_data()` on `FactionRule` per ADR-0011 Key Interfaces; the factories in `faction_rules.gd` call `_configure` (remove story 011's `# TODO(story-026)`).
- Role map keys are flat (`role.<enemy_id>`, Q5); the boss branch keeps keying on `is_boss`.
- Callers that construct rules with `.new()` (`chapter_flow.gd` lines 100–106 and the demos) still get an unconfigured rule until story 034 switches them. Keep `.new()` working during the interim (in-code defaults from 011's TODO path), pin one interim case, and record which callers still use it.
- **Seam edits:** `rule(id)` builds through the registry from records; `enemy_turn()` reads `EnemyAction.move`/`.target` (ADR-0011 Step 2's return type).
- **Closing condition:** story 009's gate passes, the Step 0 suite green and its files' hashes unchanged; editing a characterization test or the frozen fixture is never the fix. Re-run in a fresh process.
- `ContentBootstrap.run(catalog, data_root := "res://data")` as in content-catalog story 002; the registry is reached through its boot result (return-type annotation owed to technical-director, ADR-0004).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- ADR-0011 Migration Step 2 (`EnemyAction`): not yet in any epic (the blocker).
- Story 027: presentation from records.
- Story 029: `BattleFactory` doing the faction → rule lookup.
- Stories 030/031: deleting the constants.

---

## Files

- `src/battle/factions/bureaucratia.gd`, `src/battle/factions/megacorp.gd` (`_configure(faction, rule)`, reading params; built moves held as immutable config)
- `src/battle/factions/faction_rules.gd` (factories call `_configure`; remove 011's TODO)
- `src/battle/factions/faction_rule.gd` (`static func from_data()`)
- `tests/unit/battle/helpers/battle_content_seam.gd` (seam edits)
- `tests/unit/battle/fixtures/rule_configure/…` (non-default `faction_rule` fixtures)
- `tests/unit/battle/battle_faction_rule_configure_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, revisions applied: non-default fixtures, property-snapshot statelessness check and `display_name` grep in the criterion (RC-8)). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Rules configured from records decide identically and read their values from data.
  - **Test: params read.**
    - Given: a fixture `rule_bureaucratia_permit` with `permit_rounds = 2`; a MegaCorp fixture with `role.enemy_security_drone = "upsell"`.
    - Then: `specials_allowed(3) == true`; the Drone emits Upsell.
  - **Test: stateless.**
    - Given: a configured rule and a property snapshot after `_configure()`.
    - When: 50 seeded decision calls.
    - Then: the snapshot is equal; output repeated with the RNG reseeded is identical.
  - **Test: no display_name.**
    - Then: a grep finds no `display_name` in the two rules' decision methods.
  - **Test: 009 gate.**
    - Then: 006 and 008 are green, hashes unchanged.
    - Edge cases: `.new()` callers still get a working default rule until 034 (one interim case pinned).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_faction_rule_configure_test.gd` — must exist and pass, and story 009's gate passes. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-009-characterization-regression-gate.md`, `story-011-register-shipped-rule-classes.md`, `story-017-author-faction-rule-records.md`, `story-023-move-record-adapter.md`, `story-024-bureaucratia-roster-adapter.md`; ADR-0011 Migration Step 2 (no story path yet)
- Unlocks: `production/epics/content-migration/story-027-faction-rule-presentation-from-records.md`, `story-029-battle-factory-reads-enemy-records.md`, `story-030-delete-bureaucratia-constants.md`, `story-033-delete-is-manager.md`, `story-034-delete-roster-factories.md`
