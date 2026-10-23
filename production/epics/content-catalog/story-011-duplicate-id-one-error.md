# Story 011: Two records sharing one ID produce exactly one error, located at the first file, with the other in `related_locations`

> **Epic**: Content Catalog
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-24

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format
**ADR Decision Summary**: IDs are unique across the whole catalog. Two records sharing an ID is an error naming both source locations; there is no override or "last one wins" rule. The GDD's Entry shape (F3) carries the second location in `related_locations`.
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: none.

**Control Manifest Rules (this layer)**:
- Required: "The validation pass covers: ID format and uniqueness, filename = `id`, reference resolution, cycle detection, numeric ranges, unknown fields, parse failures and Resource-typed exports."
- Forbidden: "last one wins", or one error per offending file.
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-10** GIVEN two records with the same ID in two different files, WHEN validating, THEN exactly one error is reported, its `location` is the first file in report order and its `related_locations` holds the other.

---

## Implementation Notes

*Derived from GDD F3 "Entry shape" and "Report order", and ADR-0001 Rule 2:*

- The shape is pinned by the GDD (no longer "decide here"): one entry with `severity = &"error"`, `record_id = <duplicate id>`, `field = "id"`, `location` = the location that sorts first (normalised `res://` path, case-sensitive string order, then `record_index`), and `related_locations` = every other location holding that ID, in the same sorted order.
- Uniqueness is catalog-wide, across types: IDs carry their type prefix, so two different types rarely collide, but the check does not assume it.
- **Building the fixture.** Filename = `id` means the two files must share a name, so put them in two different subdirectories of one type directory (discovery recurses per subdirectory), e.g. `characters/a/char_dup.tres` and `characters/b/char_dup.tres`. If filename = `id` is ever made path-aware, record that here.
- Stories 013, 017, 023 and 028 reuse this shape for every "names both" error.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 013: Rule 2's other duplicate form, "one is an alias of another" (an alias equal to a live ID), and the same alias declared twice.
- Story 023: the global report sort.

---

## Files

- `src/data/content_catalog.gd` (`_id_locations` catalog-wide id → paths map, filled in `_load_one()`; `_check_duplicate_ids()` runs first in the Validating pass)
- `tests/unit/content_data/content_data_duplicate_id_test.gd` (5 test functions) and its `.uid`
- `tests/unit/content_data/fixtures/duplicate_id_two_files/` (2 characters sharing `char_dup` in `a/` and `b/`, 1 faction)
- `tests/unit/content_data/fixtures/duplicate_id_three_files/` (3 characters in `a/`, `b/`, `c/`, 1 faction; for the three-file edge case)

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS resolved by the GDD Entry shape). The developer implements against these — do not invent new test cases during implementation.*

- **AC-10**: One error for a duplicate ID, with both locations.
  - Given: `fixtures/duplicate_id_two_files/` holds `characters/a/char_dup.tres` and `characters/b/char_dup.tres` (both valid Characters with `id = "char_dup"`, plus their faction).
  - When: loaded into a fresh catalog.
  - Then: the return value is `FAILED`. Exactly one error entry has `record_id == "char_dup"`; its `field == "id"`; its `location.file_path` is the `res://` path of `characters/a/char_dup.tres` (the one that sorts first); its `related_locations` has size 1 and holds the `b/` path.
  - Edge cases: three files sharing one ID give one entry with two `related_locations`, sorted. The result is the same with story 003's reversed discovery order, so the "first" location never depends on listing order.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content_data/content_data_duplicate_id_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (see Completion Notes)

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-010-id-format-validation.md`
- Unlocks: `production/epics/content-catalog/story-013-alias-shadowing-and-double-declaration.md`, `story-017-overworld-uniqueness-and-faction-rule.md`, `story-023-deterministic-report-order.md` (all under `production/epics/content-catalog/`)

---

## Completion Notes
**Completed**: 2026-10-24
**Criteria**: 1/1 passing (AC-10). None deferred.
**Deviations**: None. The check runs first in the Validating pass, after every type has loaded, so the reported first location depends on sorted paths, never discovery order. Duplicated ids are also visited in sorted order, so several duplicates report in a stable order. `_id_locations` holds plain Arrays because nested typed collections do not parse on Godot 4.7.2; the check copies them into typed `Array[String]` locals. A second fixture, `duplicate_id_three_files/`, was added for the three-file QA edge case and is listed under Files. A cross-type collision is handled by the same code but not tested; the F1 prefix rule makes it unreachable while no type prefix starts another.
**Test Evidence**: `tests/unit/content_data/content_data_duplicate_id_test.gd` (5 functions); suite 61/61, 0 orphans, exit 0 on Godot 4.7.2. Watched fail (gdUnit `-c` so every test runs): disabling the check failed all 5 tests; removing the path sort failed only the reversed-order test. Commit f1ffd41.
**Reviewed by**: lead-programmer (LP-CODE-REVIEW APPROVE); QL-TEST-COVERAGE ADEQUATE
