# Story 018: The five squad specials exist as provisional Move records whose name, target type, cost and single EffectDescriptor equal the shipped `SquadSpecials` factories

> **Epic**: Content Migration
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-005`, `TR-content-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (Migration Step 4: squad-special records "marked **provisional** (Rule 5)"; EffectDescriptor adapter)
**ADR Decision Summary**: The squad specials become Move records carrying one of the five provisional Turn Battle descriptor types. They migrate after the stable data on purpose, so risk lands on the smaller, later part of the migration.
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Load records in tests with `ResourceLoader.load(path, "", CACHE_MODE_IGNORE)`.

**Control Manifest Rules (this layer)**:
- Required: "The five migrated EffectDescriptor types are `stun`, `heal_party`, `heal_single`, `damage_debuff`, `direct_damage`, provisional until Quirk State System is designed."
- Required: "EffectDescriptors are stored as plain `Array[Dictionary]`."
- Forbidden: "Never put logic in a record class."
- Guardrail: none.

---

## Acceptance Criteria

*Migration criterion from ADR-0001 Migration Step 4, scoped to this story:*

- [ ] GIVEN the five `data/moves/` records, WHEN loaded, THEN: `move_speak_to_the_manager` single_enemy, cost 4, `[{type "stun"}]`; `move_family_meal` self, cost 5, `[{type "heal_party", power 5}]`; `move_appetizer` single_ally, cost 3, `[{type "heal_single", power 10}]`; `move_viral_stunt` single_enemy, cost 3, `[{type "damage_debuff", rounds 2}]`; `move_home_run` single_enemy, cost 4, `[{type "direct_damage", power 18}]`. Each display name is the shipped one ("Home Run", not the prototype's "Baguette Home Run"); each record's descriptor `type` is listed in `BattleEffectTypes.PROVISIONAL` (doc-commented with QQ-02); and no record carries a `provisional` field.

---

## Implementation Notes

*Derived from ADR-0001 Migration Step 4 and the QA gate:*

- **Content is moved as-is and never retuned.**
- **How "provisional" is marked.** The record class has no `provisional` field, and adding one would be a schema change (Rule 8). Instead add `const PROVISIONAL: PackedStringArray` to `src/battle/battle_effect_types.gd` (story 010's file) listing the five types, with a doc comment citing QQ-02.
- **They are migrated after the stable data on purpose** (ADR-0001: "so that risk lands on the smaller, later part of the migration").
- STUN and DAMAGE_DEBUFF carry no `power` key (today `power` 0). The adapter (story 028) sets `power = 0` when the descriptor has none. Don't author `power = 0`: the Stats `power_range` (1–100) would reject it if it ever covered these types.
- The Viral Stunt key is `rounds` (pinned here; story 028 reads the same key).
- **Expected values (RC-3).** Display names and costs assert against the frozen `CharacterizationExpected`; the literal descriptors and target-type strings go in `MigratedRecordsExpected` (not under story 009's gate).
- These five Moves are unreferenced while story 019 is Blocked (no Character references them), so each produces the unreferenced-record warning. Story 021 lists them as expected warnings.
- Records go under `data/moves/<id>.tres`, reference their script under `src/data/records/` by path, and are never written by code at runtime. Cases go in the shared `battle_migrated_records_test.gd`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 014: the enemy named-attack records.
- Story 019: Character records that would reference these.
- Story 028: the specials adapter.

---

## Files

- `data/moves/move_speak_to_the_manager.tres`, `move_family_meal.tres`, `move_appetizer.tres`, `move_viral_stunt.tres`, `move_home_run.tres`
- `src/battle/battle_effect_types.gd` (adds `const PROVISIONAL`)
- `tests/unit/battle/fixtures/migrated_records_expected.gd` (specials block)
- `tests/unit/battle/battle_migrated_records_test.gd` (special cases)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, revision applied: "marked provisional" replaced by `BattleEffectTypes.PROVISIONAL`; `rounds` key pinned). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Five special records.
  - **Test: five records.**
    - Given: the five `.tres` files.
    - Then: target type, cost and effects equal the pinned literal descriptors; display names and costs equal the frozen fixture.
    - Edge cases: stun and damage_debuff carry no `power` key. "Home Run" is not "Baguette Home Run".
  - **Test: provisional.**
    - Then: each record's descriptor `type` is in `BattleEffectTypes.PROVISIONAL`; no record has a `provisional` property.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Config/Data
**Required evidence**:
- Config/Data: smoke check pass (`production/qa/smoke-*.md`). Gate level: ADVISORY.
- Supporting: the special cases in `tests/unit/battle/battle_migrated_records_test.gd` pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-002-characterize-squad-specials.md`, `story-010-register-migrated-effect-types.md`; `production/epics/content-catalog/story-015-structure-validation.md`
- Unlocks: `production/epics/content-migration/story-019-author-squad-character-records.md`, `story-021-migrated-set-validates-clean.md`, `story-028-squad-specials-adapter.md`
