# Story 006: Both faction rules' decisions are pinned: the permit round, the AI's picks before and after it, MegaCorp's per-enemy move choice, billing and suspension

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

**ADR Governing Implementation**: ADR-0011: Faction Rule Modifiers (Migration Step 1, the four named items; §6 "Behaviour is unchanged by the migration"). Also ADR-0001: Content Data Definitions Storage & Loading Format (Migration Step 0, "both faction rules").
**ADR Decision Summary**: Both shipped rules' decisions are pinned before their tuning, rosters and named attacks move to `faction_rule` records, so the configured rules can be proved to decide identically.
**ADR Version**: ADR-0011 2026-10-22 · ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "Characterization tests are written against today's hardcoded factories before migration and rerun unchanged after it."
- Required: "Enemy AI keys behaviour off the record `id`, never `display_name`" (the reason MegaCorp's per-enemy pick is pinned before 026 changes its key).
- Guardrail: none (test code).

---

## Acceptance Criteria

*Migration criterion from ADR-0011 Migration Step 1 and ADR-0001 Migration Step 0, scoped to this story:*

- [ ] GIVEN `seam.rule("rule_bureaucratia_permit")` and `seam.rule("rule_megacorp_billing")` with fixture squads and seeded RNGs, with every state arranged only through `seam.arrange_vitals`, THEN `specials_allowed(r)` for r = 1..6; `seam.enemy_turn()` for each enemy type in rounds 1–6 with the squad above half HP and with one member at or below half HP (including the boundary rows: Karen at 17/34, exactly 0.5, gets Red Tape; Karen at 18/34 gets Pen Jab; a two-member tie at equal fraction targets the first in squad order); `apply_round_upkeep()`'s MP change over several rounds down to 0; and `move_allowed()` for Attack, Defend and a Special at MP 0 and MP > 0, all equal the pinned values.

---

## Implementation Notes

*Derived from ADR-0011 Migration Step 1 / §2 and the QA gate (RC-1):*

- **Bureaucratia boundaries:** round 3 has specials banned and round 4 allowed (`PERMIT_ROUNDS` 3); `LOW_HP_THRESHOLD` 0.5 **inclusive**; "Pen Jab" target from `rng.randi_range` (pin the target and `rng.state`); the Supervisor's even/odd split after the permit (Mass Audit is one action per living member, in squad order; Final Notice on the weakest in odd rounds); the Clerk's "Late Fee" on the weakest; a weakest-HP tie goes to the first in squad order (`_weakest` uses `<`).
- **MegaCorp:** the CEO's odd/even split (Layoffs on every member in odd rounds, Hostile Takeover on the weakest in even rounds) is the reverse parity of the Supervisor's. Pin both in one test so a copy-paste adapter can't swap them. Middle Manager → Upsell, Drone → Laser Scan. Billing is 1 MP per living member per round, clamped at 0; a knocked-out member is not billed (only `living_squad` is passed).
- `move_allowed`/`specials_allowed` are side-effect-free and draw no RNG (ADR-0011 §2). Assert `rng.state` unchanged after calling them; ADR-0010's `check_command()` relies on it.
- The neutral `FactionRule.new()` default (one power-10 Attack on a random member) is pinned as a control case. It stays in code (ADR-0011 §1, the record-less fallback).
- **Statelessness** (ADR-0011 Validation Criteria): call each AI method twice with the RNG reseeded and assert identical output.
- Low-HP and MP 0 states come from `seam.arrange_vitals` (RC-1); the exact-50% boundary is otherwise unreachable.
- Epic-wide rules: expected values in `CharacterizationExpected`, never read from the rules' constants; every RNG seeded from a fixture constant; **watch it fail** (e.g. `PERMIT_ROUNDS` 3 → 2 locally, see it fail, revert, record it). The Supervisor's powers (Final Notice 18, Mass Audit 8) are pinned as shipped.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007: the rules' presentation (text, colours).
- Story 008: whole scripted fights.
- Story 017: the `faction_rule` records.
- Story 026: rules configured from records.

---

## Files

- `tests/unit/battle/battle_faction_rule_decisions_characterization_test.gd`
- `tests/unit/battle/fixtures/characterization_expected.gd` (rule decisions block, including the boundary rows)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, revisions applied: arrangement only through `seam.arrange_vitals`, boundary rows in the fixture). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Both rules' decisions equal the pins.
  - **Test: permit boundary.**
    - Then: `specials_allowed(r)` for r = 1..6 equals `[F,F,F,T,T,T]`, and `rng.state` is unchanged.
    - Edge cases: r = 0 is not called.
  - **Test: Bureaucratia AI by round and HP.**
    - Given: Clerk and Supervisor, r = 1..6, healthy and low-HP squads.
    - Then: `enemy_turn` equals the pins: pre-permit Defend + Pen Jab on the RNG target, or Red Tape on the weakest; post-permit Late Fee (Clerk), Mass Audit ×living in even rounds (Supervisor) or Final Notice in odd rounds.
    - Edge cases: exactly 0.5 is inclusive (17/34 → Red Tape, 18/34 → Pen Jab). Weakest-tie goes to the first. Mass Audit with 3 living members gives 3 actions in squad order.
  - **Test: MegaCorp AI.**
    - Then: CEO Layoffs on every member in odd rounds and Hostile Takeover on the weakest in even rounds; Middle Manager gives Upsell; Drone gives Laser Scan.
    - Edge cases: parity is opposite to the Supervisor's, asserted in one test.
  - **Test: billing.**
    - Given: 4 members, one KO'd.
    - When: `apply_round_upkeep(living)` runs ×N.
    - Then: each living member loses 1 MP per round, clamped at 0; the KO member is unchanged.
  - **Test: move_allowed.**
    - Then: Attack, Defend and a Special at MP 0 and MP 4 equal the pin (`mp > 0 or ATTACK`); `rng.state` is unchanged.
  - **Test: statelessness and neutral control.**
    - Then: each AI call repeated with the RNG reseeded gives identical output. `FactionRule.new()` gives one Attack 10 on a `randi_range` target.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_faction_rule_decisions_characterization_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-001-characterization-seam.md`
- Unlocks: `production/epics/content-migration/story-009-characterization-regression-gate.md`, `story-017-author-faction-rule-records.md`, `story-026-faction-rule-decisions-from-records.md`
