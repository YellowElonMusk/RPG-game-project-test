# Story 008: A second load request on a Ready or Failed catalog is rejected and changes nothing

> **Epic**: Content Catalog
> **Status**: In Progress
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-23

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (Implementation Guidelines; Amendment 2026-10-23); ADR-0004: Content Boot Ordering (§1 idempotency guard)
**ADR Decision Summary**: The catalog loads once per session and Ready is terminal. `load_all()` returns `ERR_ALREADY_IN_USE` and changes nothing when called a second time. `ContentBootstrap.run()` does nothing unless `catalog.state == UNLOADED`.
**ADR Version**: ADR-0001 2026-10-23; ADR-0004 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: The spy subclass overrides a typed method. On Godot 4.7 a typed override with no `return` on a path is a hard parse error that fails every dependent script (control manifest, Required Engine Patterns). Write `return super(data_root)`. (QL-STORY-READY GAPS fix, 2026-10-23.)

**Control Manifest Rules (this layer)**:
- Required: "The catalog loads once per session; `READY` is terminal. A second `load_all()` is rejected." "`ContentBootstrap.run(catalog)`... is a no-op unless `catalog.state == UNLOADED`."
- Forbidden: a reload path of any kind.
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-7** GIVEN a catalog that is Ready, or one that is Failed, WHEN a second load is requested, THEN the request returns an error and the state is unchanged.

---

## Implementation Notes

*Derived from ADR-0001 Amendment 2026-10-23 and ADR-0004 §1:*

- `load_all()` checks `state != UNLOADED` first. If so, it returns `ERR_ALREADY_IN_USE` with no other effect: no state change, no re-read, no change to the report or to any record. Calling `push_error()` here is acceptable but optional (it is a programmer error).
- `ContentBootstrap.run()` keeps its own guard. On a non-`UNLOADED` catalog it returns before any registrant runs, so a second `run()` neither registers twice nor calls `load_all()`.
- The test for `run()` counts calls with a spy: a test-only subclass of `ContentCatalogService` (in the test directory) that overrides `load_all()` to increment a counter and call `super`. `run()` is typed against `ContentCatalogService`, so the subclass is accepted. Give the spy no `class_name`: load it with `preload()` and instantiate it. It satisfies the `ContentCatalogService` type through `extends` alone, and a `class_name` would put a test-only class in the global registry. (QL-STORY-READY GAPS fix, 2026-10-23.)

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 009: lookups on a Failed catalog.

---

## Files

- `tests/unit/content_data/content_data_reload_rejected_test.gd` (4 test functions) and its `.uid`
- `tests/unit/content_data/helpers/spy_content_catalog.gd` (test-only spy, no `class_name`) and its `.uid`
- `tests/unit/content_data/fixtures/one_error_rest_valid/` (12 `.tres`: 1 human-nation faction, 5 characters, 5 moves, 1 misnamed move; built to story 009's spec, yields exactly one error)
- `src/data/content_catalog.gd`, `src/boot/content_bootstrap.gd` — unchanged: both guards already held

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS resolved by `load_all() -> Error`). The developer implements against these — do not invent new test cases during implementation.*

- **AC-7**: A second load is rejected on both terminal states, and `run()` loads once.
  - Given / When / Then:
    - **Ready**: load `valid_one_of_each` (returns `OK`, `READY`). Call `load_all(other_root)` with a different fixture. It returns `ERR_ALREADY_IN_USE`; `state` stays `READY`; the `id` lists from `all_records` for all 12 types equal those from before the call; the report is unchanged.
    - **Failed**: load `one_error_rest_valid` (returns `FAILED`, `FAILED`). Call `load_all(valid_one_of_each)`. It returns `ERR_ALREADY_IN_USE`; `state` stays `FAILED` (not `LOADING`, not `READY`); the report is unchanged, with the same entries in the same order.
    - **Bootstrap**: with the spy catalog, call `ContentBootstrap.run(spy, root)` twice. The spy's `load_all` counter is exactly 1, and the state after the second call equals the state after the first.
  - Edge cases: a second `run()` on a Failed catalog also leaves the counter at 1.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content_data/content_data_reload_rejected_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-007-lookups-error-before-ready.md`
- Unlocks: None
