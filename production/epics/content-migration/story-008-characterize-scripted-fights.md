# Story 008: Scripted fights against each faction's shipped roster produce the pinned outcome sequence, per-action HP/MP, result and final RNG state

> **Epic**: Content Migration
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-28

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: None (Step 0 characterization)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (Migration Step 0, "outcomes of scripted fights"). Also ADR-0007: Stats & Damage Resolution (Migration Step 0, "for whole battles…") and ADR-0010: Turn Battle System (Migration Step 1: "acceptance of each command, the outcome log, signal order and carryover").
**ADR Decision Summary**: Whole fights against the shipped rosters under the shipped rules are pinned end to end, so any drift introduced by the record migration shows up as a changed log, vitals, result or RNG state.
**ADR Version**: ADR-0001 2026-10-23 · ADR-0007 2026-10-22 · ADR-0010 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "Characterization tests are written against today's hardcoded factories before migration and rerun unchanged after it."
- Required (*Core*): "A non-resolving move changes no state, carries exactly one record, is appended to `outcome_log`, and is not emitted on `action_resolved`" (why the log is filtered to RESOLVED).
- Guardrail: none (test code).

---

## Acceptance Criteria

*Migration criterion from ADR-0001/ADR-0007 Migration Step 0 and ADR-0010 Migration Step 1, scoped to this story:*

- [ ] GIVEN a seeded `BattleCore` with the four-member fixture squad against (a) `enemy_clerk`, `enemy_clerk`, `enemy_supervisor` under `rule_bureaucratia_permit` and (b) `enemy_security_drone`, `enemy_middle_manager`, `enemy_ceo` under `rule_megacorp_billing`, driven by a fixed command script through `submit_action()` (each special once, a Defend, and a rejected command: a Special in round 1 under Bureaucratia; every other Bureaucratia Special in round ≥ 4; every MegaCorp Special placed while its user's MP covers its cost; one MegaCorp suspension), with each command's `target_index` resolving as `min(i, living.size() - 1)`, WHEN the fight runs to `battle_ended` or `ROUND_CAP = 20`, THEN the ordered `seam.resolved_log(battle)` (`actor`, `move_name`, `category`, `target`, `hp_delta`, `mp_delta`, `target_knocked_out`, `round_number`), every combatant's `hp`/`mp` after each `action_resolved`, the signal log (`turn_started`/`action_resolved`/`round_advanced`/`battle_ended` names in order), the number of script commands consumed, the `battle_ended(won)` value, and `rng.state` at the end all equal the pins.

---

## Implementation Notes

*Derived from ADR-0001 Migration Step 0, ADR-0010 Migration Step 1 and the QA gate:*

- **Type choice.** It spans `BattleCore`, both rules, `SquadSpecials` and `DamageCalculator`, which looks like Integration, but all are one module (`src/battle/`) and ADR-0001 fixes Step 0's location as `tests/unit/battle/`. It is typed Logic so its evidence path matches. Change to Integration (and move to `tests/integration/battle/`) only if `/story-readiness` prefers the type rule over the ADR's path.
- **Pin the loss if it loses.** If the scripted squad loses to the Supervisor, the pinned result is `won = false`. That is the open balance question, and it stays open. Choose the script for coverage (every move kind, both permit phases, a suspension), not for a win.
- Command scripts pick targets by index into `get_living_enemies()`/`get_living_squad()` at submit time, never by object identity, so a rebuilt combatant set can follow the same script. Out-of-range indices clamp to `living.size() - 1`.
- **Only `RESOLVED` entries count.** ADR-0007 Step 4 adds log-only `NO_TARGET`/`UNAFFORDABLE` entries. The filter lives in the seam (`seam.resolved_log(battle)`, added here): filter on `result` when it exists, accept all entries before it does. The test doesn't change when the field appears.
- Signal order is recorded as a log and pinned; ADR-0006's replay depends on it.
- Also pin a `start_battle(false)` carryover case: a second fight whose combatants have the first fight's end vitals copied in through `seam.arrange_vitals`.
- Epic-wide rules: `ROUND_CAP`, the seeds (`SEED_FIGHT_B`, `SEED_FIGHT_M`) and every expected value are fixture constants pinned by running today's code once; **watch it fail** (change one enemy stat locally, see the log pin fail, revert, record it). Content is never retuned.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Stories 002, 005, 006: per-move and per-decision pins.
- Story 029: `BattleFactory` building fights from records.
- Story 034: switching demo and chapter callers.

---

## Files

- `tests/unit/battle/battle_scripted_fight_characterization_test.gd` — created (3 test functions: Bureaucratia fight, MegaCorp fight, start_battle(false) carryover)
- `tests/unit/battle/fixtures/scripted_fight_commands.gd` — created (BUREAUCRATIA, MEGACORP command scripts; constants only)
- `tests/unit/battle/fixtures/characterization_expected.gd` — modified (fights block: ROUND_CAP, SEED_FIGHT_B/M, BUREAUCRATIA_FIGHT, MEGACORP_FIGHT)
- `tests/unit/battle/helpers/battle_content_seam.gd` — modified (adds resolved_log(battle))

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, revisions applied: `ROUND_CAP = 20`, target-index clamp, Special placement, signal log and commands consumed in the criterion). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Scripted fights equal the pins.
  - **Test: Bureaucratia fight.**
    - Given: the fixture squad against Clerk, Clerk, Supervisor, `SEED_FIGHT_B`, and `ScriptedFightCommands.BUREAUCRATIA`.
    - When: it runs to `battle_ended` or the cap.
    - Then: `seam.resolved_log(battle)`, hp/mp per `action_resolved`, `won`, the signal log, the commands consumed and the final `rng.state` equal the pins.
    - Edge cases: if the result is `won = false`, that loss is pinned and not "fixed". The rejected command returns `null` and leaves no log entry.
  - **Test: MegaCorp fight.**
    - Same with `SEED_FIGHT_M`, including one suspension (a member at MP 0 whose non-Attack command is rejected).
  - **Test: carryover.**
    - Given: a second `BattleCore` with the end vitals copied in through `arrange_vitals` and `start_battle(false)`.
    - Then: the first turn skips KO members, and the result is pinned.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_scripted_fight_characterization_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-001-characterization-seam.md`
- Unlocks: `production/epics/content-migration/story-009-characterization-regression-gate.md`, `story-029-battle-factory-reads-enemy-records.md`, `story-034-delete-roster-factories.md`

---

## Completion Notes
**Completed**: 2026-10-28
**Criteria**: 1/1 passing
**Deviations**: None
**Watch it fail**: Done twice. Supervisor's attack stat 15 → 16 in `src/battle/factions/bureaucratia.gd` failed 57 assertions. The target-index clamp removed from the test harness failed with 43 errors and 13 failures. Both reverted; `git status` confirmed `src/` and the test file were clean each time.
**Test Evidence**: `tests/unit/battle/battle_scripted_fight_characterization_test.gd` — 3/3 passing; full test tree 271/271, 0 errors/failures/orphans
**Reviewed by**: `/code-review` (CHANGES REQUIRED — clamp unexercised, carryover test incomplete; all fixed and re-verified before close)
