# Story 002: Load one record of each of the 12 types and get every field back deep-equal

> **Epic**: Content Catalog
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-001`, `TR-content-004`, `TR-content-012` (folded in: see QA Test Cases, T-LOC)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format; ADR-0004: Content Boot Ordering; ADR-0011: Faction Rule Modifiers (§5 `FactionRuleData`); ADR-0012: Overworld Exploration & Encounters (§3 `MapData`, `EncounterData`, `OccupationStageData`, `FactionData.patrol_archetype_id`); ADR-0013: Localization (§4 `LOC_FIELDS` / `NON_LOC_FIELDS`)
**ADR Decision Summary**: Every record type is its own `Resource` subclass saved as one `.tres` per record, with cross-references stored as ID strings, discovered with `ResourceLoader.list_directory()` and served by the `ContentCatalog` autoload. `ContentBootstrap.run()` registers vocabularies and validators and is the only production caller of `load_all()`, which takes an injectable data root and returns an `Error` (ADR-0001 amendment 2026-10-23).
**ADR Version**: ADR-0001 2026-10-23; ADR-0004 2026-10-23; ADR-0011 2026-10-22; ADR-0012 2026-10-23; ADR-0013 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: `ResourceLoader.list_directory(path) -> PackedStringArray` is a 4.4 API, after the LLM cutoff. ADR-0001 verified it in the editor on 4.7.2 (lists `.tres`, excludes non-resources). The exported-build re-verification is story 030. `Resource.duplicate_deep()` (4.5) is required for the lookup return values (ADR-0001 amendment; see story 006 for the test).

**Control Manifest Rules (this layer)**:
- Required: "Every content record type is its own `Resource` subclass (`class_name`, `extends Resource`) with every scalar and enum field as a typed `@export` var." "One record = one `.tres` file at `data/[type_plural]/[id].tres`; the filename without extension must equal the record's `id`." "Discover files with `ResourceLoader.list_directory(path)`, recursed per subdirectory under `data/`." "`ContentCatalog` is an autoload singleton... The catalog script declares `class_name ContentCatalogService`." "`ContentCatalog` sets up all its state in field initializers or `_init()`. Its `_ready()` must do nothing to catalog state." "Every string-typed record export is listed in exactly one of the record script's `LOC_FIELDS` or `NON_LOC_FIELDS`."
- Forbidden: "Never enumerate content files with `DirAccess`." "Never use `@export var x: OtherResourceType` for a cross-reference." "Never name lookups `get()`, `exists()` or `all()`." Never call `load_all()` from the autoload's `_ready()` (ADR-0004).
- Guardrail: "ContentCatalog: loads once at boot, never per frame; every record stays resident for the session."

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-1** GIVEN the fixture `valid_one_of_each` (one record of each of the 12 non-reserved types in Rule 1: Faction, Character, Enemy, Move, QuirkState, Combo, Item, InputBindings, FactionRule, Map, Encounter, OccupationStage, including list fields and nested EffectDescriptors), WHEN the catalog loads, THEN the state is Ready and `get_record(type, id)` returns every record with every field deep-equal to the fixture.

---

## Implementation Notes

*Derived from ADR-0001 (Decision, Key Interfaces, Amendment 2026-10-23), ADR-0004 §1–§5, ADR-0011 §5, ADR-0012 §3 and ADR-0013 §4:*

**Record classes (`src/data/records/`).** Twelve scripts, one per type, each `class_name XxxData extends Resource`, except the bindings record, which keeps the name ADR-0003 gives it: `class_name InputBindings` in `src/data/records/input_bindings.gd` (ruling 2026-10-23). Fields come from GDD Rule 1 and the ADRs that define each type:
- Scalars and enums are typed `@export` vars. EffectDescriptor lists (`effects`) are `Array[Dictionary]`, the one non-scalar export. Cross-references are `String` / `PackedStringArray` ID fields (`nation_id`, `move_ids`, `faction_id`, `rule_id`, `ref_ids`, `encounter_zone_ids`, `enemy_ids`, `required_state_ids`, `required_character_ids`).
- Every record exports `id: String`, plus `aliases: PackedStringArray` where Rule 2 applies (all twelve, so renames are possible for every type).
- `FactionRuleData` follows ADR-0011 §5 exactly (`rule_class: StringName`, `ref_ids`, `params`, `texts`, `colors`). `MapData`, `EncounterData`, `OccupationStageData` follow ADR-0012 §3. `FactionData` includes `patrol_archetype_id`.
- No methods beyond basic getters (Rule 4; story 021 tests this).
- **TR-content-012 (folded in here).** Each record script declares `const LOC_FIELDS: Array[StringName]` (player-visible text: `display_name`, `description`, `flavor_text`, `rule_text`, `punchline_text`, `codex_text`, `archetype_line`, `texts`, the OccupationStage name-card subtitle, …) and `const NON_LOC_FIELDS: Array[StringName]` (IDs, asset IDs, hex colours, `loc_note`, enum-like strings). Every string-typed export appears in exactly one list (ADR-0013 §4). The `LocFieldsValidator` itself (`src/loc/`) and its bootstrap registration are not built here (see Out of Scope).

**Type table (one constant in `content_catalog.gd`).** Map each type `StringName` to its ID prefix and its data subdirectory. Settled by ADRs: `&"faction"`/`faction_`/`factions`, `&"character"`/`char_`/`characters`, `&"enemy"`/`enemy_`/`enemies`, `&"move"`/`move_`/`moves`, `&"combo"`/`combo_`/`combos`, `&"item"`/`item_`/`items`, `&"bindings"`/`bindings_`/`bindings` (ADR-0003 registers its validator under `&"bindings"`), `&"faction_rule"`/`rule_`/`faction_rules` (ADR-0011), `&"map"`/`map_`/`maps`, `&"encounter"`/`enc_`/`encounters`, `&"occupation_stage"`/`ostage_`/`occupation_stages` (ADR-0012), and QuirkState in `quirks` (ADR-0001 diagram). The QuirkState type name is not pinned by any ADR: use `&"quirk_state"` and record it in the Completion Notes. The `encounters` and `occupation_stages` directory names are inferred from the plural rule. Confirm them at `/story-readiness`.

**Discovery.** `load_all()` walks **only the type subdirectories in the table** under the data root, using `ResourceLoader.list_directory()` per directory and recursing into its subdirectories. It must not sweep the whole data root: `data/config/` and `data/ui/` hold config resources (e.g. `StatsConfig`) that are not content records. Never `DirAccess`. A missing type directory is not an error (story 004).

**Catalog API (`src/data/content_catalog.gd`, `class_name ContentCatalogService extends Node`, autoload `ContentCatalog` in `project.godot`).** Per ADR-0001 Key Interfaces and its Amendment 2026-10-23:
- `enum State { UNLOADED, LOADING, VALIDATING, READY, FAILED }`; `var state` starts `UNLOADED` in its field initializer. `_ready()` is not defined (ADR-0004 §3).
- `func load_all(data_root: String = "res://data") -> Error`: returns `OK` on Ready, `FAILED` on Failed, `ERR_ALREADY_IN_USE` (changing nothing) on a second call. The injectable root is how every test loads `res://tests/unit/content_data/fixtures/<name>/`.
- `get_record(type: StringName, id: String) -> Resource`, `has_record(type, id) -> bool`, `all_records(type) -> Array[Resource]` (sorted by `id`), `resolve_alias(id: String) -> String`.
- `var last_lookup_error: StringName`: `&""` after a successful lookup; otherwise `&"not_ready"`, `&"unknown_type"` or `&"missing_id"`. A failing lookup returns the type's empty value (`null`, `false`, `[]`, `""`) and calls `push_error()`. Implement this channel here. Stories 005, 007 and 009 test it.
- `get_record` and `all_records` return `duplicate_deep()` copies (story 006 tests it).
- `register_known_effect_types(system: StringName, types: PackedStringArray) -> void` and `register_record_validator(type: StringName, validator: Callable) -> void` (ADR-0004 §4). A validator returns `Array[Dictionary]` entries (`severity`, `field`, `message`, optional `related_locations`). The catalog fills `record_id` and `location` and adds them to the report. Registration after `load_all()` has started is rejected. Build the skeleton here. Story 016 exercises it in full.
- `var report: Array[Dictionary]`: the validation report, one entry per problem, in the GDD's **Entry shape**: `severity` (`&"error"` / `&"warning"`), `record_id`, `field` (empty when the whole record is at fault), `location` `{file_path, record_index}`, `message`, `related_locations` (array, empty unless the problem spans several places). Every validation story asserts on these fields, never on `message`. `record_index` is 0 for a one-record file.
- Validation in this story is only what AC-1 needs to reach Ready on a valid set: the `null` check on load, filename = `id`, and the type table. Every other rule has its own story.

**Bootstrap (`src/boot/content_bootstrap.gd`, `class_name ContentBootstrap`).** `static func run(catalog: ContentCatalogService, data_root: String = "res://data")`: a no-op unless `catalog.state == UNLOADED`; otherwise it runs the registrant steps from ADR-0004 §1 (as amended by ADR-0007, ADR-0011 and ADR-0013), then `catalog.load_all(data_root)`. Only registrants whose code exists get a line now. Each later story or epic that adds a registrant (Turn Battle effect types, `FactionRuleRegistry` in story 017, `InputBindingsValidator`, Stats validators, `LocFieldsValidator`) adds its own line here. The `data_root` pass-through is an additive default parameter that ADR-0004's Key Interfaces does not show yet. Story 027's `--data-root=` needs it. Record it in the Completion Notes for technical-director to annotate in ADR-0004.

**Test discipline.** Each test builds a fresh `ContentCatalogService.new()` (never the autoload), calls `load_all(fixture_root)` directly (allowed for the catalog's own unit tests, ADR-0004 Implementation Guidelines) and frees the node in teardown. Fixtures are `.tres` files under the test root, never inline data (GDD AC preamble). Fixture layout mirrors `data/`: `tests/unit/content_data/fixtures/<fixture>/<type_dir>/<id>.tres`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: sort determinism and the discovery-order seam.
- Story 004: empty and absent directories.
- Stories 005, 007, 009: the lookup error channel's tests.
- Story 006: the deep-copy mutation test.
- Stories 010–023: every validation rule beyond the `null` check and filename = `id`.
- `LocFieldsValidator` (`src/loc/loc_fields_validator.gd`) and its registration: ADR-0013's own implementation. This story only declares the constants on each record script and tests them structurally.
- `GameRoot._enter_tree()` calling `ContentBootstrap.run()`: `production/epics/game-state-scene-flow/`.

---

## Files

- `src/data/content_catalog.gd` (`class_name ContentCatalogService`)
- `src/data/records/faction_data.gd`, `character_data.gd`, `enemy_data.gd`, `move_data.gd`, `quirk_state_data.gd`, `combo_data.gd`, `item_data.gd`, `input_bindings.gd` (class `InputBindings`, the ADR-0003 name), `faction_rule_data.gd`, `map_data.gd`, `encounter_data.gd`, `occupation_stage_data.gd`
- `src/boot/content_bootstrap.gd`
- `project.godot` (`[autoload]` entry `ContentCatalog`)
- `tests/unit/content_data/fixtures/valid_one_of_each/` (12 `.tres` files, one per type directory)
- `tests/unit/content_data/content_data_load_test.gd`
- `tests/unit/content_data/content_data_loc_fields_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS resolved by the ADR-0001 amendment of 2026-10-23). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: One record of each of the 12 types loads Ready and round-trips deep-equal.
  - Given: `res://tests/unit/content_data/fixtures/valid_one_of_each/` holds one valid record per type. Every list field is non-empty (`move_ids`, `aliases`, `ref_ids`, `encounter_zone_ids`, `enemy_ids`, `required_state_ids`), and the Move and QuirkState each carry at least two EffectDescriptors with nested parameters. Every non-root record is referenced by another record in the set, and every reference resolves to the right type, so no warning or error fires once later stories add their rules.
  - When: a fresh `ContentCatalogService` runs `load_all(fixture_root)` (or `ContentBootstrap.run(catalog, fixture_root)`).
  - Then: the return value is `OK`; `state == READY`; the report holds 0 error entries; and for each of the 12 types, `get_record(type, id)` deep-equals the fixture on every exported field, compared field by field against `ResourceLoader.load(fixture_path, "", ResourceLoader.CACHE_MODE_IGNORE)`, including `move_ids` and every `effects[*]` dictionary.
  - Edge cases: `last_lookup_error == &""` after each successful lookup. `has_record(type, id)` is `true` for all 12.
- **T-LOC (TR-content-012, folded in; no GDD AC)**: Every string-typed export is in exactly one localization list.
  - Given: the 12 record scripts under `src/data/records/`.
  - When: the test reads each script's `get_script_property_list()`, filtered to `PROPERTY_USAGE_STORAGE` exports of type `TYPE_STRING`, `TYPE_STRING_NAME` or `TYPE_PACKED_STRING_ARRAY`.
  - Then: each such property name is in exactly one of `LOC_FIELDS` / `NON_LOC_FIELDS`; the two lists do not intersect; and every name in either list is a real export of that script (no stale entries). Text-holding `Dictionary` exports (`FactionRuleData.texts`) are in `LOC_FIELDS`.
  - Edge cases: a script with no string exports still declares both constants (possibly empty), so the check is uniform.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content_data/content_data_load_test.gd` and `tests/unit/content_data/content_data_loc_fields_test.gd` — must exist and pass (`/story-done` checks that they EXIST; pass/fail is established by `/gate-check` and `/smoke-check`, both later). Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-001-install-gdunit4.md`
- Unlocks: `production/epics/content-catalog/story-003-all-records-sorted-by-id.md`, `story-004-empty-catalog-ready.md`, `story-005-lookup-not-found-and-unknown-type.md`, `story-006-returned-records-are-deep-copies.md`, `story-007-lookups-error-before-ready.md`, `story-010-id-format-validation.md`, `story-014-reference-validation.md`, `story-015-structure-validation.md`, `story-018-faction-field-rules.md`, `story-021-effect-descriptor-passthrough.md`, `story-022-unparsable-file.md`, `story-030-exported-build-discovery.md` (all under `production/epics/content-catalog/`)
