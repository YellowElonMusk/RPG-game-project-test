# Story 010: A malformed ID is an error naming it; 64 characters loads, 65 does not

> **Epic**: Content Catalog
> **Status**: In Progress
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-23

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format
**ADR Decision Summary**: Every record has a permanent lowercase snake_case `id` with its type prefix, at most 64 characters, checked by the catalog's generic validation pass (GDD F1: `id_valid = (length(id) ≤ 64) ∧ matches(id, ^[a-z][a-z0-9_]*$) ∧ starts_with(id, type_prefix)`).
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Use `RegEx` compiled once (a constant pattern), not per record. Windows' filesystem is case-insensitive but case-preserving; see the fixture note below.

**Control Manifest Rules (this layer)**:
- Required: "Every record exports `id: String`." "The validation pass covers: ID format and uniqueness, filename = `id`, …"
- Forbidden: writing `ID_MAX_LENGTH` or `ID_PATTERN` as knobs. They are fixed constants (GDD Tuning Knobs, "Deliberately not knobs").
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-9** One test per defect: an ID with uppercase letters, one with a space, one without its type prefix, and one of 65 characters each produce an error whose `record_id` is the offending ID. An ID of exactly 64 characters loads.

---

## Implementation Notes

*Derived from GDD F1 and ADR-0001's validation pass:*

- Constants in `content_catalog.gd`: `ID_MAX_LENGTH := 64`, `ID_PATTERN := "^[a-z][a-z0-9_]*$"`, and the per-type prefix from story 002's type table.
- One F1 check gives one entry: `severity = &"error"`, `record_id = <the offending id>`, `field = "id"`. F1 is one boolean, so an ID with several defects still produces one entry.
- **Boundary arithmetic (fixed from the draft).** `char_` is 5 characters. The 64-character ID is `char_` + **59** lowercase letters and must load. The 65-character ID is `char_` + **60** letters and must error. This matches F1's own example ("`char_` followed by 60 letters (65 characters) → false").
- **Fixture filenames equal the bad IDs exactly** (e.g. `characters/char_Bad.tres`, `characters/char_bad id.tres`, `characters/bad_no_prefix.tres`), so the filename = `id` check passes and only the F1 error fires. Git and Windows preserve case, so `char_Bad.tres` is a valid name. If `ResourceLoader.list_directory()` turns out to alter the case or the space, filter the report on `field == "id"` instead of asserting a total count, and record that in the Completion Notes.
- Each defect fixture also holds the supporting records its Character needs (a human_nation faction for `nation_id`), so no reference error fires. Characters are a root type, so no unreferenced warning fires either.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 011: ID uniqueness.
- Story 013: aliases that collide with IDs.

---

## Files

- `src/data/content_catalog.gd` (F1 id-format check in `_load_one()`; `ID_MAX_LENGTH`, `ID_PATTERN` constants; RegEx compiled once)
- `tests/unit/content_data/fixtures/id_defects/` (uppercase, space, no_prefix, len_65, len_64: one character plus its human-nation faction each)
- `tests/unit/content_data/content_data_id_format_test.gd` (6 test functions) and its `.uid`

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fixes applied: 59/60-letter boundary; filename = bad ID). The developer implements against these — do not invent new test cases during implementation.*

- **AC-9**: Each ID defect gives exactly one error naming the ID; 64 characters loads.
  - Given: five fixtures, each with one Character (plus its faction):
    - `uppercase/`: `char_Bad`
    - `space/`: `char_bad id`
    - `no_prefix/`: `bad_no_prefix` (in `characters/`)
    - `len_65/`: `char_` + 60 × `a`
    - `len_64/`: `char_` + 59 × `a`
  - When: each is loaded into a fresh catalog.
  - Then: each of the first four returns `FAILED`, and its report holds exactly one error entry, with `record_id` equal to the fixture's ID and `field == "id"`. `len_64/` returns `OK`, `state == READY`, 0 error entries, and `get_record(&"character", <64-char id>)` is non-null.
  - Edge cases: assert `<64-char id>.length() == 64` and `<65-char id>.length() == 65` inside the test, so a fixture typo cannot pass silently. Optional extra: a leading digit (`char_` cannot start with one, but `9char_x` in `characters/` fails both pattern and prefix with one entry).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content_data/content_data_id_format_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-002-load-one-of-each-type.md`
- Unlocks: `production/epics/content-catalog/story-011-duplicate-id-one-error.md`, `production/epics/content-catalog/story-012-resolve-alias.md`, `production/epics/content-catalog/story-020-mixed-severity-report.md`, `production/epics/content-catalog/story-022-unparsable-file.md`, `production/epics/content-catalog/story-023-deterministic-report-order.md`
