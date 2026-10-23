# Story 007: Any lookup during Unloaded, Loading or Validating returns an error

> **Epic**: Content Catalog
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-23

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
- **Move validator execution into the Validating phase (QL-STORY-READY GAPS fix, 2026-10-23).** Story 002's `load_all()` runs registered validators inside `_load_one()`, while `state == LOADING`; `state = VALIDATING` is set only after loading ends. ADR-0004 §4 requires validators to run during Validating, after the catalog's own generic checks. Without this move the Validating test case cannot pass. Decided by ADR-0004 §4:
  - **One pass, after all types have loaded.** Set `state = VALIDATING`, then run validators over every stored record: types in `TYPE_TABLE` order, ids in the already-sorted bucket order, so the report order stays deterministic (story 023 builds on this). Generic reference checks in later stories need the complete set, which is why it is not per type.
  - **Location is the record's file path, `record_index` 0.** `_load_one()` records each stored record's source path (for example a `_record_paths` dictionary keyed by type and id) so the pass can fill `location`.
  - Records that failed the null or filename check are not stored and are not validated, as today.
  - `_load_one()` keeps only the null check, the filename check and storage. No existing test registers a validator, so nothing depends on the old timing.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 009: lookups on a Failed catalog.
- Story 008: a second `load_all()`.

---

## Files

- `src/data/content_catalog.gd` (`file_loaded_hook` test seam; `_record_paths` source-path map; validators moved out of `_load_one()` into a new `_run_validators()` pass that runs after `state = VALIDATING`)
- `tests/unit/content_data/content_data_state_guard_test.gd` (4 test functions; reuses `fixtures/valid_one_of_each/`) and its `.uid` sidecar

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

**Status**: [x] Created and passing (see Completion Notes)

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-002-load-one-of-each-type.md`
- Unlocks: `production/epics/content-catalog/story-008-second-load-rejected.md`, `production/epics/content-catalog/story-009-one-error-fails-catalog.md`

---

## Completion Notes
**Completed**: 2026-10-23
**Criteria**: 1/1 passing (AC-6). None deferred.
**Deviations**: None outstanding. This story corrected a latent defect from story 002: registered validators ran inside `_load_one()` while `state == LOADING`, contrary to ADR-0004 §4. They now run in `_run_validators()`, one pass after `state = VALIDATING`, in registration order, over types in `TYPE_TABLE` order and ids in sorted order; each entry's location comes from the new `_record_paths` map. The lookup state guard needed no change: it already rejected every state but READY. LP-CODE-REVIEW raised one concern, `load_all()` cyclomatic complexity 13 after the move; resolved by extracting `_run_validators()`, leaving `load_all()` at 10, the project maximum.
**Test Evidence**: `tests/unit/content_data/content_data_state_guard_test.gd` (4 functions); suite 40/40, 0 orphans, exit 0 on Godot 4.7.2. Watched fail: the Validating test failed (exit 100) against a mutation with validators moved back into the Loading phase, then passed once restored.
**Reviewed by**: lead-programmer (LP-CODE-REVIEW CONCERNS → revised); QL-TEST-COVERAGE ADEQUATE
