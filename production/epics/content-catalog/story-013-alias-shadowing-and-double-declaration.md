# Story 013: Alias rules: a shadowing alias and a doubly declared alias each error; an alias reference resolves in one hop

> **Epic**: Content Catalog
> **Status**: In Progress
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-24

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format
**ADR Decision Summary**: Aliases are declared on the live record they belong to. An alias can never shadow a live ID, and an alias belongs to exactly one record, so `resolve_alias` is always one hop. A reference may use an alias and resolves through it to the aliased record.
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: none.

**Control Manifest Rules (this layer)**:
- Required: "The validation pass covers: ID format and uniqueness, filename = `id`, reference resolution, cycle detection, …" (aliases count toward uniqueness: GDD Rule 8, "IDs are well-formed and unique (aliases included)").
- Forbidden: multi-hop resolution; an alias that hides a real record.
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story (AC-12 as revised 2026-10-23):*

- [ ] **AC-12** One test each: an alias equal to a live ID produces an error naming both records; the same alias declared on two records produces an error naming both (an alias belongs to one record, so a chain of aliases cannot exist); a reference that uses an alias resolves to the aliased record in one hop, and `resolve_alias` of a live ID returns that ID unchanged.

---

## Implementation Notes

*Derived from GDD Rule 2, Edge Cases ("Identity and aliases"), the revised AC-12 and the F3 Entry shape:*

- **Rebuilt from the revised AC-12** (the earlier "chained alias" and "alias whose record is missing" cases could not be built under this data model and were dropped from the GDD; a reference to an ID that is neither live nor an alias is covered by stories 014 and 028).
- **Shadowing.** Record B declares an alias equal to record A's live `id`. One entry: `severity = &"error"`, `record_id` = the declaring record's ID (B), `field = "aliases"`, `location` = B's location, `related_locations` = [A's location]. It does not matter which record sorts first; the declaring record owns the entry.
- **Declared twice.** Records C and D both declare alias `x`. One entry: `record_id` = the record whose location sorts first, `field = "aliases"`, `related_locations` = the other's location. Same shape as story 011.
- **Build order: story 014 first.** T3's one-hop reference clause is implemented by story 014's reference pass; before it exists, T3 passes without proving anything. T1 and T2 need only stories 010-012. (QL-STORY-READY, 2026-10-24.)
- **One-hop reference.** The reference pass (story 014) resolves each referenced ID through the alias map before checking existence and type. A Character whose `move_ids` holds `move_old`, which `move_new` declares as an alias, produces no reference error, and the referenced type is `move_new`'s type. No reference ever resolves through two hops, because an alias can only name a live record.
- **Live-ID passthrough.** `resolve_alias(live_id)` returns `live_id` with `last_lookup_error == &""`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 011: two live records sharing one ID.
- Story 014: references to missing or wrong-type IDs.
- Story 028: IDs that vanished between builds.
- Story 019: the unreferenced-record warning, including that a record referenced only through an alias raises none.

---

## Files

- `src/data/content_catalog.gd` (`_alias_locations` records each alias declaration; `_register_aliases()` validates and registers a record's aliases, reporting an alias listed twice in one record as a duplicate entry; `_check_alias_shadowing()` and `_check_alias_double_declaration()` run in the Validating pass right after the duplicate-id check, and drop every flagged alias from the alias map)
- `tests/unit/content_data/content_data_alias_rules_test.gd` (12 test functions) and its `.uid`
- `tests/unit/content_data/fixtures/alias_rules/` (`shadowing/`, `declared_twice/`, `alias_reference/`, `listed_twice/`, `listed_twice_shadowing/`)

## QA Test Cases

*Written by qa-lead (QL-STORY-READY, 2026-10-23: the original story was INADEQUATE; specs rebuilt from the revised AC-12). The developer implements against these — do not invent new test cases during implementation.*

- **AC-12 / T1**: An alias equal to a live ID errors, naming both records.
  - Given: `alias_rules/shadowing/`: `char_a` (live) and `char_b` with `aliases: ["char_a"]`, plus their faction.
  - When: loaded.
  - Then: `FAILED`; exactly one error entry with `field == "aliases"` and `record_id == "char_b"`; its `related_locations` holds `char_a`'s `res://` path.
  - Edge cases: the same result with reversed discovery order (story 003 seam).
- **AC-12 / T2**: The same alias on two records errors, naming both.
  - Given: `alias_rules/declared_twice/`: `char_c` and `char_d`, both with `aliases: ["char_gone"]`, plus their faction. (Faction added at QL-STORY-READY GAPS fix, 2026-10-24: once story 014 checks references, a Character whose `nation_id` does not resolve is a second error.)
  - When: loaded.
  - Then: `FAILED`; exactly one error entry with `field == "aliases"`; `location.file_path` is `char_c`'s path (sorts first) and `related_locations` holds `char_d`'s path.
  - Edge cases: none.
- **AC-12 / T3**: An alias reference resolves in one hop, and a live ID passes through.
  - Given: `alias_rules/alias_reference/`: `move_new` with `aliases: ["move_old"]`; `char_user` with `move_ids: ["move_old"]`, plus its faction.
  - When: loaded.
  - Then: `OK`, `READY`, 0 error entries; `resolve_alias("move_old") == "move_new"`; `get_record(&"move", resolve_alias("move_old"))` is non-null; `resolve_alias("move_new") == "move_new"` with `last_lookup_error == &""`.
  - Edge cases: none. (The "no unreferenced warning through an alias" case moved to story 019, which owns that warning; QL-STORY-READY GAPS fix, 2026-10-24.)

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content_data/content_data_alias_rules_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-011-duplicate-id-one-error.md`, `production/epics/content-catalog/story-012-resolve-alias.md`, `production/epics/content-catalog/story-014-reference-validation.md`
- Unlocks: None
