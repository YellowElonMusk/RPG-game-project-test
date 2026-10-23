# Story 025: `make_security_drone()`, `make_middle_manager()` and `make_ceo()` build their Combatants from the MegaCorp enemy records, and the Step 0 suite passes unchanged

> **Epic**: Content Migration
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-005`, `TR-turnbattle-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (Migration Step 3). Also ADR-0011: Faction Rule Modifiers (§5 `Combatant.record_id`; Migration Step 3).
**ADR Decision Summary**: The MegaCorp roster factories keep their shape but become adapters over their Enemy records through the shared `EnemyAdapter`.
**ADR Version**: ADR-0001 2026-10-23 · ADR-0011 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "Static factories become adapters: they read the catalog record and build today's runtime `Move` / `Combatant` objects."
- Required: "Consumers copy a record's values into their own runtime objects (`Combatant`, `Move`) at construction time."
- Forbidden (*Core*): "Nothing in `src/battle/stats/` may reference … any other Feature type."
- Guardrail: construction-time only.

---

## Acceptance Criteria

*Migration criterion from ADR-0001 Migration Step 3, scoped to this story:*

- [ ] GIVEN the catalog READY, WHEN the three `MegaCorpRule` factories run, THEN each returns a new `Combatant` copied from its Enemy record through `EnemyAdapter`, with `record_id` set, and story 009's gate passes (004, 006 and 008 green, unchanged).

---

## Implementation Notes

*Derived from ADR-0001 Migration Step 3; same rules as story 024:*

- Reuse `EnemyAdapter` from story 024. No fallback to the constants; an unknown ID fails loudly (`push_error`, `null`).
- After this story, MegaCorp's AI still branches on `display_name`, and it still works because the record's display name is unchanged. Story 026 moves the branch to `record_id`.
- The constants stay until story 031 deletes them.
- **Closing condition:** story 009's gate passes, the Step 0 suite green and its files' hashes unchanged; editing a characterization test or the frozen fixture is never the fix. Re-run in a fresh process.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 026: keying the AI on `record_id`.
- Story 031: deleting the MegaCorp constants.
- Story 034: deleting the factories.

---

## Files

- `src/battle/factions/megacorp.gd` (factory bodies)
- `tests/unit/battle/battle_enemy_adapter_test.gd` (MegaCorp cases)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Three factories read records; the gate passes.
  - Given: the catalog READY on `res://data`.
  - When: each of the three factories runs.
  - Then: as story 024, for the Drone, Middle Manager and CEO, with `record_id` set.
  - Edge cases: the Middle Manager's AI branch still works (006 green) because the display name is unchanged. Story 009's gate passes (004, 006, 008).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_enemy_adapter_test.gd` (MegaCorp cases) — must exist and pass, and story 009's gate passes. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-009-characterization-regression-gate.md`, `story-016-author-megacorp-enemies.md`, `story-024-bureaucratia-roster-adapter.md`
- Unlocks: `production/epics/content-migration/story-026-faction-rule-decisions-from-records.md`, `story-031-delete-megacorp-constants.md`, `story-034-delete-roster-factories.md`
