# Story 006: A caller's edit to a returned record, including nested lists and descriptors, never leaks back

> **Epic**: Content Catalog
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-23

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (Implementation Guidelines; Amendment 2026-10-23 "Deep copies")
**ADR Decision Summary**: Immutability after Ready is enforced, not left to discipline: `get_record` and `all_records` return `duplicate_deep()` copies, so a caller's edit to a nested array or EffectDescriptor never reaches the cached record. The cost is bounded by record size, and lookups happen at construction time, never per frame.
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: `Resource.duplicate_deep()` was added in Godot 4.5, after the LLM cutoff. `duplicate(true)` keeps its old behaviour, which does not copy nested `Array` / `Dictionary` values inside the resource reliably (`docs/engine-reference/godot/deprecated-apis.md`, "`duplicate()` for nested resources → `duplicate_deep()`, 4.5"). Use `duplicate_deep()`. Check its optional deep-duplicate mode argument against the 4.7 class reference and pick the mode that copies arrays and dictionaries inside exported properties.

**Control Manifest Rules (this layer)**:
- Required: "Consumers copy a record's values into their own runtime objects (`Combatant`, `Move`) at construction time; records are shared, cached `Resource` instances."
- Forbidden: "Never mutate a record's fields after load, or use a record as live runtime state."
- Guardrail: "ContentCatalog: loads once at boot, never per frame." Copies happen per lookup; lookups are construction-time.

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-5** GIVEN a Ready catalog, WHEN a caller modifies a returned definition (including a nested list and a nested EffectDescriptor), THEN the next `get_record` for that ID returns the original values.

---

## Implementation Notes

*Derived from ADR-0001 Amendment 2026-10-23:*

- The mechanism is decided: option (a), deep copies. Do not build a write-rejecting wrapper.
- `get_record` returns `record.duplicate_deep(...)` of the cached instance. `all_records` returns an array of such copies. The cached originals are never handed out.
- `ResourceLoader.load()` defaults to `CACHE_MODE_REUSE`, so the cached instance is shared with anything else that loads the same path. The catalog must keep its own references and never let them escape.
- Record a rough cost note in the Completion Notes (e.g. time for 1000 `get_record` calls on the fixture) so `/story-done` can confirm the "construction time, never per frame" assumption. This is an observation, not a gate.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 021: no logic in record classes.
- Consumers' own copy-at-construction factories: `production/epics/content-migration/`.

---

## Files

- `tests/unit/content_data/content_data_immutability_test.gd` (3 test functions: T1 Move, T2 Character, cost observation; reuses `fixtures/valid_one_of_each/`) and its `.uid` sidecar
- `src/data/content_catalog.gd` — unchanged: the no-argument `duplicate_deep()` from story 002 already deep-copies nested arrays and dictionaries on 4.7.2

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23: ADEQUATE; engine risk raised to MEDIUM). The developer implements against these — do not invent new test cases during implementation.*

- **AC-5 / T1**: Scalar, list and nested-descriptor edits on a Move do not leak.
  - Given: a Ready catalog from `valid_one_of_each`.
  - When: the test takes `get_record(&"move", id)`, changes its scalar `cost`, appends a dictionary to its `effects`, and changes a key inside `effects[0]`.
  - Then: the next `get_record(&"move", id)` deep-equals the fixture (compared with a `CACHE_MODE_IGNORE` load of the fixture file).
  - Edge cases: the two returned objects are different instances (`is_same` is false).
- **AC-5 / T2**: List edits on a Character do not leak.
  - Given: the same catalog.
  - When: the test appends to a returned Character's `move_ids`.
  - Then: the next `get_record` returns an independent instance with the original `move_ids`. Note (QL-STORY-READY GAPS fix, 2026-10-23): `move_ids` is a value-semantics `PackedStringArray`, so this case proves instance independence, not deep-copy correctness on its own. T1, on Move's `Array[Dictionary]` `effects`, is the evidence for AC-5's deep-copy guarantee; T2 is a supplementary instance-independence check.
  - Edge cases: edits made through an element of `all_records(&"character")` do not leak into `get_record` either, and the reverse holds.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content_data/content_data_immutability_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (see Completion Notes)

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-002-load-one-of-each-type.md`
- Unlocks: None

---

## Completion Notes
**Completed**: 2026-10-23
**Criteria**: 1/1 passing (AC-5). None deferred.
**Deviations**: None.
**Test Evidence**: `tests/unit/content_data/content_data_immutability_test.gd` (T1 Move, T2 Character, cost observation); suite 36/36, 0 orphans, exit 0 on Godot 4.7.2. Commit d917222.
**Reviewed by**: lead-programmer (LP-CODE-REVIEW APPROVE); QL-TEST-COVERAGE ADEQUATE; `/code-review` APPROVED

**Engine Notes observed**: On the pinned 4.7.2 install, the no-argument `Resource.duplicate_deep()` that story 002 already calls copies every level of a Move record: the record, its `effects` array and each `effects[i]` dictionary are distinct objects, and edits to the copy never reach the original. No mode argument was needed, so `src/data/content_catalog.gd` is unchanged. For this data `duplicate(true)` behaves the same, because records hold plain dictionaries and no sub-Resources (ADR-0001 forbids them); the documented difference only applies to nested sub-Resources.

**Watched fail**: T1 was run against a mutation where `get_record` returned the cached instance with no copy. It failed (3 assertion failures, exit 100). With the copy restored it passes; the full suite is 36/36.

**Cost observation** (not a gate): about 6.4 µs per `get_record()` on the Move fixture, from three runs of 1000 calls (6.38, 6.53 and 6.44 µs). That is consistent with copying at construction time and never per frame.
