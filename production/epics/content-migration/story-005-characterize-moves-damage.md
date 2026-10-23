# Story 005: Every enemy named attack, Attack and Home Run deals its pinned damage to every shipped stat block under a seeded RNG

> **Epic**: Content Migration
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: None (Step 0 characterization)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (Migration Step 0). Also ADR-0007: Stats & Damage Resolution (Migration Step 0: "every shipped move against the shipped stat blocks, with Defend and Viral Stunt included") and ADR-0011: Faction Rule Modifiers (§5, named attacks become `Move` records).
**ADR Decision Summary**: The damage pipeline's output for every shipped move against every shipped stat block is pinned through `BattleCore` before migration, because ADR-0007 Step 2 deletes `DamageCalculator` and the Step 0 tests must pass unchanged.
**ADR Version**: ADR-0001 2026-10-23 · ADR-0007 2026-10-22 · ADR-0011 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "Characterization tests are written against today's hardcoded factories before migration and rerun unchanged after it."
- Required (*Core*): "The resolver uses `BattleCore.rng`, and never draws for a heal, a skipped target or an invalid effect" (the `rng.state` pins are what 023 and the Stats epic are held to).
- Guardrail: none (test code).

---

## Acceptance Criteria

*Migration criterion from ADR-0001 and ADR-0007 Migration Step 0, scoped to this story (rewritten per QA; the earlier draft's Defend clause is dropped — Defend deals no damage):*

- [ ] GIVEN `BattleCore` built with `seam.scripted_rule()` and `rng.seed = CharacterizationExpected.DAMAGE_SEED`, reseeded per case, WHEN each case in `CharacterizationExpected.DAMAGE_CASES` resolves, THEN `hp_delta`, the target's `hp` and `rng.state` equal the pins. The cases are:
  - (a) **enemy-side:** each named attack from each enemy that can emit it (Pen Jab and Red Tape from Clerk and Supervisor; Late Fee from Clerk; Mass Audit and Final Notice from Supervisor; Laser Scan from Drone; Upsell from Middle Manager; Layoffs and Hostile Takeover from CEO), plus Attack (power 10, the neutral fallback) from each of the 5 enemies, against each of the 4 fixture squad members, with the target plain and Defending: 16 × 4 × 2 = 128 cases.
  - (b) **squad-side:** Attack from each of the 4 members and Home Run from the Baguette Thrower, against each of the 5 enemies, with the target plain, Defending, and under Viral Stunt: 5 × 5 × 3 = 75 cases.
- [ ] In addition, for each named-attack ID, the `Move` the shipped rule emits in story 006's scenarios has `display_name`, `power`, `category`, `mp_cost` and `target_type` equal to `seam.move(id)`.

---

## Implementation Notes

*Derived from ADR-0007 Migration Step 0 and the QA gate (RC-2):*

- **Why the scripted rule (RC-2).** Under the shipped rules several needed cases are unreachable: Bureaucratia enemies Defend only pre-permit, when Specials are banned; MegaCorp enemies never Defend; no enemy owns Viral Stunt. `seam.scripted_rule()` (story 001) lets a case pick its attacker, move and target. The pinned behaviour is the damage and effect pipeline; the shipped rules' decisions stay pinned by 006 and 008.
- Defending is arranged by the target submitting Defend on its turn. The vulnerable state is set by a Florida Man Viral Stunt submitted earlier in the same case. Defending + vulnerable together is not a case (unreachable); omit it.
- This is the "moves" family. ADR-0007 Step 0's `DamageCalculator.calculate_damage()` pins are taken **through `BattleCore`** (Q2).
- `rng.state` after each resolution is pinned (ADR-0007 Step 0). It catches a variance draw that changed order without changing the amount.
- **Generate once, freeze, delete the generator.** Build the matrix with a throwaway script under `prototypes/` or the scratchpad, review it, freeze it into `CharacterizationExpected.DAMAGE_CASES`, and delete the generator. Leaving it in would let someone "re-pin" a regression.
- The rule-emitted-fields check is what keeps story 001's hand-built named attacks honest.
- Epic-wide rules: expected values never derived from the factories' constants; seed every RNG from a fixture constant; **watch it fail** (change one power locally, see a case fail, revert, record it). Content is never retuned.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the specials' non-damage effects.
- Story 006: which move the shipped AI picks.
- Story 014: the named-attack Move records.
- Story 023: the move adapter.

---

## Files

- `tests/unit/battle/battle_moves_damage_characterization_test.gd`
- `tests/unit/battle/fixtures/characterization_expected.gd` (`DAMAGE_SEED`, `DAMAGE_CASES`; generated once, then frozen)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict INADEQUATE as drafted, story rewritten with the QA report's revised criterion via the scripted rule and retitled). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: The damage matrix.
  - **Test: enemy-side matrix.**
    - Given: a case (attacker, move, target, state) from `DAMAGE_CASES` (a).
    - When: the scripted enemy action resolves.
    - Then: `hp_delta`, target `hp` and `rng.state` equal the pins.
    - Edge cases: minimum damage 1 is reached on at least one case (pin which). Defending halves the damage.
  - **Test: squad-side matrix.**
    - Given: a case from `DAMAGE_CASES` (b).
    - Then: as above. The vulnerable state is set by a Florida Man Viral Stunt submitted earlier in the same case.
    - Edge cases: Defending + vulnerable together is not a case.
- **AC-2**: Rule-emitted fields equal the seam.
  - Given: each named-attack ID.
  - When: the first emission of that move in a story 006 scenario is taken.
  - Then: its `display_name`, `power`, `category`, `mp_cost` and `target_type` equal `seam.move(id)`.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_moves_damage_characterization_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-001-characterization-seam.md`
- Unlocks: `production/epics/content-migration/story-009-characterization-regression-gate.md`, `story-014-author-enemy-named-attack-moves.md`, `story-023-move-record-adapter.md`
