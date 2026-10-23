# Story 004: A zero-record data set loads Ready with an empty list for every type

> **Epic**: Content Catalog
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format
**ADR Decision Summary**: The catalog's terminal state is decided by the error count alone (F3), and a type with zero records is valid. A system that needs at least one record of a type reports that itself.
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Confirm on 4.7.2 what `ResourceLoader.list_directory()` returns for an empty directory and for a path that does not exist: an empty array, or an empty array plus an engine error. Neither may become a validation error. Record the observed behaviour in the Completion Notes; story 030 re-checks it in an exported build.

**Control Manifest Rules (this layer)**:
- Required: "Validation runs over the complete record set before reporting." "The catalog loads once per session; `READY` is terminal."
- Forbidden: treating "no files found" as a load failure.
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-3** GIVEN a fixture with zero records of every type, WHEN it loads, THEN the state is Ready and `all_records(type)` returns an empty list for each type.

---

## Implementation Notes

*Derived from ADR-0001 (F3; Edge Cases "If a type has zero records") and the ADR-0001 amendment of 2026-10-23:*

- `error_count == 0` gives Ready (F3), and with zero records it is trivially 0. Validation must still run its full pass (over nothing) and transition `LOADING → VALIDATING → READY`.
- An empty or absent type directory under the data root yields zero records for that type, never an error entry.
- `all_records(type)` on a known type with zero records returns `[]` **and** sets `last_lookup_error = &""`. This is the "valid, empty" result, distinct from the unknown-type error in story 005.
- `load_all()` returns `OK`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: unknown-type `all_records` must be distinguishable from this empty result.

---

## Files

- `tests/unit/content_data/fixtures/empty_catalog/` (every type directory present and empty, each with a `.gdkeep` so it is committed)
- `tests/unit/content_data/fixtures/empty_catalog_absent/` (no type directories; a `.gdkeep` at the fixture root)
- `tests/unit/content_data/content_data_empty_catalog_test.gd`
- `src/data/content_catalog.gd` (only if a fix is needed for an absent directory)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23: ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-3 / T1**: Empty type directories load Ready.
  - Given: `fixtures/empty_catalog/` with every type subdirectory present and empty.
  - When: a fresh catalog runs `load_all(fixture_root)`.
  - Then: the return value is `OK`; `state == READY`; the report has 0 error entries; `all_records(t).size() == 0` for each of the 12 types, with `last_lookup_error == &""` after each call.
  - Edge cases: a `.gdkeep` file in a type directory is not a resource and is not listed.
- **AC-3 / T2**: Absent type directories load Ready.
  - Given: `fixtures/empty_catalog_absent/` with no type subdirectories at all.
  - When: loaded.
  - Then: the same results as T1, and no entry is raised for a missing directory.
  - Edge cases: if `list_directory()` on a missing path pushes an engine error, the test either expects it with the gdUnit4 error assertion or the catalog checks the path first. Either way the report stays empty.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content_data/content_data_empty_catalog_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-002-load-one-of-each-type.md`
- Unlocks: None
