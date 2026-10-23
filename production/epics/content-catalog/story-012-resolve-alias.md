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
- [ ] **AC-11b** GIVEN a record declaring an alias that fails F1 (pattern, type prefix, or over 64 characters), WHEN the catalog loads, THEN it produces one error entry with `field == "aliases"` and `record_id` equal to the declaring record's id. (GDD Rule 8: "IDs are well-formed and unique (aliases included)"; added at QL-STORY-READY GAPS fix, 2026-10-24.)

---

## Implementation Notes

*Derived from ADR-0001 Rule 2 and Rule 9:*

- At the end of a successful load, build one `Dictionary` from alias to live ID across all types. `resolve_alias(id)` returns the mapped live ID when `id` is an alias.
- For an ID that is neither live nor an alias, follow the lookup error channel (ADR-0001 amendment): return `""` and set `last_lookup_error = &"missing_id"`.
- The live-ID passthrough (`resolve_alias(live_id) == live_id`) is AC-12's third case and is tested in story 013. Implement it here, because it shares the code path.
- **Alias format (AC-11b; QL-STORY-READY GAPS fix, 2026-10-24).** Aliases are validated as IDs too: the same F1 rule (length, `ID_PATTERN`, the declaring type's prefix). Story 010's check covers only the record's own `id`, so add the alias check in `_load_one()`, in the loop that fills the alias map. A malformed alias is one error on field `aliases` with `record_id` = the declaring record's id, and it is not added to the alias map. Several malformed aliases on one record give one entry each.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 013: alias errors (shadowing, declared twice) and the live-ID passthrough test.
- Story 028: the CI ID manifest.

---

## Files

- `src/data/content_catalog.gd` (alias map, `resolve_alias`)
- `tests/unit/content_data/fixtures/alias_basic/`
- `tests/unit/content_data/fixtures/alias_format_defects/` (one subdirectory per defect, plus `len_64/`)
- `tests/unit/content_data/content_data_alias_resolve_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23: ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-11**: A declared alias resolves to its live ID.
  - Given: `fixtures/alias_basic/` holds `characters/char_new.tres` with `aliases: ["char_old"]` (plus its faction).
  - When: loaded into a fresh catalog (`OK`, `READY`), and `resolve_alias("char_old")` is called.
  - Then: it returns `"char_new"`, with `last_lookup_error == &""`; `get_record(&"character", resolve_alias("char_old"))` is non-null.
  - Edge cases: a record with two aliases (`["char_old", "char_older"]`) resolves both. `resolve_alias("char_never_existed")` returns `""` with `&"missing_id"`.
- **AC-11b**: A malformed declared alias is an error naming the declaring record on field `aliases`. (Added at QL-STORY-READY GAPS fix, 2026-10-24.)
  - Given: `fixtures/alias_format_defects/`, one subdirectory per defect, each holding `characters/char_new.tres` (valid id) declaring one malformed alias, plus its faction: `Char_Old` (uppercase), `char old` (space), `bad_alias` (no type prefix), `char_` + 60 × `a` (65 characters).
  - When: each subdirectory is loaded into a fresh catalog.
  - Then: each returns `FAILED`, with exactly one error entry: `field == "aliases"`, `record_id == "char_new"`.
  - Edge cases: `len_64/` declares an alias of `char_` + 59 × `a` (64 characters); it loads `READY` and `resolve_alias` on it returns `"char_new"`. A malformed alias is never added to the alias map: in the `uppercase` fixture, `resolve_alias("Char_Old")` is refused with `&"not_ready"`, because the catalog is `FAILED`.

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
