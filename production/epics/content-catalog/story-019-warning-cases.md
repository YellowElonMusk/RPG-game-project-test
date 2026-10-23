# Story 019: A shared alien colour, a shared alien shape, a duplicated signature move and an unreferenced record each warn, and the catalog stays Ready

> **Epic**: Content Catalog
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (Rule 8 two severities; F3)
**ADR Decision Summary**: Validation reports in two severities. Errors fail the catalog; warnings are reported but never affect the outcome (`warning_count` never changes `validation_outcome`).
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: none.

**Control Manifest Rules (this layer)**:
- Required: "Validation runs over the complete record set before reporting, every problem collected."
- Forbidden: a warning that changes the terminal state.
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-18** One test each: two alien factions sharing `signature_color`, two sharing `base_shape`, a Character whose `signature_move_id` is also in its `move_ids`, and a record nothing references. Each produces a warning entry, and the state is Ready.

---

## Implementation Notes

*Derived from GDD Edge Cases ("Faction rules", "Other warnings", including the root-type exemption added 2026-10-23) and the F3 Entry shape:*

- **Shared colour / shape.** One `warning` entry per shared value, located at the faction that sorts first, with the others in `related_locations` (the GDD Entry shape: "related_locations … unless the problem spans several places"). `field = "signature_color"` or `"base_shape"`.
- **Signature move also in `move_ids`.** One warning on the Character, `field = "signature_move_id"`.
- **Unreferenced record.** One warning per record with zero inbound references (counted by story 014's reference pass, including references through aliases), `field = ""` (the whole record). **Root types are exempt** and never warn: Character, Map, OccupationStage, InputBindings, Combo, Item. So only Faction, Enemy, Move, QuirkState, FactionRule and Encounter records can warn.
- Because of the exemption, every fixture below is built only from exempt records and records that something references, so each produces **exactly one** warning (the RC-C fix; exact counts are kept).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 020: warnings and errors together.
- Story 018: the error-severity faction rules.

---

## Files

- `src/data/content_catalog.gd` (four warning checks; root-type exemption constant)
- `tests/unit/content_data/fixtures/warnings/shared_color/`, `.../shared_shape/`, `.../signature_in_move_ids/`, `.../unreferenced/`
- `tests/unit/content_data/content_data_warnings_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS resolved by the GDD's root-type exemption). The developer implements against these — do not invent new test cases during implementation.*

Each test loads one fixture into a fresh catalog and asserts `OK`, `state == READY`, 0 error entries, and **exactly one** entry in total, a warning with the stated `record_id` and `field`.
- **AC-18 / T1 shared colour**: GIVEN `faction_alien_a` and `faction_alien_b` (both `kind: alien`, same `signature_color`, shapes `square` and `circle`), each referenced by its own Map (`map_a.faction_id`, `map_b.faction_id`), THEN the warning has `field == "signature_color"`, `record_id == "faction_alien_a"`, and `related_locations` holds `faction_alien_b`'s path.
- **AC-18 / T2 shared shape**: GIVEN the same two factions with different colours and both `base_shape: square`, each referenced by a Map, THEN the warning has `field == "base_shape"`.
- **AC-18 / T3 signature in move_ids**: GIVEN `char_x` with `move_ids: ["move_a"]` and `signature_move_id: "move_a"`, `nation_id` = `faction_human_h`, THEN the warning has `record_id == "char_x"` and `field == "signature_move_id"`. (`move_a` and `faction_human_h` are referenced by `char_x`; `char_x` is a root type.)
- **AC-18 / T4 unreferenced**: GIVEN only `quirk_orphan`, a QuirkState nothing uses, THEN the warning has `record_id == "quirk_orphan"` and `field == ""`.
- Edge cases: a fixture of only root-type records (a Character with no moves, a Map with no faction, an Item) gives 0 entries. A record referenced only through its alias does not warn.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content_data/content_data_warnings_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-009-one-error-fails-catalog.md`, `production/epics/content-catalog/story-014-reference-validation.md`, `production/epics/content-catalog/story-018-faction-field-rules.md`
- Unlocks: `production/epics/content-catalog/story-020-mixed-severity-report.md`
