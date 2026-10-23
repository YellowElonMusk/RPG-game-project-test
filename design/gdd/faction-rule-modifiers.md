# Faction Rule Modifiers — Design Document

---
**Status**: Reverse-Documented
**Source**: `src/battle/factions/{faction_rule,bureaucratia,megacorp}.gd`
**Date**: 2026-10-21
**Verified By**: pending review
**Implementation Status**: Partially implemented (2 of the planned 4 factions — Bureaucratia, MegaCorp)
---

> **⚠️ Reverse-Documentation Notice**
>
> This design document was created **after** the implementation already existed.
> It captures current behavior and clarified design intent based on code analysis
> and user consultation. Some sections may be incomplete where implementation is
> partial or design intent was unclear during reverse-engineering.

---

## Summary

Faction Rule Modifiers lets each alien civilization bend the rules of battle
— a satirical mechanic made literal (Pillar 1, Pillar 2) — without Turn Battle
System ever hardcoding which faction exists. Two of the eventual four
factions are built: Bureaucratia (a specials ban that lifts on a timer) and
MegaCorp (per-round MP billing that suspends the squad to basic Attack).

---

## 1. Overview

**Purpose**: give each alien faction its own combat-bending rule, enemy
roster, and AI, as a plug-in to Turn Battle System rather than a special case
inside it.

**Scope**: included — the `FactionRule` hook contract, Bureaucratia's permit
ban, MegaCorp's subscription billing, both factions' enemy rosters and enemy
AI, and the HUD-facing banner/tooltip/color text each faction supplies.
Excluded — the two factions not yet built (Influencia, Liberty-7), the
Quirk State/Combo layer, and all damage/heal math (Stats & Damage
Resolution).

**Current Implementation**: `FactionRule` (base class, neutral defaults) with
`BureaucratiaRule` and `MegaCorpRule` subclasses. `BattleCore` holds exactly
one `FactionRule` instance per battle and consults it; it contains zero
per-faction branches anywhere.

**Design Intent** (clarified):
- Directly implements `game-concept.md`'s Unique Hook ("every enemy faction's
  satire *is* a combat rule set") and Pillar 2 (Nobody Is Right — both
  factions get equally absurd, equally telegraphed rules, no "harder" or
  "easier" coding).
- The hook contract grew by addition across three stories (specials-ban →
  enemy AI → per-round upkeep/move-legality → HUD text/color) rather than
  being designed up front — see Open Questions on whether this shape holds as
  Influencia/Liberty-7 are added.

---

## 2. Player Fantasy

`[inferred — confirm]` Reading a new faction's rule within the first turn or
two, then playing around it — the "aha" of recognizing MegaCorp's billing
ticking your MP down, or watching Bureaucratia's permit countdown, and
adjusting your plan accordingly (Pillar 4: Readable in One Turn).

---

## 3. Detailed Design

### 3.1 Core Mechanics

**The `FactionRule` Hook Contract**
- **Description**: nine methods, each with a neutral default on the base
  class: `specials_allowed(round_number)`, `choose_enemy_action(enemy,
  living_squad, round_number, rng)`, `apply_round_upkeep(living_squad)`,
  `move_allowed(actor, move)`, plus five presentation methods
  (`get_banner_text`, `get_identity_color`, `get_banner_color`,
  `get_tooltip_text`, `get_combatant_tooltip_note`).
- **Implementation**: `faction_rule.gd`'s base class; both subclasses
  override only what differs from neutral.
- **Design Rationale**: every faction's rule, AI, and presentation text share
  one hook contract, so `BattleCore` and the battle HUD both stay faction-
  agnostic.
- **Player-Facing**: the rule banner and tooltips the player reads come
  straight from this contract (see sibling UI Framework / battle-HUD slice).

**Bureaucratia — the Permit Ban**
- **Description**: Specials are banned for both sides through round
  `PERMIT_ROUNDS` (3); before the permit, the AI hunkers down (Defend + a
  weak jab) while the squad is healthy, or focuses the weakest squad member
  once anyone drops to ≤50% HP. After the permit, officials use named
  attacks (Late Fee / Mass Audit / Final Notice). The boss ("the Supervisor")
  is immune to Karen's stun because "he *is* the manager" — a single
  `is_manager()` flag other specials can reuse rather than each needing a
  one-off boss check.
- **Implementation**: `BureaucratiaRule.specials_allowed()`,
  `choose_enemy_action()`, `is_manager()`; roster factories `make_clerk()`,
  `make_supervisor()`.
- **Design Rationale**: the rule is a simple round-threshold, telegraphed by
  the HUD banner's own countdown text — satisfies Pillar 4 directly.
- **Player-Facing**: "no special moves until round 4" is readable from the
  banner alone, no tutorial text needed.

**MegaCorp — Subscription Billing**
- **Description**: every living squad member is billed `BILL_MP` MP once per
  round; reaching 0 MP "suspends" that member to Attack-only (Defend and
  Specials rejected) until they have MP again. Attack is never MP-gated, so a
  permanently-suspended member can still fight.
- **Implementation**: `MegaCorpRule.apply_round_upkeep()`,
  `move_allowed()`; roster factories `make_security_drone()`,
  `make_middle_manager()`, `make_ceo()`.
- **Design Rationale**: a resource-drain rule rather than a timer, giving a
  structurally different pressure from Bureaucratia's (Pillar 2: every
  faction's rule must feel distinct, not a reskin).
  `BILL_MP` was lowered from 2 to 1 (user, 2026-10-21) — no rationale beyond
  the user's direct instruction was recorded; flagged in Tuning Knobs.
- **Player-Facing**: the HUD banner states the exact MP charge and the
  suspension condition in plain language.

### 3.2 State and Data

**Data Structures** (from code):
- `FactionRule`: stateless base class, nine virtual methods, no fields.
- `BureaucratiaRule`: `PERMIT_ROUNDS`, `LOW_HP_THRESHOLD`, named-attack power
  constants, roster stat constants.
- `MegaCorpRule`: `BILL_MP`, roster stat constants, named-attack power
  constants.

**State Machines**: none owned here — `specials_allowed()`/`move_allowed()`
are pure functions of `BattleCore`'s own `round_number` and the `Combatant`
being asked about; this system holds no state of its own between calls.

**Persistence**: none — stateless per the above.

### 3.3 Integration Points

**Dependencies**:
- Turn Battle System (hard): the `FactionRule` hook is this system's entire
  surface; it has no existence without `BattleCore` calling into it.
- Stats & Damage Resolution (hard, indirect): named enemy attacks are plain
  `Move` instances resolved through Turn Battle System's own damage
  pipeline — this system never computes damage itself.

**Dependents**:
- Turn Battle System: injected as `BattleCore`'s `faction_rule`.
- *(Not yet designed)* UI Framework: the five presentation methods exist
  specifically to be read by a HUD; the MVP battle-HUD slice
  (`src/battle/ui/battle_hud.gd`) already does this and contains zero
  per-faction branches, confirming the contract achieves its goal.

**API Surface**:
- `FactionRule.new()`, `BureaucratiaRule.new()`, `MegaCorpRule.new()`
- The nine hook methods listed in 3.1.
- `BureaucratiaRule.make_clerk()`/`make_supervisor()`,
  `MegaCorpRule.make_security_drone()`/`make_middle_manager()`/`make_ceo()`

---

## 4. Formulas

**Formulas Discovered in Code**: none — this system decides *whether* and
*what* to trigger; the damage/heal math itself is Stats & Damage
Resolution's, called through Turn Battle System's shared pipeline.

---

## 5. Edge Cases

**Handled in Code**:
- ✅ Bureaucratia's boss-immunity flag (`is_manager()`) is keyed off the
  general `Combatant.is_boss` field, so it works for any future boss, not
  just the Supervisor.
- ✅ MegaCorp's suspension never blocks Attack, keeping a battle winnable
  even for a permanently-suspended squad member — verified live across 6
  consecutive suspended rounds during Story 004's implementation.
- ✅ Bureaucratia's enemy AI correctly switches behavior exactly at the
  `PERMIT_ROUNDS` threshold, both for choosing an action and for the HUD
  banner's text/color.

**Not Yet Handled**:
- ⚠️ Only one faction (whichever is injected) is ever active per `BattleCore`
  instance — nothing here supports two factions' rules interacting in the
  same battle. `[inferred — confirm]` likely fine, since nothing in
  `game-concept.md` describes a battle under two factions' rules
  simultaneously.

**Unclear**:
- ❓ `[INTENT UNKNOWN — inferred from implementation, not confirmed]` The hook
  contract already covers rules, AI, upkeep, legality, *and* presentation
  text/color in one class. Is this the contract shape to keep as Influencia
  and Liberty-7 are added, or is a reshuffle expected once Quirk State System
  exists (since some of what a faction rule does today — e.g. the
  stun/debuff mechanics underneath it, owned by the sibling Turn Battle
  System GDD — might move there)?

---

## 6. Dependencies

**Technical Dependencies**: none beyond GDScript/Godot 4.7.2 `RefCounted`.

**Design Dependencies**:
- Turn Battle System (hard, documented alongside this GDD).
- Content Data Definitions (soft today — the `Faction` record type's
  `rule_id` field is explicitly designed to point at a `FactionRule` record,
  itself *reserved* pending this GDD; migration in progress at the user's
  request).

**Content Dependencies**: enemy rosters and named-attack tuning (see Tuning
Knobs) — currently in-code, migrating to data now.

---

## 7. Tuning Knobs

**Current Values** (as implemented):

| Parameter | Current Value | Rationale | Needs Tuning? |
|-----------|--------------|-----------|---------------|
| Bureaucratia `PERMIT_ROUNDS` | 3 | Matches the prototype's playtested value (`PLAYTEST-LOG.md`) | ✅ |
| Bureaucratia `LOW_HP_THRESHOLD` | 0.5 | Matches the prototype | ✅ |
| Bureaucratia named-attack powers (Late Fee/Mass Audit/Final Notice) | 16 / 8 / 18 | Matches the prototype | ⚠️ |
| Clerk / Supervisor stat blocks | HP 40 / 110, etc. | Matches the prototype | ⚠️ |
| MegaCorp `BILL_MP` | **1** (was 2) | Lowered from the prototype's value by direct user instruction, 2026-10-21 — no further rationale recorded | ⚠️ |
| Security Drone / Middle Manager / CEO stat blocks | HP 36 / 44 / 120, etc. | Story 004 starting estimate, not from the prototype (MegaCorp was never prototyped) | ⚠️ |
| MegaCorp named-attack powers (Laser Scan/Upsell/Layoffs/Hostile Takeover) | 11 / 6 / 8 / 18 | Story 004 starting estimate | ⚠️ |

**Balance Concerns Identified**:
- ⚠️ `BILL_MP=1` has not been played through a full chapter — lowering it
  eases MegaCorp's pressure but hasn't been validated against the same
  chapter-length survivability concern flagged in the sibling Turn Battle
  System GDD.
- ⚠️ MegaCorp's roster was never prototyped (unlike Bureaucratia's), so its
  numbers carry more balance risk by the brief's own admission.

**Recommended Balance Pass**:
- Run `/balance-check` once this content moves into Content Data Definitions.
- Playtest MegaCorp specifically at the new `BILL_MP=1` value.

---

## 8. Acceptance Criteria

**What Exists**:
- ✅ Bureaucratia's permit-ban rule, hunker-down AI, and Supervisor boss.
- ✅ MegaCorp's billing/suspension rule, enemy roster, and CEO boss.
- ✅ A faction-agnostic HUD (zero per-faction branches in the battle-HUD
  slice), confirming the hook contract works as intended.

**What's Missing**:
- ❌ Influencia and Liberty-7 — not built; `systems-index.md`'s own note says
  these "reuse Faction Rule Modifiers" as content, not new code.
- ❌ Content Data Definitions migration — the `Faction` record type's
  `rule_id`/`signature_color`/`base_shape` fields aren't populated anywhere
  yet.

**Definition of Done** (for this reverse-documentation, not the full vision):
- [x] Every mechanic in `src/battle/factions/{faction_rule,bureaucratia,megacorp}.gd`
  is described above.
- [ ] Hook-contract-shape question confirmed (open question below).
- [ ] Content Data Definitions migration (in progress).

---

## Open Questions and Follow-Up Work

### Questions Needing User Decision

1. **Hook contract shape** `INTENT UNKNOWN`: keep the current nine-method
   contract as Influencia/Liberty-7 are added, or expect a reshuffle once
   Quirk State System exists? *(ADR-0007, Proposed 2026-10-22, adds a tenth:
   `register_resolution_hooks(hooks)`, through which a faction registers damage
   and heal modifiers and overrides with Stats & Damage Resolution. The base is
   a no-op, and neither shipped faction uses it.)*
   - Option A: keep it; new factions just add more overrides.
   - Option B: split presentation (banner/tooltip/color) out into its own
     interface once UI Framework is actually designed, so this GDD owns only
     rules/AI.

### Flagged Follow-Up Work

- [ ] Migrate Clerk/Supervisor/Drone/Manager/CEO rosters and named-attack
  tuning to Content Data Definitions `Enemy`/`Move` records — **in
  progress**, user has requested the real system be built now.
- [ ] Define the `Faction` record's `rule_id` → `FactionRule` mapping once
  Content Data Definitions' loader exists.
- [ ] Run `/balance-check` on `BILL_MP=1` specifically.
- [ ] Design Influencia and Liberty-7 as new `Faction`/`FactionRule` content
  once the data-driven path exists, per `systems-index.md`'s own note that
  they're content, not new systems.

---

## Version History

| Date | Author | Changes |
|------|--------|---------|
| 2026-10-21 | Claude (reverse-doc) | Initial reverse-documentation from `src/battle/factions/{faction_rule,bureaucratia,megacorp}.gd`; records the user's `BILL_MP` 2→1 change made the same day |

---

**Next Steps**:
1. Build Content Data Definitions (user-requested) and migrate this system's
   hardcoded content into it.
2. Resolve the hook-contract-shape question before adding Influencia/Liberty-7.
3. Design Overworld Exploration & Encounters next (explicit user request for
   overworld travel).

**Related Skills**:
- `/balance-check` — Validate formulas and progression
- `/architecture-decision` — Document technical decisions
- `/code-review` — Ensure code matches clarified design

---

*This document was generated by `/reverse-document design src/battle`*
