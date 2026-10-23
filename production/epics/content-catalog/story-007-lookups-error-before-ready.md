# Story 007: Any lookup during Unloaded, Loading or Validating returns an error

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

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (States; Amendment 2026-10-23); ADR-0004: Content Boot Ordering (§3, §4)
**ADR Decision Summary**: Lookups in any state other than Ready return an error, never partial data. The error channel is `last_lookup_error = &"not_ready"` with the type's empty value and a `push_error()`. The catalog starts `UNLOADED` in its field initializers, and a lookup before `ContentBootstrap.run()` is rejected like any other non-Ready lookup.
**ADR Version**: ADR-0001 2026-10-23; ADR-0004 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `load_all()` is synchronous, so the Loading and Validating states can only be observed from code that runs inside the call. The seams below provide that.

**Control Manifest Rules (this layer)**:
- Required: "state is `ContentCatalog.state` (`UNLOADED | LOADING | VALIDATING | READY | FAILED`)." "`ContentCatalog` sets up all its state in field initializers or `_init()`. Its `_ready()` must do nothing to catalog state."
- Forbidden: special-casing only `UNLOADED` and letting a lookup through once `load_all()` has started.
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-6** GIVEN a catalog in Unloaded, Loading or Validating, WHEN any lookup is called, THEN it returns an error.

---

## Implementation Notes

*Derived from ADR-0001 (States and Transitions; Amendment 2026-10-23) and ADR-0004 §3–§4:*

- Every lookup (`get_record`, `has_record`, `all_records`, `resolve_alias`) checks `state == READY` first. Otherwise it returns the empty value (`null`, `false`, `[]`, `""`), calls `push_error()` (for `UNLOADED`, naming the missing bootstrap, per ADR-0004 §3), and sets `last_lookup_error = &"not_ready"`.
- **Loading seam.** Add `var file_loaded_hook: Callable` (default empty) to `ContentCatalogService`. `load_all()` calls it once after each file is loaded, while `state == LOADING`, passing the file path. It is a test seam only; doc-comment it as such. Do not use a signal: story 021's monitor allows only the catalog's state-change signal during load.
- **Validating seam.** No new API: register a test-only validator with `register_record_validator()` that calls each lookup and records the results. ADR-0004 forbids lookups inside production validators (purity). A test double may do it, because its purpose is to observe that the lookups are refused.
- **Unloaded.** A fresh `ContentCatalogService.new()`, with a lookup called before any `load_all()`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 009: lookups on a Failed catalog.
- Story 008: a second `load_all()`.

---

## Files

- `src/data/content_catalog.gd` (`file_loaded_hook` seam; state guard on every lookup)
- `tests/unit/content_data/content_data_state_guard_test.gd` (reuses `fixtures/valid_one_of_each/`)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fixes applied: `not_ready` channel, Loading hook, Validating test validator). The developer implements against these — do not invent new test cases during implementation.*

- **AC-6**: All four lookups are refused in each non-terminal state.
  - Given / When / Then, per state:
    - **Unloaded**: a fresh catalog, no `load_all()` yet. Each of `get_record(&"character", id)`, `has_record(&"character", id)`, `all_records(&"character")` and `resolve_alias(id)` returns its empty value with `last_lookup_error == &"not_ready"`.
    - **Loading**: `file_loaded_hook` set to a callable that asserts `state == LOADING` and calls the four lookups, recording each return value and `last_lookup_error`. After `load_all(valid_one_of_each)` returns, every recorded result is empty with `&"not_ready"`, and the hook ran at least once.
    - **Validating**: a test validator registered for `&"character"` before `load_all()` does the same with `state == VALIDATING`. Every recorded result is empty with `&"not_ready"`, and the validator ran at least once.
  - Edge cases: after the same load ends `READY`, the same four lookups succeed (`&""`), which proves the guard is state-based and not sticky. The test validator returns `[]`, so it adds no entries.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content_data/content_data_state_guard_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-002-load-one-of-each-type.md`
- Unlocks: `production/epics/content-catalog/story-008-second-load-rejected.md`, `production/epics/content-catalog/story-009-one-error-fails-catalog.md`
