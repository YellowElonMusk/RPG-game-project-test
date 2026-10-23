# Story 009: One error anywhere fails the whole catalog, even for records that were valid themselves

> **Epic**: Content Catalog
> **Status**: In Progress
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-23

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-002`, `TR-content-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (F3; States; Amendment 2026-10-23)
**ADR Decision Summary**: `validation_outcome = Failed if error_count > 0, else Ready`. A single error fails the whole catalog, including records that were valid themselves. No content is served from a Failed catalog: every lookup returns its empty value with `last_lookup_error = &"not_ready"`.
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: none.

**Control Manifest Rules (this layer)**:
- Required: "Validation runs over the complete record set before reporting, every problem collected."
- Forbidden: "Never fail fast on the first bad record." Never serve the valid records of a Failed catalog.
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-8** GIVEN a fixture with exactly one error, WHEN it loads, THEN the state is Failed and every lookup returns an error, including for records that were themselves valid.

---

## Implementation Notes

*Derived from ADR-0001 F3 and the Amendment 2026-10-23:*

- The end of Validating counts `error`-severity entries. Any error gives `FAILED`, and `load_all()` returns `FAILED`. Warnings never affect the outcome (F3).
- In `FAILED`, all four lookups behave as in story 007: empty value, `push_error()`, `last_lookup_error = &"not_ready"`. There is no partial Ready.
- **Fixture error choice.** This story depends only on 002 and 007, so its one error must be a rule story 002 already checks. Use a **filename that does not equal the record's `id`** (e.g. `moves/move_wrong_name.tres` whose `id` is `move_real_name`). Later stories may reuse the fixture.
- Keep the fixture's valid records otherwise clean: five Characters (root type, exempt from the unreferenced warning) each with a resolvable `nation_id`, plus their human_nation faction and their moves.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 019: warnings never fail the catalog.
- Story 020: errors and warnings in one report.
- Story 026: Game State's reaction to `FAILED` (`game-state-scene-flow`).

---

## Files

- `tests/unit/content_data/content_data_failed_state_test.gd` (6 test functions) and its `.uid`
- `tests/unit/content_data/fixtures/one_error_rest_valid/` — reused unchanged (built in story 008 to this story's spec)
- `src/data/content_catalog.gd` — unchanged: the existing guards already refuse lookups on a Failed catalog

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS resolved by the `last_lookup_error` channel). The developer implements against these — do not invent new test cases during implementation.*

- **AC-8**: One error fails the catalog, and no lookup serves a valid record.
  - Given: `fixtures/one_error_rest_valid/` holds five valid Characters (including `char_valid_one`), their faction and moves, and one Move whose filename differs from its `id`.
  - When: a fresh catalog runs `load_all(fixture_root)`.
  - Then: the return value is `FAILED`; `state == FAILED`; the report holds exactly 1 error entry. Each lookup on a record that is valid by itself is refused with `last_lookup_error == &"not_ready"`: `get_record(&"character", "char_valid_one")` is `null`; `has_record(&"character", "char_valid_one")` is `false`; `all_records(&"character")` is empty; `resolve_alias("char_valid_one")` is `""`.
  - Edge cases: the error entry has `severity == &"error"` and `location.file_path` equal to the mismatched file's `res://` path.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content_data/content_data_failed_state_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-007-lookups-error-before-ready.md`
- Unlocks: `production/epics/content-catalog/story-019-warning-cases.md`, `story-020-mixed-severity-report.md`, `story-023-deterministic-report-order.md`, `story-026-failed-catalog-blocks-boot.md` (all under `production/epics/content-catalog/`)
