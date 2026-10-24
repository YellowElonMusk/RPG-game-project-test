# Story 013: `faction_bureaucratia` and `faction_megacorp` exist as alien Faction records whose shape, colour and `rule_id` equal the shipped identity

> **Epic**: Content Migration
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (Migration Step 2, "the two built Faction records"). Also ADR-0011: Faction Rule Modifiers (§4, "Faction → rule references use the generic reference pass") and ADR-0012: Overworld Exploration & Encounters (§3, `patrol_archetype_id`).
**ADR Decision Summary**: The two shipped factions become Faction records with ID-only references: `rule_id` names a `faction_rule` record, and asset fields hold asset IDs, never paths.
**ADR Version**: ADR-0001 2026-10-23 · ADR-0011 2026-10-22 · ADR-0012 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Records are `.tres` text files; load them in tests with `ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)`.

**Control Manifest Rules (this layer)**:
- Required: "One record = one `.tres` file at `data/[type_plural]/[id].tres`; the filename without extension must equal the record's `id`."
- Required: "Cross-references are `String` / `PackedStringArray` fields holding record IDs."
- Forbidden: "Never use `@export var x: OtherResourceType` for a cross-reference."
- Guardrail: none.

---

## Acceptance Criteria

*Migration criterion from ADR-0001 Migration Step 2, scoped to this story:*

- [ ] GIVEN `data/factions/faction_bureaucratia.tres` and `faction_megacorp.tres`, WHEN loaded, THEN each has `kind = alien`, `base_shape` = `square` / `wedge`, `signature_color` = `#D23A2E` / `#19C2D6` (the shipped `get_identity_color()`), `rule_id` = `rule_bureaucratia_permit` / `rule_megacorp_billing`, the display names "Bureaucratia" / "MegaCorp", `backup_icon_id` = `icon_faction_bureaucratia` / `icon_faction_megacorp`, and `patrol_archetype_id` = `patrol_compliance_clerk` / `""` (or `patrol_placeholder` for MegaCorp if `patrol_archetype_id` is in `FactionData.REQUIRED_FIELDS`, recorded in the Completion Notes).

---

## Implementation Notes

*Derived from ADR-0001 Migration Step 2, the draft's Q9 resolution and the QA gate (RC-3):*

- **Content is moved as-is and never retuned.** `base_shape` comes from the art bible §3 table (Bureaucratia "Square / rectangle", MegaCorp "Wedge / triangle"), and `signature_color` from the shipped code. Neither is new content.
- **Asset IDs (Q9).** `backup_icon_id` and `patrol_archetype_id` have no shipped values. The overworld GDD names Bureaucratia's patrol "Compliance Clerk"; MegaCorp has none. Never a `res://` path (TR-content-005; story 022 checks). If a Presentation validator (ADR-0005 `sprite_set_exists`) is registered and the assets don't exist, story 021 surfaces it, and the fix is a placeholder asset, never removing the validator.
- `rule_id` references records that story 017 authors. Land 013 and 017 in the same commit, or the reference pass fails in between (content-catalog story 014). This story's per-record test cases load each `.tres` directly with `CACHE_MODE_IGNORE`; the catalog-level pass is story 021.
- Rule 8 requires `signature_color`, `backup_icon_id`, `rule_id` and `patrol_archetype_id` only on alien factions; both are alien.
- **Expected values (RC-3).** Record-only values (`base_shape`, asset IDs, `rule_id`, `kind`) go in `tests/unit/battle/fixtures/migrated_records_expected.gd` (`class_name MigratedRecordsExpected`, constants only, **not** under story 009's gate). The identity colours are asserted against the frozen `CharacterizationExpected`. A record that disagrees with that fixture fails the test, so "moved as-is" is enforced by a test, not a review.
- Records go under `data/factions/<id>.tres` and reference their script under `src/data/records/` by path. Records are never written by code at runtime.
- The data-set round-trip test `tests/unit/battle/battle_migrated_records_test.gd` is shared across stories 013–019; each story adds only its own cases.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 017: the `faction_rule` records `rule_id` points to.
- Story 021: the catalog-level zero-error load.
- Story 022: the no-paths scan.
- Story 027: rules reading the identity colour from this record.

---

## Files

- `data/factions/faction_bureaucratia.tres`
- `data/factions/faction_megacorp.tres`
- `tests/unit/battle/fixtures/migrated_records_expected.gd` (faction block)
- `tests/unit/battle/battle_migrated_records_test.gd` (faction cases)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, revisions applied: asset IDs pinned, per-record loads with `CACHE_MODE_IGNORE`, `MigratedRecordsExpected` (RC-3)). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Faction fields.
  - Given: both `.tres` files, loaded with `ResourceLoader.load(path, "", CACHE_MODE_IGNORE)`.
  - Then: `id`, `kind == "alien"`, `base_shape` square/wedge, `display_name`, `signature_color` equal to the frozen identity colour (`is_equal_approx`), `rule_id`, and the asset IDs as pinned in `MigratedRecordsExpected`.
  - Edge cases: no value starts with `res://` (story 022 covers this in full).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Config/Data
**Required evidence**:
- Config/Data: smoke check pass (`production/qa/smoke-*.md`). Gate level: ADVISORY.
- Supporting: the faction cases in `tests/unit/battle/battle_migrated_records_test.gd` pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-002-load-one-of-each-type.md`, `production/epics/content-catalog/story-017-overworld-uniqueness-and-faction-rule.md`
- Unlocks: `production/epics/content-migration/story-015-author-bureaucratia-enemies.md`, `story-017-author-faction-rule-records.md`, `story-027-faction-rule-presentation-from-records.md`
