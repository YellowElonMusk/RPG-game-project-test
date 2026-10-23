# Story 003: `all_records(type)` returns records sorted by ID, whatever the discovery order

> **Epic**: Content Catalog
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-23

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format
**ADR Decision Summary**: The lookup API includes `all_records(type)`, which returns records in a fixed order sorted by `id` so that tests and saves behave identically on every run, whatever order the filesystem lists files in.
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: The order `ResourceLoader.list_directory()` returns is not documented as stable. Never rely on it.

**Control Manifest Rules (this layer)**:
- Required: "Lookup API names are `get_record(type, id)`, `has_record(type, id)`, `all_records(type)` (sorted by `id`) and `resolve_alias(id)`."
- Forbidden: relying on directory-listing order for any observable output.
- Guardrail: the sort runs once at load, never per lookup per frame.

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-2** GIVEN a Ready catalog, WHEN `all_records(type)` is called on each type, THEN records come back sorted by ID, and the result is identical when the same files are loaded in a shuffled file order.

---

## Implementation Notes

*Derived from ADR-0001 Rule 9 (lookup) and the QA gate:*

- Sort each type's records by `id` as a case-sensitive string comparison (`a.id < b.id`), once, at the end of a successful load. `all_records` returns `duplicate_deep()` copies in that order.
- **Discovery-order test seam.** Renaming files to change their order is not possible: filename = `id` is a validation rule, so a rename becomes an error. Filesystem listing order cannot be controlled deterministically either. Add an injectable transform instead: `var discovery_order_transform: Callable` on `ContentCatalogService`, default empty (identity). When set, `load_all()` passes each directory's `PackedStringArray` listing through it before loading. It is a test seam only; production code never sets it. Document it with a doc comment saying so.
- The test applies a **fixed** permutation (reverse the listing, and a fixed rotation), never a random shuffle with a seed, per the Determinism rule in coding-standards.
- Compare `id` sequences, not objects. Two `duplicate_deep()` copies are never the same instance.
- This underwrites the report-order determinism in story 023, which reuses the seam.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 023: deterministic order of the validation report.
- Story 006: the copy semantics of the returned records.

---

## Files

- `src/data/content_catalog.gd` (sort moved into `load_all()`, once per type; `discovery_order_transform` test seam; `all_records()` iterates the pre-sorted bucket)
- `tests/unit/content_data/fixtures/sort_order/` (9 `.tres`: characters, moves, factions × {a, a_two, b})
- `tests/unit/content_data/content_data_sort_order_test.gd` (7 test functions, AC-2)
- `tests/unit/content_data/content_data_sort_order_test.gd.uid` (import-generated sidecar)

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fix applied: discovery-order seam). The developer implements against these — do not invent new test cases during implementation.*

- **AC-2**: Records come back sorted by `id`, and discovery order does not change the result.
  - Given: `fixtures/sort_order/`, valid, with several records in at least three types.
  - When: catalog A loads it with no transform; catalog B loads it with `discovery_order_transform` reversing each listing; catalog C loads it with a fixed rotation by one.
  - Then: for each of the 12 types, the `id` list from `all_records(type)` is strictly ascending, and catalogs A, B and C produce equal `id` lists.
  - Edge cases: IDs that share a prefix (`char_a` < `char_a_two` < `char_b`) sort by plain string order. Types with zero records return `[]` in all three catalogs. `last_lookup_error == &""` after each call.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content_data/content_data_sort_order_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-002-load-one-of-each-type.md`
- Unlocks: `production/epics/content-catalog/story-023-deterministic-report-order.md`

---

## Completion Notes
**Completed**: 2026-10-23
**Criteria**: 1/1 passing (AC-2). None deferred.
**Deviations**: Advisory, deferred hardening of the test-only `discovery_order_transform` seam: (1) `load_all()` does not check that the transform returns a same-size listing; (2) assigning the seam after `load_all()` has no `state != UNLOADED` guard, unlike the two registration methods. Neither affects production, which never sets the seam. AC-2's "shuffled" is implemented as two fixed permutations (reverse, rotate-by-one) per the Determinism rule, as the story's Implementation Notes direct. FAILED-catalog ordering is untested here; story 009 owns the FAILED path.
**Test Evidence**: `tests/unit/content_data/content_data_sort_order_test.gd` (7 functions); suite 25/25, 0 orphans, exit 0 on Godot 4.7.2. Mutation check: removing the sort fails 9 assertions on the reversed and rotated catalogs. Commit d9a69cc.
**Reviewed by**: lead-programmer (LP-CODE-REVIEW APPROVE); QL-TEST-COVERAGE ADEQUATE; `/code-review` APPROVED WITH SUGGESTIONS
