# Story 033: `BureaucratiaRule.is_manager()` is deleted, `SquadSpecials.apply_stun()` reads `is_boss` directly, and the Step 0 suite passes unchanged

> **Epic**: Content Migration
> **Status**: Blocked — BLOCKED: behind story 026 (the rule still references `is_manager()` in its doc examples and the registry path)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-factionrules-002` (no rule-subclass reference outside `src/battle/factions/`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: Faction Rule Modifiers (§5: "`SquadSpecials` reads `Combatant.is_boss` directly. `BureaucratiaRule.is_manager()` is deleted with the migration"; Implementation Guidelines: `SquadSpecials` must never reference a rule subclass)
**ADR Decision Summary**: Feature code outside `src/battle/factions/` must not name a rule subclass; stun immunity reads `is_boss` on the combatant.
**ADR Version**: ADR-0011 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required (Feature, ADR-0011): "`BattleCore`, the Battle mode, `SquadSpecials` and every HUD widget must never reference a rule subclass."
- Guardrail: none.

---

## Acceptance Criteria

*Migration criterion from ADR-0011 §5, scoped to this story:*

- [ ] GIVEN the codebase, THEN no file defines or calls `is_manager`, `SquadSpecials` references no `BureaucratiaRule` symbol, `apply_stun()` returns `false` and leaves `is_stunned` false for any `is_boss` target, and story 009's gate passes (002's Supervisor and CEO immunity pins green, unchanged).

---

## Implementation Notes

*Derived from ADR-0011 §5:*

- The behaviour is identical (`is_manager` already returned `is_boss`). The point is the dependency direction: Feature code outside `factions/` must not name a rule subclass.
- Delete `is_manager` and its doc example from `bureaucratia.gd`; replace the call in `apply_stun()` with `target.is_boss`.
- **Closing condition:** story 009's gate passes, the Step 0 suite green and its files' hashes unchanged; editing a characterization test or the frozen fixture is never the fix.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 032: the specials' constants.
- Story 035: the CI lint that keeps rule-subclass references out.

---

## Files

- `src/battle/squad/specials.gd` (`apply_stun`)
- `src/battle/factions/bureaucratia.gd` (delete `is_manager` and its doc example)
- `tests/unit/battle/battle_no_hardcoded_content_test.gd` (`is_manager` case)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: `is_manager` is gone and bosses stay immune.
  - Given: the codebase and the catalog READY.
  - Then: a grep finds no `is_manager`, and `specials.gd` contains no `BureaucratiaRule`. `apply_stun(boss)` returns false and leaves `is_stunned` false for the Supervisor and the CEO. A Clerk is stunned.
  - Edge cases: story 009's gate passes (002).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_no_hardcoded_content_test.gd` (`is_manager` case) — must exist and pass, and story 009's gate passes. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-002-characterize-squad-specials.md`, `story-009-characterization-regression-gate.md`, `story-026-faction-rule-decisions-from-records.md`
- Unlocks: `production/epics/content-migration/story-035-no-hardcoded-battle-content-lint.md`
