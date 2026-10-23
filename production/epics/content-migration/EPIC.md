# Epic: Content Migration

> **Layer**: Foundation
> **GDD**: design/gdd/content-data-definitions.md
> **Architecture Module**: Content Data Definitions (the ADR-0001 Migration Plan: legacy battle factories → catalog records)
> **Status**: Ready
> **Stories**: 35 (26 Ready, 9 Blocked) — see the table below

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

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Characterization seam builds every shipped enemy, move and rule by record ID](story-001-characterization-seam.md) | Logic | Ready | ADR-0001, ADR-0011 |
| 002 | [Squad specials' fields and effects pinned](story-002-characterize-squad-specials.md) | Logic | Ready | ADR-0001, ADR-0007 |
| 003 | [Clerk and Supervisor stat blocks pinned](story-003-characterize-bureaucratia-roster.md) | Logic | Ready | ADR-0001 |
| 004 | [Security Drone, Middle Manager and CEO stat blocks pinned](story-004-characterize-megacorp-roster.md) | Logic | Ready | ADR-0001 |
| 005 | [Named attacks, Attack and Home Run damage matrix pinned](story-005-characterize-moves-damage.md) | Logic | Ready | ADR-0001, ADR-0007 |
| 006 | [Both faction rules' decisions pinned](story-006-characterize-faction-rule-decisions.md) | Logic | Ready | ADR-0011 |
| 007 | [Both faction rules' presentation pinned](story-007-characterize-faction-rule-presentation.md) | Logic | Ready | ADR-0011 |
| 008 | [Scripted fights pinned end to end](story-008-characterize-scripted-fights.md) | Logic | Ready | ADR-0001, ADR-0010 |
| 009 | [Characterization regression gate (SHA-256 manifest)](story-009-characterization-regression-gate.md) | Logic | Ready | ADR-0001 |
| 010 | [Register the six migrated effect types](story-010-register-migrated-effect-types.md) | Logic | Ready | ADR-0001, ADR-0004 |
| 011 | [Register the shipped rule classes and validators](story-011-register-shipped-rule-classes.md) | Logic | Ready | ADR-0011 |
| 012 | [Register StatsValidators](story-012-register-stats-validators.md) | Logic | Blocked | ADR-0007 |
| 013 | [Faction records](story-013-author-faction-records.md) | Config/Data | Ready | ADR-0001 |
| 014 | [Enemy named-attack Move records](story-014-author-enemy-named-attack-moves.md) | Config/Data | Ready | ADR-0001, ADR-0011 |
| 015 | [Bureaucratia Enemy records](story-015-author-bureaucratia-enemies.md) | Config/Data | Ready | ADR-0001, ADR-0011 |
| 016 | [MegaCorp Enemy records](story-016-author-megacorp-enemies.md) | Config/Data | Ready | ADR-0001, ADR-0011 |
| 017 | [`faction_rule` records](story-017-author-faction-rule-records.md) | Config/Data | Ready | ADR-0011 |
| 018 | [Squad-special Move records (provisional)](story-018-author-squad-special-moves.md) | Config/Data | Ready | ADR-0001 |
| 019 | [Squad Character records](story-019-author-squad-character-records.md) | Config/Data | Blocked | ADR-0001 |
| 020 | [Enemy reward range validation](story-020-enemy-reward-range-validation.md) | Logic | Blocked | ADR-0007 |
| 021 | [Migrated set validates clean](story-021-migrated-set-validates-clean.md) | Integration | Ready | ADR-0001 |
| 022 | [No file paths in migrated records](story-022-migrated-records-no-paths.md) | Logic | Ready | ADR-0001 |
| 023 | [Move record adapter](story-023-move-record-adapter.md) | Logic | Ready | ADR-0001, ADR-0010 |
| 024 | [Bureaucratia roster adapter](story-024-bureaucratia-roster-adapter.md) | Logic | Ready | ADR-0001, ADR-0011 |
| 025 | [MegaCorp roster adapter](story-025-megacorp-roster-adapter.md) | Logic | Ready | ADR-0001, ADR-0011 |
| 026 | [Rule decisions from records](story-026-faction-rule-decisions-from-records.md) | Logic | Blocked | ADR-0011 |
| 027 | [Rule presentation from records](story-027-faction-rule-presentation-from-records.md) | Logic | Blocked | ADR-0011, ADR-0013 |
| 028 | [Squad specials adapter](story-028-squad-specials-adapter.md) | Logic | Ready | ADR-0001 |
| 029 | [BattleFactory reads enemy records](story-029-battle-factory-reads-enemy-records.md) | Integration | Blocked | ADR-0010, ADR-0011 |
| 030 | [Delete Bureaucratia constants](story-030-delete-bureaucratia-constants.md) | Logic | Ready | ADR-0011 |
| 031 | [Delete MegaCorp constants](story-031-delete-megacorp-constants.md) | Logic | Ready | ADR-0011 |
| 032 | [Delete squad-special constants](story-032-delete-squad-special-constants.md) | Logic | Ready | ADR-0001 |
| 033 | [Delete `is_manager()`](story-033-delete-is-manager.md) | Logic | Blocked | ADR-0011 |
| 034 | [Delete the roster factories](story-034-delete-roster-factories.md) | Integration | Blocked | ADR-0011 |
| 035 | [Battle content CI lint](story-035-no-hardcoded-battle-content-lint.md) | Logic | Blocked | ADR-0011 |

**Step numbering.** The stories follow this EPIC's phases (Step 0 characterization, Step 2 author the records, Step 3 factories become adapters, Steps 4–5 delete the hardcoded data), not ADR-0001's step numbers, which differ. Each story cites the ADR-0001 step it implements. ADR-0001's Step 5 (pointing the regression check at the Step 0 tests) is story 009, pulled forward so every later story can close on it. ADR-0001 Step 4's squad-special records and adapter are stories 018 and 028. The deletion stories (030–035) are driven by ADR-0011 Migration Step 4.

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Characterization tests (Step 0) pass unchanged before and after the factory switch
- No battle content remains hardcoded in `src/battle/`; every runtime `Combatant`/`Move` is built from a catalog record
- `tools/ci/validate-content.gd` passes on the migrated data set
- Logic and Integration stories have passing tests in the test root
