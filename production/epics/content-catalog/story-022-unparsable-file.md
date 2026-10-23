# Story 022: An unparsable file is one error naming it, and validation still reports the other files' errors

> **Epic**: Content Catalog
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format ("Validation mechanism" step 3)
**ADR Decision Summary**: `ResourceLoader.load(path)` returns `null` on a file that does not parse, and writes to the engine log on its own. The catalog checks for `null`, records its own validation error naming the file path, and keeps loading the rest. It never aborts early.
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Loading a corrupt `.tres` pushes an engine error before `null` is returned. Confirm whether the pinned gdUnit4 version fails a test on engine errors; if it does, expect the error explicitly with gdUnit4's error assertion.

**Control Manifest Rules (this layer)**:
- Required: "Check `ResourceLoader.load(path)` for `null`, record a validation error naming the file, and keep loading the rest."
- Forbidden: "Never fail fast on the first bad record."
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-16** GIVEN one data file that does not parse alongside valid files, WHEN loading, THEN there is one error naming that file, the state is Failed, and errors in the other files are still reported.

---

## Implementation Notes

*Derived from ADR-0001 "Validation mechanism" step 3 and GDD Edge Cases:*

- A `null` load gives one entry: `severity = &"error"`, `record_id = ""` (no ID could be read), `field = ""`, `location.file_path` = the file's normalised `res://` path, `record_index = 0`.
- No record from that file enters the catalog. Its raw-text scan (story 015) is skipped too, so it produces no second entry.
- Loading continues, and every later validation phase runs over the rest of the set.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 015: files that parse but carry unknown or invalid fields.

---

## Files

- `src/data/content_catalog.gd` (only if story 002's `null` check needs a fix)
- `tests/unit/content_data/fixtures/unparsable_file/` (one `.tres` with a corrupt `[resource]` header, three valid records, one record with ID `Char_Bad`)
- `tests/unit/content_data/content_data_unparsable_file_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23: ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-16 / T1**: One parse error, and the other file's error still reported.
  - Given: `fixtures/unparsable_file/` (one `.tres` with a corrupt `[resource]` header, three valid records, and one record with ID `Char_Bad` in `characters/Char_Bad.tres`).
  - When: loaded into a fresh catalog.
  - Then:
    - exactly one entry has `location.file_path` equal to the corrupt file's `res://` path, with an empty `record_id`
    - one error has `record_id == "Char_Bad"`
    - `state == FAILED`
    - no record from the corrupt file is retrievable
  - Edge cases: the engine error pushed by `ResourceLoader.load` on the corrupt file is expected explicitly, or shown not to fail the test.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content_data/content_data_unparsable_file_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-002-load-one-of-each-type.md`, `production/epics/content-catalog/story-010-id-format-validation.md` (the `Char_Bad` error is an F1 error)
- Unlocks: None
