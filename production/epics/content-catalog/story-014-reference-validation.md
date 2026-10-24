# Story 014: Missing, wrong-type, self- and cyclic references, and a duplicate list entry, each error

> **Epic**: Content Catalog
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-24

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
- **Cycle graph: decided 2026-10-23** (GDD Edge Cases and ADR-0001 amendment). A self-reference on any reference field is always an error. Cycles are checked only along fields an owner declares with `register_acyclic_field(type, field)`; cross-type references such as `faction → rule_id → faction_rule → ref_ids → enemy → faction_id → faction` are legal and never cycle-checked. EffectDescriptor parameters are never edges for the catalog (their owner validates Move chains). Fixtures: see T3–T5 in QA Test Cases. (QL-STORY-READY GAPS fix, 2026-10-24: the earlier "test-only record type" plan had no API behind it, because `TYPE_TABLE` is a constant, and no real type references its own type.)
- **Detector shape (QL-STORY-READY, 2026-10-24).** The cycle detector is a pure function over an edge map, `{record id: Array of target ids}`, built from the registered acyclic fields after alias resolution. It returns each cycle once, as an Array of member ids starting at the member that sorts first; a self-edge is a cycle of one. It reads no catalog state, so T3 and T4 call it directly. The reference pass turns each returned cycle into one report entry with locations. This is a test structure inside the story, not a new public API, so it needs no ADR change.
- **Precedence (QL-STORY-READY, 2026-10-24).** No real record type has a reference field naming its own type, so a value equal to the referring record's own id is always also a wrong-type value. It gives one entry, the self-reference error, never a second wrong-type entry for the same value.
- The cycle detector is one generic depth-first walk over the edge table, reporting each cycle once (located at the member that sorts first, the other members in `related_locations`), never a per-field check.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 013: alias-specific rules.
- Story 018: the alien-only faction fields (`rule_id` on a `human_nation` is a Rule 8 error there, not a reference error).
- Story 019: the unreferenced-record warning, which uses this pass's inbound counts.

---

## Files

- `src/data/content_catalog.gd` (`REFERENCE_SCHEMA` with the 14 reference fields; `register_acyclic_field()`; the reference pass for missing, wrong-type, wrong-kind, self- and duplicate references; static `find_reference_cycles()` and the cycle check over registered acyclic fields)
- `tests/unit/content_data/content_data_reference_test.gd` (14 test functions) and its `.uid`
- `tests/unit/content_data/fixtures/reference_defects/` (`missing_id/`, `wrong_type_move_ids/`, `wrong_kind_nation_id/`, `cycle_3/`, `duplicate_list_entry/`, `alias_reference_ok/`, `valid_references/`, `self_reference/`, `duplicate_missing/`)
- `tests/unit/content_data/fixtures/valid_one_of_each/` (changed: `char_baguette_thrower.nation_id` now names a new `faction_human_republic`, because `nation_id` must name a `human_nation`)

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23: GAPS; the cycle cases follow the 2026-10-23 cycle-graph decision above). The developer implements against these — do not invent new test cases during implementation.*

Each test loads one fixture into a fresh catalog and asserts `FAILED` plus exactly one error entry with the stated `record_id` and `field`, filtering on `severity == &"error"`.
- **AC-13 / T1 missing ID**: `char_x.move_ids = ["move_nobody"]`. Then `record_id == "char_x"`, `field == "move_ids"`.
- **AC-13 / T2a wrong type**: `char_x.move_ids = ["char_y"]` (`char_y` exists). Then `record_id == "char_x"`, `field == "move_ids"`.
- **AC-13 / T2b wrong kind**: `char_x.nation_id = "faction_alien_a"` (`kind: alien`). Then `field == "nation_id"`.
- **AC-13 / T3 self-reference** (pure function; QL-STORY-READY GAPS fix, 2026-10-24): call the cycle detector directly with a synthetic edge map `{"char_x": ["char_x"]}`. It returns exactly one cycle, `["char_x"]` (a self-edge is a cycle of one). No real record type has a reference field naming its own type, so a self-reference on real data is always also a wrong-type value; see the precedence note in Implementation Notes.
- **AC-13 / T4 2-record cycle** (pure function): call the detector with `{"node_a": ["node_b"], "node_b": ["node_a"]}`. It returns exactly one cycle, `["node_a", "node_b"]`, starting at the member that sorts first. No two real types reference each other, so this shape cannot be built through `load_all()`.
- **AC-13 / T5 3-record cycle** (fixture, real types, through `load_all()`): `cycle_3/` holds `faction_a` (`kind: alien`, `rule_id: "rule_a"`), `rule_a` (`ref_ids: ["enemy_a"]`) and `enemy_a` (`faction_id: "faction_a"`), each otherwise valid. Before `load_all()`, the test calls `register_acyclic_field(&"faction", &"rule_id")`, `register_acyclic_field(&"faction_rule", &"ref_ids")` and `register_acyclic_field(&"enemy", &"faction_id")`. This registration is test-only: production deliberately never cycle-checks this chain (GDD Edge Cases "References"; ADR-0001). Then `FAILED` and exactly one error entry: `location` at the member whose path sorts first, the other two members' paths in `related_locations`, `field` = that member's acyclic field. A control without the three registrations loads `READY` with 0 error entries.
- **AC-13 / T6 duplicate list entry**: `char_x.move_ids = ["move_a", "move_a"]`. Then `field == "move_ids"`.
- Edge cases: a reference through an alias is not an error (story 013 T3). A valid control fixture (everything resolves) gives 0 error entries.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content_data/content_data_reference_test.gd` — must exist and pass, including T3–T5. Gate level: BLOCKING.

**Status**: [x] Created and passing (see Completion Notes)

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-002-load-one-of-each-type.md`
- Unlocks: `production/epics/content-catalog/story-013-alias-shadowing-and-double-declaration.md`, `production/epics/content-catalog/story-019-warning-cases.md`, `production/epics/content-catalog/story-023-deterministic-report-order.md`

---

## Completion Notes
**Completed**: 2026-10-24
**Criteria**: 1/1 passing (AC-13). None deferred.
**Deviations**: ADVISORY: a cycle entry is located at the member whose id sorts first; the T5 text says the member whose path sorts first. They agree on the `cycle_3` fixture but can differ when members sit in different type folders. ADVISORY: the missing-id branch cannot fail a test on its own; without it a missing id falls through to a wrong-type entry with the same structured fields, and tests never assert on messages. Notes: `valid_one_of_each/` changed because `nation_id` must now name a `human_nation`: the character points at a new `faction_human_republic` (no assertion changed). The cycle walk is iterative: the first, recursive version overflowed GDScript's call stack at about 1,100 chained records and returned no cycles. Code review split the edge-map building into `_build_acyclic_edge_map()` (complexity 9) to bring `_run_cycle_checks()` under the limit, and added end-to-end self-reference and repeated-missing-value tests.
**Test Evidence**: `tests/unit/content_data/content_data_reference_test.gd` (14 functions); suite 86/86, 0 orphans, exit 0 on Godot 4.7.2. Watched fail (gdUnit `-c`): turning off the wrong-type, kind, duplicate, cycle-closing and rotation guards each failed a test; the 3,000-record chain test failed on the recursive walk; letting a self-reference fall through failed the end-to-end self-reference test. Commits 2c23269, ac45c17, ef0c73a.
**Reviewed by**: lead-programmer (LP-CODE-REVIEW APPROVE); QL-TEST-COVERAGE ADEQUATE; /code-review CHANGES REQUIRED (complexity 11) → fixed
