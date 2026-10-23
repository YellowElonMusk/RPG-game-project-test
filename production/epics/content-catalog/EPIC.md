# Epic: Content Catalog

> **Layer**: Foundation
> **GDD**: design/gdd/content-data-definitions.md
> **Architecture Module**: Content Data Definitions (`ContentCatalog`, record classes) + Content Boot Ordering (`ContentBootstrap`, composition-root code under `src/boot/`)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories content-catalog`

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

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/content-data-definitions.md verified (AC-1 to AC-28; AC-25 advisory)
- Logic and Integration stories have passing tests in the test root
- Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/`
  (a lead sign-off too for Visual/Feel)
