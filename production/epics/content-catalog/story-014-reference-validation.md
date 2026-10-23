# Story 014: Missing, wrong-type, self- and cyclic references, and a duplicate list entry, each error

> **Epic**: Content Catalog
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format; ADR-0011: Faction Rule Modifiers (§4–§5: `Faction.rule_id` and `FactionRuleData.ref_ids` go through the generic reference pass)
**ADR Decision Summary**: Records refer to each other by ID only. One generic reference pass checks that every reference resolves to a record of the correct type, detects cycles, and rejects duplicate list entries. Faction rule references use that same pass, with no rule-specific lookup.
**ADR Version**: ADR-0001 2026-10-23; ADR-0011 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: none.

**Control Manifest Rules (this layer)**:
- Required: "Cross-references are `String` / `PackedStringArray` fields holding record IDs (`nation_id`, `move_ids`, `faction_id`, …)." "`Faction.rule_id` is an ordinary reference to a `faction_rule` record, checked by the generic reference pass."
- Forbidden: "Never use `@export var x: OtherResourceType` for a cross-reference." Per-field special-casing in the reference pass.
- Guardrail: the pass is linear in the number of references plus one graph walk; it runs once at load.

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-13** One test each: a reference to a missing ID; a wrong-type reference (`move_ids` containing a `char_` ID, and a Character `nation_id` naming an `alien` faction); a self-reference; a 2-record cycle; a 3-record cycle; and a duplicate entry in a list field. Each produces an error.

---

## Implementation Notes

*Derived from ADR-0001 Rule 3 and Edge Cases ("References"), and ADR-0011 §4–§5:*

- **Reference schema table.** One constant table lists each reference field, the type it must name, and any constraint on the target: `character.nation_id → faction (kind == human_nation)`, `enemy.faction_id → faction (kind == alien)`, `character.move_ids`, `enemy.move_ids`, `character.signature_move_id → move`, `faction.rule_id → faction_rule`, `faction_rule.ref_ids → move | enemy`, `combo.required_state_ids → quirk_state`, `combo.required_character_ids → character`, `map.faction_id`, `encounter.faction_id`, `occupation_stage.faction_id → faction`, `map.encounter_zone_ids → encounter`, `encounter.enemy_ids → enemy`. Asset-ID fields (`sprite_set_id`, `ai_profile_id` while AIProfile is reserved, …) are not references and are not in the table. Every target ID is passed through the alias map first (story 013).
- **Entries.** Missing ID: `field` = the reference field, `record_id` = the referring record. Wrong type, or wrong target `kind`: same shape. Duplicate list entry: `field` = the list field. One entry per offending value.
- **Cycle graph: decided 2026-10-23** (GDD Edge Cases and ADR-0001 amendment). A self-reference on any reference field is always an error. Cycles are checked only along fields an owner declares with `register_acyclic_field(type, field)`; cross-type references such as `faction → rule_id → faction_rule → ref_ids → enemy → faction_id → faction` are legal and never cycle-checked. EffectDescriptor parameters are never edges for the catalog (their owner validates Move chains). Fixtures: T3 uses any typed reference field naming the record's own ID; T4 and T5 use a test-only record type, registered by the fixture, with a reference field `next_id` to its own type that the test marks acyclic.
- The cycle detector is one generic depth-first walk over the edge table, reporting each cycle once (located at the member that sorts first, the other members in `related_locations`), never a per-field check.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 013: alias-specific rules.
- Story 018: the alien-only faction fields (`rule_id` on a `human_nation` is a Rule 8 error there, not a reference error).
- Story 019: the unreferenced-record warning, which uses this pass's inbound counts.

---

## Files

- `src/data/content_catalog.gd` (reference table, reference pass, cycle detector)
- `tests/unit/content_data/fixtures/reference_defects/missing_id/`, `.../wrong_type_move_ids/`, `.../wrong_kind_nation_id/`, `.../self_reference/`, `.../cycle_2/`, `.../cycle_3/`, `.../duplicate_list_entry/`
- `tests/unit/content_data/content_data_reference_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23: GAPS; the cycle cases follow the 2026-10-23 cycle-graph decision above). The developer implements against these — do not invent new test cases during implementation.*

Each test loads one fixture into a fresh catalog and asserts `FAILED` plus exactly one error entry with the stated `record_id` and `field`, filtering on `severity == &"error"`.
- **AC-13 / T1 missing ID**: `char_x.move_ids = ["move_nobody"]`. Then `record_id == "char_x"`, `field == "move_ids"`.
- **AC-13 / T2a wrong type**: `char_x.move_ids = ["char_y"]` (`char_y` exists). Then `record_id == "char_x"`, `field == "move_ids"`.
- **AC-13 / T2b wrong kind**: `char_x.nation_id = "faction_alien_a"` (`kind: alien`). Then `field == "nation_id"`.
- **AC-13 / T3 self-reference**, **T4 2-record cycle**, **T5 3-record cycle**: fixtures and expected `field` to be named once the cycle-graph decision is made. Each must produce exactly one cycle entry (`location` = the member that sorts first, the others in `related_locations`). Until then these three tests are not written, and the story cannot close.
- **AC-13 / T6 duplicate list entry**: `char_x.move_ids = ["move_a", "move_a"]`. Then `field == "move_ids"`.
- Edge cases: a reference through an alias is not an error (story 013 T3). A valid control fixture (everything resolves) gives 0 error entries.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content_data/content_data_reference_test.gd` — must exist and pass, including T3–T5. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-002-load-one-of-each-type.md`
- Unlocks: `production/epics/content-catalog/story-013-alias-shadowing-and-double-declaration.md`, `production/epics/content-catalog/story-019-warning-cases.md`, `production/epics/content-catalog/story-023-deterministic-report-order.md`
