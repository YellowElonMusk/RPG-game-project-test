# Story 004: The Security Drone, Middle Manager and CEO stat blocks and flags are pinned against today's `MegaCorpRule` factories

> **Epic**: Content Migration
> **Status**: Merged into story 003 (2026-10-24)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: None (Step 0 characterization)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (Migration Step 0). Also ADR-0011: Faction Rule Modifiers (§5).
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

- [ ] GIVEN `seam.enemy()` for `enemy_security_drone`, `enemy_middle_manager` and `enemy_ceo`, THEN every stat, `is_enemy`, `is_boss`, and the post-reset `hp`/`mp` equal the pins (36/0/12/8/10; 44/0/10/6/8; 120/0/15/10/9, boss), and repeated calls return distinct instances.

---

## Implementation Notes

*Derived from ADR-0001 Migration Step 0:*

- Same shape as story 003.
- `display_name` is pinned, and it matters here: today the MegaCorp AI branches on `enemy.display_name == "Middle Manager"`. Story 026 moves the branch to `record_id`, and story 006's AI pins prove the result is the same.
- Epic-wide rules: values pinned in `CharacterizationExpected` by running today's code once, never read from `MegaCorpRule` constants. **Watch it fail:** change one pinned production value locally, see the test fail, revert, record it in the Completion Notes. Content is never retuned.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: the Bureaucratia roster.
- Story 016: the Enemy records.
- Story 025: the roster adapter.
- Story 026: keying the AI on `record_id`.

---

## Files

- `tests/unit/battle/battle_megacorp_roster_characterization_test.gd`
- `tests/unit/battle/fixtures/characterization_expected.gd` (MegaCorp roster block)

---

## QA Test Cases

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
- Logic: `tests/unit/battle/battle_megacorp_roster_characterization_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-001-characterization-seam.md`
- Unlocks: `production/epics/content-migration/story-009-characterization-regression-gate.md`, `story-015-author-bureaucratia-enemies.md`, `story-024-bureaucratia-roster-adapter.md`
