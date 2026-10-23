# Epic: Content Migration

> **Layer**: Foundation
> **GDD**: design/gdd/content-data-definitions.md
> **Architecture Module**: Content Data Definitions (the ADR-0001 Migration Plan: legacy battle factories → catalog records)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories content-migration`

## Overview

Today's MVP battle content lives in code. Characters, enemies, moves and the two
factions are built by static factories in `src/battle/` (`BureaucratiaRule.make_clerk()`
and friends), so it never meets the catalog's validation. This epic moves that content
into catalog records without changing any battle result, following ADR-0001's
Migration Plan:
- **Step 0: characterization tests first.** Before any factory code changes, tests under `tests/unit/battle/` pin today's behaviour: every combatant's stats, every move's effect, and the outcomes of scripted fights. These tests are the safety net for the rest of the epic, and they only touch today's code, so this step can start on day one, right after test setup.
- **Step 2: author the records.** Write `.tres` records for the existing squad, enemies, moves and factions (Bureaucratia, MegaCorp), plus their `faction_rule` records (ADR-0011).
- **Step 3: factories become adapters.** Each factory reads its catalog record and builds the runtime `Combatant`/`Move`. `BattleCore` never touches a record. The characterization tests must still pass unchanged.
- **Steps 4–5: delete the hardcoded data** and the now-unused factory bodies once every caller reads the catalog.

**Dependencies.** Steps 2–5 need `content-catalog` done. When this epic finishes, it
unblocks `game-state-scene-flow` Step 3, which deletes the interim
`TransitionConfig.validate_enemy_ids_against_catalog = false` flag (ADR-0002 §8).

**Risks.**
- Behaviour drift during the factory switch is the main risk; Step 0 exists to catch it.
- TR-stats-005 (`Enemy.reward` ranges) lands with this migration (ADR-0007 §7).
- The open balance question (the naive autoplay bot can't beat the Bureaucratia Supervisor) is not changed by this epic. Content must be moved as-is, not retuned.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0001: Content Data storage format | Migration Plan Steps 0, 2–5; factories become adapters over records | MEDIUM |
| ADR-0007: Stats & Damage Resolution (§7) | Stats range validators registered through `ContentBootstrap`; `Enemy.reward` ranges with the enemy-record migration | LOW |
| ADR-0011: Faction Rule Modifiers | Faction rules as `faction_rule` records referenced by `Faction.rule_id` | LOW |
| ADR-0010: Turn Battle System | `BattleFactory` builds battles from records and the Encounter descriptor | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-content-005 | ID-only references; asset IDs, never paths (applied to the migrated content) | ADR-0001 ✅ |
| TR-content-006 | Data-only records; the migrated EffectDescriptors stay uninterpreted until their owner reads them | ADR-0001, ADR-0004 ✅ |
| TR-content-011 | Migrated stat and reward values are validated against their owners' ranges | ADR-0001, ADR-0007 §7 ✅ |
| TR-stats-005 | `Enemy.reward` ranges validated once enemies are records | ADR-0007 ⚠️ partial (lands with this migration) |

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Characterization tests (Step 0) pass unchanged before and after the factory switch
- No battle content remains hardcoded in `src/battle/`; every runtime `Combatant`/`Move` is built from a catalog record
- `tools/ci/validate-content.gd` passes on the migrated data set
- Logic and Integration stories have passing tests in the test root
