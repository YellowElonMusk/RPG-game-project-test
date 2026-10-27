# Story 023: A fixture triggering five rules gives five errors, in the same order on every run

> **Epic**: Content Catalog
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-27

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (the report format itself is pinned in GDD F3, "Entry shape" and "Report order")
**ADR Decision Summary**: Validation produces structured entries in a deterministic order that does not depend on filesystem listing order or the OS. The GDD pins the sort key `(location.file_path, location.record_index, field, severity)`, with an empty `field` first and paths normalised to `res://` form, compared case-sensitively.
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Use a custom comparator with `Array.sort_custom()`. Godot's sort is not documented as stable, so the key must fully order every pair of entries that can differ. Add `record_id` and then `message` as final tiebreaks, and record that in the Completion Notes.

**Control Manifest Rules (this layer)**:
- Required: "Validation entries are structured (severity, record_id, field, location) in a deterministic order; error screen lists the first `ERROR_SCREEN_CAP`; log holds all" (TR-content-008).
- Forbidden: emitting entries in discovery order.
- Guardrail: one sort, at the end of Validating.

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-20** GIVEN a fixture triggering 5 different rules (malformed ID, duplicate ID, missing reference, unknown field, faction mismatch), WHEN validating, THEN the report has 5 errors, and their order is identical across repeated runs.

---

## Implementation Notes

*Derived from GDD F3 "Report order":*

- At the end of Validating, normalise every `location.file_path` (and every `related_locations` path) to `res://` with forward slashes, then sort the whole report ascending by `(file_path, record_index, field, severity)`, where an empty `field` sorts first (plain string order already puts `""` first). A multi-location entry sorts by its `location`, which story 011 already set to the first location.
- Severity order: compare the severity names as strings (`&"error"` < `&"warning"`), so on the same file and field an error comes before a warning.
- Use story 003's `discovery_order_transform` seam to perturb discovery order between runs.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 024: turning the report into text.

---

## Files

- `src/data/content_catalog.gd` — modified (`_sort_report()`, `_report_entry_less_than()`, `_normalize_path()`; one sort at the end of Validating)
- `tests/unit/content_data/fixtures/five_rule_violations/` — created (malformed ID, duplicate ID, missing reference, unknown field, faction signature_color mismatch)
- `tests/unit/content_data/content_data_report_order_test.gd` — created (3 test functions)

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23: ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-20 / T1**: Five rules give five errors.
  - Given: `fixtures/five_rule_violations/` (a malformed ID, a duplicate ID across two files, a missing reference, an unknown field, and a human_nation with `signature_color`), each in an isolated record that nothing else references.
  - When: loaded into a fresh catalog.
  - Then: `state == FAILED` and the error count is exactly 5.
- **AC-20 / T2**: The order is identical across runs and follows the F3 key.
  - Given: the same fixture loaded into two fresh catalogs, the second with reversed discovery order (story 003's seam).
  - When: the error entries are projected to `(file_path, record_index, field, severity)`.
  - Then: the two sequences are equal, and sorted ascending by the F3 key, with an empty `field` first.
  - Edge cases: warnings in the fixture (the human faction is non-root and unreferenced) are allowed; the error count and the projection order are filtered on `severity == &"error"`. A third run in the same test process gives the same sequence.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content_data/content_data_report_order_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-003-all-records-sorted-by-id.md`, `story-009-one-error-fails-catalog.md`, `story-010-id-format-validation.md`, `story-011-duplicate-id-one-error.md`, `story-014-reference-validation.md`, `story-015-structure-validation.md`, `story-018-faction-field-rules.md` (all under `production/epics/content-catalog/`)
- Unlocks: `production/epics/content-catalog/story-024-error-screen-text.md`

---

## Completion Notes
**Completed**: 2026-10-27
**Criteria**: 1/1 passing (AC-20)
**Deviations**: Advisory only — the sort key adds `record_id` and `message` as final tiebreaks beyond GDD F3's four-component key, as the story's own Engine Notes asked, since `Array.sort_custom()` is not documented as stable on 4.7.2 and the four-component key alone cannot order every possible pair of entries.
**Test Evidence**: `tests/unit/content_data/content_data_report_order_test.gd` — 3/3 passing; full test tree 196/196, 0 errors/failures/orphans
**Reviewed by**: `/code-review` (first pass: APPROVED WITH SUGGESTIONS — added a test for the sort rules the main fixture couldn't reach: empty field first, error before warning, record_id/message tiebreaks, path normalisation; applied and re-verified before close)
