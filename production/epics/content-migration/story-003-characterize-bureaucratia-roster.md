# Story 003: The Clerk and Supervisor stat blocks and flags are pinned against today's `BureaucratiaRule` factories (merged with story 004)

> **Epic**: Content Migration
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-27

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: None (Step 0 characterization)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (Migration Step 0, "the five enemy types"). Also ADR-0011: Faction Rule Modifiers (§5, rosters become `Enemy` records).
**ADR Decision Summary**: Today's enemy stat blocks are pinned before the rosters become records, so the later adapter can be proved to build identical combatants.
**ADR Version**: ADR-0001 2026-10-23 · ADR-0011 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "Consumers copy a record's values into their own runtime objects (`Combatant`, `Move`) at construction time."
- Required: "Characterization tests are written against today's hardcoded factories before migration and rerun unchanged after it."
- Guardrail: none (test code).

---

## Acceptance Criteria

*Migration criterion from ADR-0001 Migration Step 0, scoped to this story:*

- [ ] GIVEN `seam.enemy("enemy_clerk")` and `seam.enemy("enemy_supervisor")`, THEN `display_name`, `max_hp`, `max_mp`, `attack`, `defense`, `speed`, `is_enemy`, `is_boss`, and the post-`reset_for_battle()` `hp`/`mp` equal the pinned values (Clerk 40/0/11/6/8, not boss; Supervisor 110/0/15/10/9, boss), and two calls return distinct instances.

*Merged from story 004, 2026-10-24:*

*Migration criterion from ADR-0001 Migration Step 0, scoped to this story:*

- [ ] GIVEN `seam.enemy()` for `enemy_security_drone`, `enemy_middle_manager` and `enemy_ceo`, THEN every stat, `is_enemy`, `is_boss`, and the post-reset `hp`/`mp` equal the pins (36/0/12/8/10; 44/0/10/6/8; 120/0/15/10/9, boss), and repeated calls return distinct instances.

---

## Implementation Notes

*Derived from ADR-0001 Migration Step 0:*

- "Distinct instances" pins the ADR-0001 rule that consumers copy record values into their own runtime objects. A cached shared `Combatant` would let one fight's damage reach the next.
- **The Supervisor's numbers are pinned exactly as shipped** (110 HP, 15 ATK, 10 DEF, 9 SPD). The open balance question (the naive autoplay bot can't beat him) stays open; this test is the guard that it isn't "fixed" in passing.
- After ADR-0011 adds `record_id`, this test does **not** assert it: a Step 0 file can't name a field that doesn't exist yet. Story 024 adds the `record_id` check in its own test file.
- Epic-wide rules: values pinned in `CharacterizationExpected` by running today's code once, never read from `BureaucratiaRule` constants. Seed nothing that isn't needed; nothing time-dependent. **Watch it fail:** change Clerk HP 40 → 41 locally, see the test fail, revert, record it in the Completion Notes.

*Merged from story 004, 2026-10-24:*

*Derived from ADR-0001 Migration Step 0:*

- Same shape as story 003.
- `display_name` is pinned, and it matters here: today the MegaCorp AI branches on `enemy.display_name == "Middle Manager"`. Story 026 moves the branch to `record_id`, and story 006's AI pins prove the result is the same.
- Epic-wide rules: values pinned in `CharacterizationExpected` by running today's code once, never read from `MegaCorpRule` constants. **Watch it fail:** change one pinned production value locally, see the test fail, revert, record it in the Completion Notes. Content is never retuned.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: the MegaCorp roster.
- Story 015: the Enemy records.
- Story 024: the roster adapter and `record_id`.

---

## Files

- `tests/unit/battle/battle_bureaucratia_roster_characterization_test.gd` — created (3 test functions: Clerk/Supervisor stat blocks, distinct instances, no shared state)
- `tests/unit/battle/battle_megacorp_roster_characterization_test.gd` — created (3 test functions: Security Drone/Middle Manager/CEO stat blocks, pinned display name, distinct instances)
- `tests/unit/battle/fixtures/characterization_expected.gd` — modified (`ENEMY_STATS`: all 5 enemies' stat blocks)

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Clerk and Supervisor stat blocks.
  - Given: `seam.enemy(id)` for both IDs.
  - When: `reset_for_battle()`.
  - Then: name, `max_hp`, `max_mp`, `attack`, `defense`, `speed`, `is_enemy`, `is_boss`, `hp` and `mp` equal the fixture (40/0/11/6/8, not boss; 110/0/15/10/9, boss).
  - Edge cases: two calls are `is_not_same`. Damaging one instance (through `seam.arrange_vitals`) leaves the other at full HP.

*Merged from story 004, 2026-10-24:*

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Three stat blocks.
  - Given: `seam.enemy(id)` for the three IDs.
  - When: `reset_for_battle()`.
  - Then: as story 003, for Drone 36/0/12/8/10, Middle Manager 44/0/10/6/8 and CEO 120/0/15/10/9 (boss).
  - Edge cases: `display_name == "Middle Manager"` is pinned exactly. Repeated calls return distinct instances.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_bureaucratia_roster_characterization_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

*Merged from story 004, 2026-10-24:*

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_megacorp_roster_characterization_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-001-characterization-seam.md`
- Unlocks: `production/epics/content-migration/story-009-characterization-regression-gate.md`, `story-015-author-bureaucratia-enemies.md`, `story-024-bureaucratia-roster-adapter.md`

---

## Completion Notes
**Completed**: 2026-10-27
**Criteria**: 2/2 passing
**Deviations**: None
**Watch it fail**: Clerk's max HP was temporarily changed 40 → 41 in `src/battle/factions/bureaucratia.gd`; the Bureaucratia roster test failed (2 assertions). Reverted; `git status` confirmed `src/` was clean again.
**Test Evidence**: `tests/unit/battle/battle_bureaucratia_roster_characterization_test.gd`, `tests/unit/battle/battle_megacorp_roster_characterization_test.gd` — 6/6 passing; full test tree 242/242, 0 errors/failures/orphans
**Reviewed by**: `/code-review` (APPROVED, no changes requested)
