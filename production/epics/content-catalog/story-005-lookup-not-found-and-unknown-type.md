# Story 005: A missing ID returns not-found, and an unknown type returns an error, not an empty list

> **Epic**: Content Catalog
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-23

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (Key Interfaces, Amendment 2026-10-23)
**ADR Decision Summary**: Every lookup has one error channel. A failing lookup returns the type's empty value, calls `push_error()`, and sets `ContentCatalog.last_lookup_error` to `&"not_ready"`, `&"unknown_type"` or `&"missing_id"` (`&""` on success). Tests assert on `last_lookup_error`, so the three causes can be told apart.
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `push_error()` writes to the engine log. Confirm how the pinned gdUnit4 version treats engine errors pushed during a test (some versions report them as failures). Use the gdUnit4 error assertion, or the documented way to expect them, so the test stays green when the behaviour is correct.

**Control Manifest Rules (this layer)**:
- Required: "Lookup API names are `get_record(type, id)`, `has_record(type, id)`, `all_records(type)` (sorted by `id`) and `resolve_alias(id)`."
- Forbidden: "Never name lookups `get()`, `exists()` or `all()`." Never invent a fallback record (GDD Edge Cases).
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-4** GIVEN a Ready catalog, WHEN `get_record` is called with a missing ID, THEN it returns a not-found result and no record. WHEN `all_records` is called with an unknown type, THEN it returns an error, not an empty list.

---

## Implementation Notes

*Derived from ADR-0001 Amendment 2026-10-23 (one error channel for lookups):*

- `get_record(known_type, missing_id)` returns `null`, calls `push_error()` naming the type and ID, and sets `last_lookup_error = &"missing_id"`. Save/Load relies on this path; it must never crash and never return a default or partial record.
- `all_records(unknown_type)` returns `[]`, calls `push_error()`, and sets `last_lookup_error = &"unknown_type"`. The empty return is allowed only because `last_lookup_error` distinguishes it from story 004's valid empty type (`&""`). A typo in a type name must never look like "no records yet".
- Apply the same discipline to `get_record(unknown_type, id)` (`&"unknown_type"`) and `has_record` (`false` + the cause).
- Reset `last_lookup_error` to `&""` at the start of every lookup, so a stale value never leaks from a previous call.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007 and story 009: `&"not_ready"` outside Ready.
- Story 012: `resolve_alias` for a non-alias ID.

---

## Files

- `tests/unit/content_data/content_data_lookup_errors_test.gd` (6 test functions, AC-4; reuses `fixtures/valid_one_of_each/`)
- `src/data/content_catalog.gd` — unchanged: story 002's error channel already met the contract

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS resolved by the ADR-0001 amendment). The developer implements against these — do not invent new test cases during implementation.*

- **AC-4**: Missing ID and unknown type give two distinguishable error outcomes.
  - Given: a Ready catalog loaded from `fixtures/valid_one_of_each/`.
  - When: (a) `get_record(&"character", "char_does_not_exist")`; (b) `all_records(&"charcter")` (a typo); (c) `all_records(&"item")`, a known type, for comparison.
  - Then: (a) returns `null` and `last_lookup_error == &"missing_id"`; (b) returns an empty array and `last_lookup_error == &"unknown_type"`; (c) returns the fixture's Item and `last_lookup_error == &""`. The outcomes of (a) and (b) differ.
  - Edge cases: `has_record(&"character", "char_does_not_exist")` is `false` with `&"missing_id"`. `get_record(&"charcter", "char_x")` gives `&"unknown_type"`. A successful lookup right after a failed one resets `last_lookup_error` to `&""`. The catalog stays `READY` throughout.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content_data/content_data_lookup_errors_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (see Completion Notes)

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-002-load-one-of-each-type.md`
- Unlocks: None

---

## Completion Notes
**Completed**: 2026-10-23
**Criteria**: 1/1 passing (AC-4). None deferred.
**Deviations**: Advisory: the GDD's AC-4 prose says an unknown type "returns an error, not an empty list"; the ADR-0001 2026-10-23 amendment, which this story implements, returns `[]` with `last_lookup_error = &"unknown_type"` and a `push_error()`. The GDD wording should be synced by its owner. No production code changed: story 002's channel already met the contract. The Engine Notes question is answered: gdUnit4 6.2.2 does not fail a test on `push_error()`, so no error-expectation wrapper was needed.
**Test Evidence**: `tests/unit/content_data/content_data_lookup_errors_test.gd` (6 functions); suite 33/33, 0 orphans, exit 0 on Godot 4.7.2. Commit 1156b0b.
**Reviewed by**: lead-programmer (LP-CODE-REVIEW APPROVE); QL-TEST-COVERAGE ADEQUATE; `/code-review` APPROVED
