# Epic: Content Catalog

> **Layer**: Foundation
> **GDD**: design/gdd/content-data-definitions.md
> **Architecture Module**: Content Data Definitions (`ContentCatalog`, record classes) + Content Boot Ordering (`ContentBootstrap`, composition-root code under `src/boot/`)
> **Status**: Ready
> **Stories**: 30 (28 Ready, 2 Blocked on game-state-scene-flow) — see the table below

## Overview

This epic builds the data backbone every other system reads: the `ContentCatalog`
autoload, the record classes, `ContentBootstrap`, validation and the CI tooling. It
is the first epic in the build order because Input (its `bindings_` record), Game
State (its Boot and Content Error modes), Faction Rules, the Overworld and every
content-driven Core system depend on a catalog that loads, validates and fails
loudly.

**What it implements (from the GDD and ADR-0001/0004):**
- **Record types.** Twelve `Resource` subclasses, one per non-reserved type in the GDD's Rule 1: Faction, Character, Enemy, Move, QuirkState, Combo, Item, InputBindings, FactionRule (`rule_`, ADR-0011 §5), Map, Encounter and OccupationStage (ADR-0012 §3). Each type's schema is exactly its `@export` list. One record is one `.tres` file at `data/[type_plural]/[id].tres`.
- **The catalog.** `ContentCatalog` is an autoload singleton (the one documented exception to dependency injection), with the state machine Unloaded → Loading → Validating → Ready | Failed (both terminal) and the lookup API `get_record` / `has_record` / `all_records` / `resolve_alias`. Files are discovered with `ResourceLoader.list_directory()`, never `DirAccess`.
- **Boot ordering.** `ContentBootstrap.run()` is called from `GameRoot._enter_tree()` (ADR-0004). It registers every vocabulary and record validator, then loads. Later ADRs add their registrant lines here (Stats ranges ADR-0007, faction rule classes ADR-0011, presentation profiles ADR-0005 §14, Overworld validators ADR-0012). This epic owns `ContentBootstrap` and its registration API. `GameRoot` itself belongs to `game-state-scene-flow`.
- **Validation.** Full-set validation in two severities (errors fail the catalog), structured entries `(severity, record_id, field, location)` in a deterministic, OS-independent order, the range table (F2) with bounds read from each owner's constants, uniqueness rules, alien-only faction fields, unknown-field detection against the `@export` list. This epic defines the **error-report data format** only; the Content Error *scene* is built by `game-state-scene-flow`.
- **CI tooling.** `tools/ci/validate-content.gd` is a headless check (exit 0 on valid data, 1 on errors). The checked-in **ID manifest** makes CI fail when an ID vanishes without an alias.
- **Localization.** Player-visible record text is `LocText` (ADR-0013).

**Story 1 is test setup:** run `/test-setup` and install gdUnit4. It blocks every
Logic story in all four Foundation epics.

**Risks.** TR-content-007/008/010 are only partly covered by ADR-0001:
- immutability after Ready is protected by discipline, so a story must add a mutation test (GDD AC);
- the report entry format is pinned in the GDD, not in an ADR;
- the 500-record benchmark is advisory until it is run on the `min_spec` machine.

The engine risk is LOW–MEDIUM. `ResourceLoader.list_directory()` was verified in the editor on 4.7.2 and must be re-verified against an exported build (control manifest).

**Build order.** Test setup → this epic. `content-migration` Step 0 (characterization
tests) can run alongside it. `input-system` and `game-state-scene-flow` Step 1 follow.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0001: Content Data storage format | `Resource` subclasses as `.tres`, ID-string references, autoload catalog, `ResourceLoader.list_directory()` discovery | MEDIUM |
| ADR-0004: Content Boot Ordering | `ContentBootstrap.run()` in `GameRoot._enter_tree()` registers vocabularies and validators before `load_all()` | LOW |
| ADR-0011: Faction Rule Modifiers (§5) | Defines the `faction_rule` record type (`rule_`) and its validator registration | LOW |
| ADR-0012: Overworld (§3) | Adds the `map`, `encounter`, `occupation_stage` record types and `faction.patrol_archetype_id` | LOW |
| ADR-0013: Localization | Player-visible record text is `LocText` with gettext context `<record_id>.<field>` | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-content-001 | 12 record types plus reserved types; permanent lowercase snake_case IDs with type prefix, max 64 chars, unique; aliases resolve one hop only | ADR-0001, ADR-0003, ADR-0011, ADR-0012 ✅ |
| TR-content-002 | Catalog state machine Unloaded → Loading → Validating → Ready or Failed; Ready and Failed terminal; lookups error outside Ready | ADR-0001 ✅ |
| TR-content-003 | Full-set validation, two severities, any error fails the catalog; standalone headless check (exit 0/1) | ADR-0001, ADR-0004 ✅ |
| TR-content-004 | Lookup API `get_record`, `has_record`, `all_records` (sorted), `resolve_alias` | ADR-0001 ✅ |
| TR-content-005 | ID-only references, asset IDs; the catalog never names a file path | ADR-0001 ✅ |
| TR-content-006 | Data-only records; EffectDescriptor vocabulary registered by owners before validation | ADR-0001, ADR-0004 ✅ |
| TR-content-007 | Immutable after Ready; caller mutation never leaks | ADR-0001 ⚠️ partial (discipline only) |
| TR-content-008 | Structured entries, deterministic order, error screen first `ERROR_SCREEN_CAP`, log holds all | ADR-0001 ⚠️ partial (format in the GDD only) |
| TR-content-009 | Game State waits for Ready; a Failed catalog never reaches gameplay | ADR-0001, ADR-0002, ADR-0004 ✅ |
| TR-content-010 | 500 generated records load + validate in median < 1.0 s over 10 runs | ADR-0001 ⚠️ partial (benchmark advisory) |
| TR-content-011 | Field ranges read from the owning system's constants | ADR-0001, ADR-0007 §7 ✅ |
| TR-content-012 | Player-visible strings extractable for localization | ADR-0013, ADR-0008 §11 ✅ |

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Install gdUnit4 and prove the runner discovers and passes one test | Config/Data | Ready | ADR-0001 |
| 002 | Load one record of each of the 12 types and get every field back deep-equal | Logic | Ready | ADR-0001 |
| 003 | `all_records(type)` returns records sorted by ID, whatever the discovery order | Logic | Ready | ADR-0001 |
| 004 | A zero-record data set loads Ready with an empty list for every type | Logic | Ready | ADR-0001 |
| 005 | A missing ID returns not-found, and an unknown type returns an error, not an empty list | Logic | Ready | ADR-0001 |
| 006 | A caller's edit to a returned record, including nested lists and descriptors, never leaks back | Logic | Ready | ADR-0001 |
| 007 | Any lookup during Unloaded, Loading or Validating returns an error | Logic | Ready | ADR-0001 |
| 008 | A second load request on a Ready or Failed catalog is rejected and changes nothing | Logic | Ready | ADR-0001 |
| 009 | One error anywhere fails the whole catalog, even for records that were valid themselves | Logic | Ready | ADR-0001 |
| 010 | A malformed ID is an error naming it; 64 characters loads, 65 does not | Logic | Ready | ADR-0001 |
| 011 | Two records sharing one ID produce exactly one error, located at the first file, with the other in `related_locations` | Logic | Ready | ADR-0001 |
| 012 | `resolve_alias` resolves a record's declared alias to its live ID | Logic | Ready | ADR-0001 |
| 013 | Alias rules: a shadowing alias and a doubly declared alias each error; an alias reference resolves in one hop | Logic | Ready | ADR-0001 |
| 014 | Missing, wrong-type, self- and cyclic references, and a duplicate list entry, each error | Logic | Ready | ADR-0001 |
| 015 | Unknown, missing, wrong-typed, empty and whitespace-only fields, and an unknown descriptor type, each error naming record and field | Logic | Ready | ADR-0001 |
| 016 | Registered range validators reject every F2 boundary outside its bound and accept it at the bound | Logic | Ready | ADR-0001 |
| 017 | Two new-game-entry maps, a duplicate (faction, stage) pair and a human `patrol_archetype_id` each error; a registered `faction_rule` loads | Logic | Ready | ADR-0012 |
| 018 | An alien-only field on a human nation, and a `base_shape` that does not match `kind`, each error | Logic | Ready | ADR-0001 |
| 019 | A shared alien colour, a shared alien shape, a duplicated signature move and an unreferenced record each warn, and the catalog stays Ready | Logic | Ready | ADR-0001 |
| 020 | Two errors and two warnings fail the catalog, and the report carries all four with the right severities | Logic | Ready | ADR-0001 |
| 021 | A Move's EffectDescriptors round-trip untouched, and loading triggers no game effect | Logic | Ready | ADR-0001 |
| 022 | An unparsable file is one error naming it, and validation still reports the other files' errors | Logic | Ready | ADR-0001 |
| 023 | A fixture triggering five rules gives five errors, in the same order on every run | Logic | Ready | ADR-0001 |
| 024 | Build the capped error-screen text and the full log text from a 30-error report | Logic | Ready | ADR-0001 |
| 025 | On launch with 30 errors, the player sees the plain-text error screen, never a crash or blank screen | UI | Blocked (needs game-state-scene-flow) | ADR-0001 |
| 026 | A Failed catalog keeps Game State in its boot state, never reaching overworld or battle | Integration | Blocked (needs game-state-scene-flow) | ADR-0001 |
| 027 | The headless validation check exits 0 on valid data, and 1 with the full report on any error | Integration | Ready | ADR-0001 |
| 028 | CI fails on an ID that vanished without an alias, passes once it is aliased, and the old ID resolves through the alias | Integration | Deferred | ADR-0001 |
| 029 | 500 generated records load and validate with a median under 1.0 s over 10 runs (advisory) | Config/Data | Deferred | ADR-0001 |
| 030 | In an exported Windows build, `ResourceLoader.list_directory()` finds every record | Integration | Deferred | ADR-0001 |
## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/content-data-definitions.md verified (AC-1 to AC-28; AC-25 advisory)
- Logic and Integration stories have passing tests in the test root
- Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/`
  (a lead sign-off too for Visual/Feel)
