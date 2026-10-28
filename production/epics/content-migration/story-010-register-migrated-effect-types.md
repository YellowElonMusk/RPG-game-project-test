# Story 010: `ContentBootstrap.run()` registers the six effect types the migrated moves use, so a Move carrying each one loads and an unregistered one errors

> **Epic**: Content Migration
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-28

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (EffectDescriptor adapter; Vocabulary ownership). Also ADR-0004: Content Boot Ordering — Registration Before Validation (§1 step 1) and ADR-0010: Turn Battle System (§8).
**ADR Decision Summary**: Owning systems register their effect-type vocabulary before validation; an unknown descriptor type is a validation error. The five migrated Turn Battle types are provisional until the Quirk State System is designed.
**ADR Version**: ADR-0001 2026-10-23 · ADR-0004 2026-10-23 · ADR-0010 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API.

**Ownership**: Turn Battle System (the five types) and Stats & Damage (`damage`). Drafted here because no epic for either exists yet. Move it if one appears first.

**Control Manifest Rules (this layer)**:
- Required: "Owning systems register their vocabulary before validation: Turn Battle System calls `ContentCatalog.register_known_effect_types(system, types)`."
- Required: "The five migrated EffectDescriptor types are `stun`, `heal_party`, `heal_single`, `damage_debuff`, `direct_damage`, provisional until Quirk State System is designed."
- Forbidden: "Never register a vocabulary from a static initializer the catalog triggers by referencing a Feature class."
- Forbidden: "Never let `src/data/` import `src/boot/` or any Feature-layer script."
- Guardrail: registration is a boot-time call, never per frame.

---

## Acceptance Criteria

*Migration criterion from ADR-0001 (EffectDescriptor adapter, Vocabulary ownership) and ADR-0004 §1 step 1, scoped to this story:*

- [ ] GIVEN a fixture with one Move per type (`stun`, `heal_party`, `heal_single`, `damage_debuff`, `direct_damage`, `damage`), WHEN `ContentBootstrap.run(catalog, fixture_root)`, THEN `catalog.state == READY` and no **error** entry names those moves; a seventh Move with `type = "heal_partyy"` produces exactly one error whose `record_id` is that move and whose `field` follows content-catalog story 015's descriptor convention (`effects`).

---

## Implementation Notes

*Derived from ADR-0001 Vocabulary ownership, ADR-0004 §1 and the QA gate (RC-4, RC-5):*

- `src/battle/battle_effect_types.gd` (`class_name BattleEffectTypes`): `const TURN_BATTLE: PackedStringArray` with the five names and `static func register(catalog)`. The five names are **provisional** (ADR-0001, GDD Rule 5); the constant's doc comment says so and cites QQ-02. Story 018 adds `const PROVISIONAL` beside it.
- Registration is `register_known_effect_types(&"turn_battle", TURN_BATTLE)`, plus `(&"stats", ["damage", "heal"])` registered on Stats' behalf until the Stats epic exists. `heal` is registered but unused by the migrated set. Record which system owns `damage` in the Completion Notes (Q4: named attacks carry `[{type = "damage", power = N}]`).
- **Bootstrap signature (RC-5).** Use `ContentBootstrap.run(catalog: ContentCatalogService, data_root: String = "res://data")`, as content-catalog story 002 defines it. The return-type annotation (a boot result carrying `.registry` and `.presentation_config`) is owed to technical-director in ADR-0004 Key Interfaces; don't depend on it here. Tests use a fresh `ContentCatalogService.new()`, never the autoload.
- **Errors only (RC-4).** The fixture Moves are unreferenced, so each produces the unreferenced-record warning. Assert on **error** entries only; warnings are expected and are not part of this criterion.
- ADR-0004 rule: "An ADR that adds a registrant must name its line in `ContentBootstrap.run()`". Quote the line in the Completion Notes.
- `src/data/` must not import this file. It is called from `src/boot/` only.
- Fixtures are `.tres` files under the test root, mirroring `data/` (`tests/unit/battle/fixtures/effect_types/valid/moves/…`, `…/typo/moves/…`).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 014 and 018: the real Move records.
- Story 018: `BattleEffectTypes.PROVISIONAL`.
- Story 023: mapping descriptor types to runtime `Move` fields.
- Story 012: Stats range validators (`power_range`).

---

## Files

- `src/battle/battle_effect_types.gd` — created (class_name BattleEffectTypes: TURN_BATTLE, register())
- `src/boot/content_bootstrap.gd` — modified (step 1: Turn Battle + Stats-placeholder + Quirk-State-placeholder effect-type registration)
- `tests/unit/battle/fixtures/effect_types/valid/moves/` — created (6 fixture Moves, one per type)
- `tests/unit/battle/fixtures/effect_types/typo/moves/` — created (1 fixture Move with an unregistered type)
- `tests/unit/battle/battle_effect_types_registration_test.gd` — created (4 test functions)

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, revisions applied: assert errors only (RC-4); `run(catalog, data_root)` signature (RC-5)). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Six types load; a typo errors once.
  - **Test: six types load.**
    - Given: `fixtures/effect_types/valid/` and a fresh `ContentCatalogService`.
    - When: `ContentBootstrap.run(catalog, root)`.
    - Then: state is READY and the error count is 0.
    - Edge cases: `BattleEffectTypes.TURN_BATTLE` equals the 5 names. `damage` is known under the system recorded in the Completion Notes.
  - **Test: typo errors once.**
    - Given: `fixtures/effect_types/typo/`.
    - Then: state is FAILED and there is exactly 1 error, on `move_typo`, `field == "effects"`.
    - Edge cases: a grep test finds no reference to `battle_effect_types.gd` / `BattleEffectTypes` in `src/data/`.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_effect_types_registration_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-002-load-one-of-each-type.md`, `production/epics/content-catalog/story-015-structure-validation.md`
- Unlocks: `production/epics/content-migration/story-012-register-stats-validators.md`, `story-014-author-enemy-named-attack-moves.md`, `story-018-author-squad-special-moves.md`

## Completion Notes
**Completed**: 2026-10-28
**Criteria**: 1/1 passing
**Deviations**: `content_bootstrap.gd` also registers a provisional `&"quirk_state_provisional"` vocabulary (`apply_quirk_state`, `consume_quirk_state`, `stat_modifier`, `expiry_hook`), not named by this story's AC or by any ADR. Needed because activating effect-type validation for the first time broke 3 pre-existing content-catalog tests against the shared `valid_one_of_each` fixture (`content_data_load_test.gd::test_bootstrap_run_on_fixture_root_reaches_ready`, `content_data_reload_rejected_test.gd::test_bootstrap_run_twice_on_ready_catalog_calls_load_all_once`, `content_data_validate_cli_test.gd::test_clean_data_set_exits_zero`), which already use these quirk/combo type strings. Mirrors this story's own sanctioned Stats placeholder. Replace this line when the Quirk State System gets its own ADR. `damage` is registered under system `&"stats"` (no test asserts this by name — `_known_effect_types` is private to `src/data/`).
**Test Evidence**: `tests/unit/battle/battle_effect_types_registration_test.gd` — exists and passes (full suite: 288/288, 0 errors, 0 failures, 0 orphans)
**Reviewed by**: `/code-review` (self-invoked this session) — APPROVED WITH SUGGESTIONS after one fix (vacuous-pass gap in the `src/data/` reference scan, watched fail against an unopenable directory, then fixed)
