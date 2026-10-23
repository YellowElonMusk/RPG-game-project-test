# Story 021: A Move's EffectDescriptors round-trip untouched, and loading triggers no game effect

> **Epic**: Content Catalog
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (Rule 4; EffectDescriptor adapter; Vocabulary ownership)
**ADR Decision Summary**: Records are data only. The catalog stores EffectDescriptors (`{type, ...params}`) as plain `Array[Dictionary]` and checks that each `type` is in a vocabulary registered by its owning system; it never interprets or runs them. Record classes contain no logic beyond basic getters.
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Confirm on 4.7.2 what `Script.get_script_method_list()` returns for a record script: it should list only methods the script itself declares (not `Resource`'s inherited ones). If it also lists implicit entries (for example, generated setters or the implicit initializer), add those names to the allow-list and record them in the Completion Notes.

**Control Manifest Rules (this layer)**:
- Required: "EffectDescriptors (`effects` fields) are stored as plain `Array[Dictionary]` (`{type, ...params}`), the one non-scalar export."
- Forbidden: "Never put logic in a record class beyond basic getters."
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story (AC-15 as made measurable 2026-10-23):*

- [ ] **AC-15** GIVEN a Move whose effects use only known descriptor types, WHEN loaded, THEN `get_record` returns the descriptors deep-equal to the fixture and loading triggers no game effect: every record script defines no methods beyond getters (checked with `get_script_method_list()`), and a signal monitor attached during load records no signal other than the catalog's own state changes.

---

## Implementation Notes

*Derived from ADR-0001 Rule 4 and the EffectDescriptor adapter section:*

- Register the provisional vocabulary as a test double: `register_known_effect_types(&"turn_battle", ["stun", "heal_party", "heal_single", "damage_debuff", "direct_damage"])`. Turn Battle System owns the real call.
- The catalog copies descriptors as data (`duplicate_deep()`, story 006) and never branches on a descriptor's parameters. Only `type` is checked (story 015).
- **"No game effect", made measurable:**
  - **Methods.** For each of the 12 record scripts, every name in `get_script_method_list()` matches the allow-list: names starting with `get_`, plus `_init`. A record script that needs no getter declares no methods at all.
  - **Signals.** The only signal `ContentCatalogService` may emit during `load_all()` is its own state-change signal, if story 002 added one (e.g. `state_changed`). Nothing else is emitted, and the catalog emits nothing on any other object. Test seams (`file_loaded_hook`, `discovery_order_transform`) are `Callable` properties, not signals, so they do not interfere.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 015: an unknown descriptor type.
- Turning descriptors into runtime `Move` objects: `production/epics/content-migration/` (factory adapters).

---

## Files

- `tests/unit/content_data/fixtures/effect_passthrough/` (a Move with three descriptors of known types, including a nested `Dictionary` and an `Array` parameter, plus a Character that references it)
- `tests/unit/content_data/content_data_effect_passthrough_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS resolved by the measurable rewrite of AC-15). The developer implements against these — do not invent new test cases during implementation.*

- **AC-15 / T1 round-trip**: GIVEN `fixtures/effect_passthrough/` and the five types registered, WHEN loaded, THEN `OK`, `READY`, and `get_record(&"move", id).effects` deep-equals the fixture's `effects` (keys, value types and nesting identical, compared with a `CACHE_MODE_IGNORE` load).
- **AC-15 / T2 methods**: GIVEN the 12 record scripts under `src/data/records/`, WHEN each script's `get_script_method_list()` is read, THEN every method name starts with `get_` or is `_init`.
- **AC-15 / T3 signals**: GIVEN a gdUnit4 signal monitor (`monitor_signals`) on a fresh catalog, WHEN `load_all(fixture_root)` runs, THEN the monitor records no signal other than the catalog's state-change signal (or none at all, if it has none).
- Edge cases: an unregistered descriptor parameter key (e.g. `{type = "stun", rounds = 2, flavour = "x"}`) passes through unchanged. The catalog does not validate parameter names.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content_data/content_data_effect_passthrough_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-002-load-one-of-each-type.md`, `production/epics/content-catalog/story-015-structure-validation.md`
- Unlocks: None
