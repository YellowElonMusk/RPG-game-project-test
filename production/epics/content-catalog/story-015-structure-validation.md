# Story 015: Unknown, missing, wrong-typed, empty and whitespace-only fields, and an unknown descriptor type, each error naming record and field

> **Epic**: Content Catalog
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format ("Validation mechanism"; "Vocabulary ownership")
**ADR Decision Summary**: Godot silently drops unknown `.tres` properties and typed exports always have defaults, so `Resource` loading catches neither unknown nor missing fields. The catalog reads each file's raw text, diffs its `[resource]` keys against the script's property list, and enforces a validity rule on every required field. Owning systems register the known EffectDescriptor types before validation.
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: The raw-text scan is a hand-written line scanner, not a full `.tres` parser. Check it against the 4.7.2 text-resource format: multi-line values (arrays and dictionaries spanning lines), quoted strings containing `=` or newlines, `metadata/` keys, and the `script = ExtResource(...)` line. Ignore engine-written keys that are not script exports (`script`, `resource_name`, `resource_local_to_scene`, `metadata/*`).

**Control Manifest Rules (this layer)**:
- Required: "Unknown fields are detected by reading each `.tres` file's raw text (`FileAccess`), parsing the `[resource]` section's `key = value` lines, and diffing against the instance's `get_property_list()`." "Every required field has an enforced validity rule (non-empty text, numeric range from the owning GDD)." "Owning systems register their vocabulary before validation: Turn Battle System calls `ContentCatalog.register_known_effect_types(system, types)`."
- Forbidden: "Never rely on `Resource` loading alone to catch unknown or missing fields."
- Guardrail: one `FileAccess` read per file, at load only.

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-14** One test each: an unknown field, a missing required field, a wrong-typed required field, an empty required text field, a whitespace-only required text field, and an unknown EffectDescriptor `type`. Each produces an error naming the record and field.

---

## Implementation Notes

*Derived from ADR-0001 "Validation mechanism" steps 1–2 and "Vocabulary ownership":*

- **Unknown fields.** For each file: `FileAccess.get_file_as_string(path)`, find the `[resource]` section, collect each top-level `key` (a line matching `^([A-Za-z_][A-Za-z0-9_/]*) = `, skipping continuation lines of multi-line values), and diff against the instance's `get_property_list()` filtered to `PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_STORAGE`. Each extra key is one entry: `record_id` = the record's ID, `field` = the unknown key.
- **Required fields.** Each record script declares `const REQUIRED_FIELDS: Array[StringName]`, the fields its owning GDD row marks required (a constant, not a method, so Rule 4 still holds). Record that choice in the Completion Notes. For required text: empty or whitespace-only (`strip_edges().is_empty()`) is an error on that field. Optional text may be empty. Required numeric ranges belong to the owners' validators (story 016), not here.
- **Missing and wrong-typed collapse into one condition** (ADR-0001): a missing key leaves the default, and a wrong-typed value (Godot fails to assign it) also leaves the default, which then fails the field's rule. **Known limitation (for technical-director, from the QA gate):** this only holds when the default fails its own rule. A wrong-typed `defense` silently defaults to 0, which is valid, and goes undetected. The tests below pick fields whose defaults fail (`display_name`).
- **EffectDescriptor `type`.** Every `effects` entry's `type` must be in the union of vocabularies registered through `register_known_effect_types()`. An unknown type is an entry with `field = "effects"`. The tests register the five migrated types (`stun`, `heal_party`, `heal_single`, `damage_debuff`, `direct_damage`) as a test double under `&"turn_battle"`; Turn Battle System owns the real call.
- Also reject a record script that declares an Object/Resource-typed export (ADR-0001 Implementation Guidelines): an entry with `field` = that export, located at the first file of that type. No separate AC; cover it with an edge-case test using a test-only record script.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 016: numeric ranges through registered validators.
- Story 021: known descriptors round-tripping untouched.
- Story 022: files that do not parse at all.

---

## Files

- `src/data/content_catalog.gd` (raw-text key scan, required-field checks, descriptor-type check)
- `src/data/records/*.gd` (`REQUIRED_FIELDS` constants)
- `tests/unit/content_data/fixtures/structure_defects/unknown_field/`, `.../missing_required/`, `.../wrong_typed_required/`, `.../empty_required_text/`, `.../whitespace_required_text/`, `.../unknown_effect_type/`, `.../optional_text_empty/`
- `tests/unit/content_data/content_data_structure_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23: ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

Each test asserts exactly one entry with `severity == &"error"`, the stated `record_id` and `field`, and `state == FAILED`. Fixtures live in `fixtures/structure_defects/<case>/`.
- **AC-14 / T1 unknown field**: GIVEN a Character `.tres` with `stat_blok = {...}`, WHEN loaded, THEN `field == "stat_blok"`.
- **AC-14 / T2 missing required**: GIVEN a Move with no `display_name` key, WHEN loaded, THEN `field == "display_name"`.
- **AC-14 / T3 wrong-typed required**: GIVEN a Move with `display_name = 5`, WHEN loaded, THEN `field == "display_name"`.
- **AC-14 / T4 empty required text**: GIVEN `display_name = ""`, WHEN loaded, THEN `field == "display_name"`.
- **AC-14 / T5 whitespace-only**: GIVEN `display_name = "   "`, WHEN loaded, THEN `field == "display_name"`.
- **AC-14 / T6 unknown descriptor type**: GIVEN a Move with `effects[0].type = "not_a_type"` and the five types registered, WHEN loaded, THEN `field == "effects"`.
- **Control**: an optional text field left empty (`optional_text_empty/`) produces no entry and loads `READY`.
- Edge cases: a multi-line `effects = [ ... ]` value does not produce false unknown-field entries for its inner keys. `script`, `resource_name` and `metadata/*` keys are never reported.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content_data/content_data_structure_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-002-load-one-of-each-type.md`
- Unlocks: `production/epics/content-catalog/story-016-field-range-validators.md`, `story-017-overworld-uniqueness-and-faction-rule.md`, `story-020-mixed-severity-report.md`, `story-021-effect-descriptor-passthrough.md`, `story-023-deterministic-report-order.md` (all under `production/epics/content-catalog/`)
