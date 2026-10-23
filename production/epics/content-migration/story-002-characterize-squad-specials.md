# Story 002: The five squad specials' Move fields and effects are pinned against today's `SquadSpecials`

> **Epic**: Content Migration
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: None (Step 0 characterization)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (Migration Step 0, "the four squad specials"). Also ADR-0007: Stats & Damage Resolution (Migration Step 0, heal outputs) and ADR-0010: Turn Battle System (§7, the stun/vulnerable writers).
**ADR Decision Summary**: Today's behaviour is pinned before any factory changes, and the pins must pass unchanged after every later step. The specials' fields and effects are observed through `BattleCore`, because ADR-0007 deletes the heal helpers.
**ADR Version**: ADR-0001 2026-10-23 · ADR-0007 2026-10-22 · ADR-0010 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "Characterization tests are written against today's hardcoded factories before migration and rerun unchanged after it."
- Required (*Core*): "`Combatant.hp` is a read-only property" (no `hp` writes; arrangement goes through `seam.arrange_vitals`).
- Required: "Attack and Defend stay code-side factories."
- Guardrail: none (test code).

---

## Acceptance Criteria

*Migration criterion from ADR-0001 Migration Step 0 and ADR-0007 Migration Step 0, scoped to this story:*

- [ ] GIVEN seeded battles built with fixture squads, the effect pins running under `seam.scripted_rule([])` (permissive, no enemy actions) and one immunity case per boss under its real rule after its gate (Supervisor under Bureaucratia in round 4; CEO under MegaCorp in round 1 with Karen's MP ≥ 4), with damaged and knocked-out states arranged only through `seam.arrange_vitals`, WHEN each of `move_speak_to_the_manager`, `move_family_meal`, `move_appetizer`, `move_viral_stunt` and `move_home_run` is submitted through `BattleCore.submit_action()`, THEN its `display_name`, `category`, `mp_cost`, `power`, `target_type`, `special_effect` and `effect_rounds`, the MP spent, and its effect (stun lands on a Clerk and not on the Supervisor or CEO; heal amounts for Family Meal and Appetizer; `vulnerable_rounds_left == 2` after Viral Stunt; Home Run's damage) all equal the pinned values.

---

## Implementation Notes

*Derived from ADR-0001/ADR-0007 Migration Step 0 and the QA gate (RC-1, RC-2):*

- **Which rule each battle runs under.** Bureaucratia bans Specials in rounds 1–3, so a Clerk stun in round 1 under the real rule is rejected. The effect pins use `seam.scripted_rule([])`. Only the two boss-immunity cases use the real rules, after their gates.
- **Heal amounts are observed through the battle, not through `calculate_heal()`** (ADR-0007 Step 2 deletes it). Assert `BattleOutcome.hp_delta` and each member's `hp` after `action_resolved`. Damaged and KO states come from `seam.arrange_vitals`, never from writing `hp`.
- Family Meal: pin both the side total (`hp_delta`) and each member's `hp`, with one knocked-out member, so the "living members only" rule is in the pin.
- Stun immunity is pinned on **both** bosses. Today it keys on `is_boss` (through `is_manager()`), which story 033 keeps.
- Appetizer on a knocked-out ally is rejected at submit (`submit_action` returns `null`). Pin that: ADR-0010 relies on it.
- Viral Stunt: pin `vulnerable_rounds_left` straight after the stunt and after each round tick, and the extra damage one attack deals while it lasts (+50%, `DamageCalculator.VULNERABLE_PCT`), with `rng.state` after the boosted attack.
- Each test names its owner in a comment (Karen, Michelin Chef ×2, Florida Man, Baguette Thrower).
- Epic-wide rules: expected values live in `CharacterizationExpected` (specials block), pinned by running today's code once, never derived from `SquadSpecials` constants. Squad stat blocks are `CharacterizationExpected.SQUAD_*` (the prototype's four; test data, not migrated content). Seed every RNG from a fixture constant. **Watch it fail:** change one pinned production value locally (e.g. Home Run power 18 → 19), see the test fail, revert, and record it in the Completion Notes. Content is never retuned.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: the full damage matrix (Home Run is also there, against every enemy and state).
- Story 018: the special Move records.
- Story 028: the specials adapter.
- Story 033: deleting `is_manager()`.

---

## Files

- `tests/unit/battle/battle_squad_specials_characterization_test.gd`
- `tests/unit/battle/fixtures/characterization_expected.gd` (specials block)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, revisions applied: scripted rule for effect pins, real-rule boss cases after the gate, arrangement through `arrange_vitals`). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Fields and effects of the five specials equal the pins.
  - **Test: Move fields.**
    - Given: each of the 5 special IDs through `seam.move()`.
    - Then: `display_name`, `category`, `mp_cost`, `power`, `target_type`, `special_effect` and `effect_rounds` equal `CharacterizationExpected.SPECIALS[id]`.
    - Edge cases: Home Run's name is "Home Run".
  - **Test: stun.**
    - Given: Karen and a Clerk under the scripted rule.
    - When: Speak to the Manager is submitted.
    - Then: `outcome.mp_delta == -4`, the Clerk's `is_stunned` is true, and the next enemy phase logs no Clerk outcome.
    - Edge cases: the Supervisor (Bureaucratia, round 4) and the CEO (MegaCorp) stay `is_stunned == false`, and the MP is still spent.
  - **Test: Family Meal.**
    - Given: the Chef plus 3 members arranged to the fixture HPs, one of them at hp 0.
    - When: Family Meal is submitted.
    - Then: `hp_delta` equals the pinned total, each living member's hp equals its pin, and the KO member stays 0.
    - Edge cases: a member at full HP gains 0 (clamped).
  - **Test: Appetizer.**
    - Given: the Chef and an ally arranged damaged.
    - Then: the heal equals the pin.
    - Edge cases: submitting against a KO ally returns `null`, and hp/mp are unchanged.
  - **Test: Viral Stunt.**
    - Then: `vulnerable_rounds_left` is 2 straight after, 1 after the first round tick, 0 after the second; one Attack while active deals the pinned (×1.5-path) amount.
    - Edge cases: `rng.state` is pinned after the boosted attack.
  - **Test: Home Run.**
    - Given: the Baguette Thrower against each of the 5 enemies (scripted rule).
    - Then: `hp_delta` and `rng.state` equal the pins.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_squad_specials_characterization_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-001-characterization-seam.md`
- Unlocks: `production/epics/content-migration/story-009-characterization-regression-gate.md`, `story-018-author-squad-special-moves.md`, `story-028-squad-specials-adapter.md`, `story-033-delete-is-manager.md`
