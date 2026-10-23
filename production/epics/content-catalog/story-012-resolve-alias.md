# Story 012: `resolve_alias` resolves a record's declared alias to its live ID

> **Epic**: Content Catalog
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-001`, `TR-content-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format
**ADR Decision Summary**: A renamed or merged record keeps its old ID in its own `aliases` list so old saves still resolve. `resolve_alias(id: String) -> String` maps an alias to its live ID in exactly one hop.
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: none.

**Control Manifest Rules (this layer)**:
- Required: "Lookup API names are `get_record(type, id)`, `has_record(type, id)`, `all_records(type)` (sorted by `id`) and `resolve_alias(id)`." "Every record exports `id: String`, and `aliases: PackedStringArray` where ID aliasing applies."
- Forbidden: multi-hop alias resolution.
- Guardrail: the alias map is built once at load.

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-11** GIVEN `char_new` with `aliases: [char_old]`, WHEN `resolve_alias("char_old")` is called, THEN it returns `char_new`.

---

## Implementation Notes

*Derived from ADR-0001 Rule 2 and Rule 9:*

- At the end of a successful load, build one `Dictionary` from alias to live ID across all types. `resolve_alias(id)` returns the mapped live ID when `id` is an alias.
- For an ID that is neither live nor an alias, follow the lookup error channel (ADR-0001 amendment): return `""` and set `last_lookup_error = &"missing_id"`.
- The live-ID passthrough (`resolve_alias(live_id) == live_id`) is AC-12's third case and is tested in story 013. Implement it here, because it shares the code path.
- Aliases are validated as IDs too (F1 pattern and type prefix). An alias that fails F1 is an error on field `aliases`. This is covered by story 010's mechanism; no extra fixture is needed here.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 013: alias errors (shadowing, declared twice) and the live-ID passthrough test.
- Story 028: the CI ID manifest.

---

## Files

- `src/data/content_catalog.gd` (alias map, `resolve_alias`)
- `tests/unit/content_data/fixtures/alias_basic/`
- `tests/unit/content_data/content_data_alias_resolve_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23: ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-11**: A declared alias resolves to its live ID.
  - Given: `fixtures/alias_basic/` holds `characters/char_new.tres` with `aliases: ["char_old"]` (plus its faction).
  - When: loaded into a fresh catalog (`OK`, `READY`), and `resolve_alias("char_old")` is called.
  - Then: it returns `"char_new"`, with `last_lookup_error == &""`; `get_record(&"character", resolve_alias("char_old"))` is non-null.
  - Edge cases: a record with two aliases (`["char_old", "char_older"]`) resolves both. `resolve_alias("char_never_existed")` returns `""` with `&"missing_id"`.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content_data/content_data_alias_resolve_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-010-id-format-validation.md`
- Unlocks: `production/epics/content-catalog/story-013-alias-shadowing-and-double-declaration.md`, `production/epics/content-catalog/story-028-id-manifest-ci.md`
