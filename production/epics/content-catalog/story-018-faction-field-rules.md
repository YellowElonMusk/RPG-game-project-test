# Story 018: An alien-only field on a human nation, and a `base_shape` that does not match `kind`, each error

> **Epic**: Content Catalog
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-27

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-001`, `TR-content-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (Rule 8 validation pass); ADR-0012: Overworld Exploration & Encounters (§3 adds `patrol_archetype_id` to the alien-only list)
**ADR Decision Summary**: The generic validation pass enforces the art bible's faction rules: `signature_color`, `backup_icon_id`, `rule_id` and `patrol_archetype_id` appear only on `alien` factions, and `base_shape` matches `kind` (`organic` for `human_nation`; `square` | `circle` | `wedge` | `star` for `alien`).
**ADR Version**: ADR-0001 2026-10-23; ADR-0012 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: none.

**Control Manifest Rules (this layer)**:
- Required: "The validation pass covers: ID format and uniqueness, filename = `id`, reference resolution, cycle detection, numeric ranges, unknown fields, parse failures and Resource-typed exports" (the faction rules sit under Rule 8's generic pass).
- Forbidden: faction-specific code paths keyed on faction IDs.
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-17** One test each: `signature_color` on a `human_nation`, and a `base_shape` that does not match `kind`. Each produces an error.

---

## Implementation Notes

*Derived from GDD Rule 8 and Edge Cases ("Faction rules"):*

- Keep the alien-only field list as one constant: `[&"signature_color", &"backup_icon_id", &"rule_id", &"patrol_archetype_id"]`. For a `human_nation`, each non-empty field in the list is one error entry, `field` = that field. Story 017 reuses the same constant for `patrol_archetype_id`.
- Keep the shape table as one constant: `human_nation → [organic]`, `alien → [square, circle, wedge, star]`. A mismatch is one entry with `field = "base_shape"`.
- An unknown `kind` value is a structure error (story 015's enum check), not a shape error.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 019: two aliens sharing a colour or shape (warnings).
- Story 014: `rule_id` resolving to a `faction_rule` record.

---

## Files

- `src/data/content_catalog.gd` — modified (`_ALIEN_ONLY_FIELDS` extended to all four alien-only fields; new `_SHAPES_BY_KIND` and `_check_faction_shapes()`)
- `tests/unit/content_data/fixtures/faction_rules/` — created (`human_signature_color/`, `alien_organic_shape/`, `human_square_shape/`, plus `human_two_alien_fields/` and `unknown_kind/` from the /code-review suggestions)
- `tests/unit/content_data/content_data_faction_fields_test.gd` — created (6 test functions)

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23: ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-17 / T1**: GIVEN `faction_human_x` (`kind: human_nation`, `base_shape: organic`, `signature_color: "#ff0000"`), WHEN loaded, THEN `state == FAILED` and exactly one error with `record_id == "faction_human_x"` and `field == "signature_color"`.
- **AC-17 / T2**: GIVEN `faction_alien_x` (`kind: alien`, `base_shape: "organic"`), WHEN loaded, THEN exactly one error with `record_id == "faction_alien_x"` and `field == "base_shape"`.
- **AC-17 / T3 (optional)**: a `human_nation` with `base_shape: "square"` errors the same way as T2.
- Edge cases: count only `severity == &"error"` entries (Faction is not a root type, so an unreferenced faction may also warn). A valid alien faction with all four alien-only fields set gives no error.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content_data/content_data_faction_fields_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-002-load-one-of-each-type.md`
- Unlocks: `production/epics/content-catalog/story-019-warning-cases.md`, `production/epics/content-catalog/story-023-deterministic-report-order.md`

---

## Completion Notes
**Completed**: 2026-10-27
**Criteria**: 1/1 passing (AC-17)
**Deviations**: Advisory only — (1) an empty `base_shape` is not flagged, since only `display_name` is required on a Faction today and ~20 existing fixtures leave `base_shape` empty; game-designer should decide whether `base_shape` becomes required. (2) no `kind` enum check exists anywhere in the codebase (the story assumed one from story 015); an unrecognized `kind` causes no shape error today.
**Test Evidence**: `tests/unit/content_data/content_data_faction_fields_test.gd` — 6/6 passing; full `tests/unit/content_data` suite 178/178, 0 errors/failures/orphans
**Reviewed by**: `/code-review` (APPROVED WITH SUGGESTIONS; both suggestions — a two-field human_nation test and an unknown-kind test — applied and re-verified before close)
