# Turn Battle System — Design Document

---
**Status**: Reverse-Documented
**Source**: `src/battle/battle_core.gd`, `move.gd`, `combatant.gd`, `battle_outcome.gd`, `squad/specials.gd`
**Date**: 2026-10-21
**Verified By**: pending review
**Implementation Status**: Partially implemented (core loop + 4 named specials complete; Quirk State/Combo layer not yet built on top)
---

> **⚠️ Reverse-Documentation Notice**
>
> This design document was created **after** the implementation already existed.
> It captures current behavior and clarified design intent based on code analysis
> and user consultation. Some sections may be incomplete where implementation is
> partial or design intent was unclear during reverse-engineering.

---

## Summary

Turn Battle System is the turn-based combat engine: it resolves Attack, Defend
and Special moves for a squad against enemies, tracks HP/MP, and reports
win/loss round-by-round, through an injected `FactionRule` hook so
faction-specific rules never touch the core loop.

---

## 1. Overview

**Purpose**: run one battle from start to finish — choose a move, resolve it,
advance turns and rounds, detect victory/defeat — while staying unaware of
which alien faction or which squad member's special is in play.

**Scope**: included — turn order, MP/targeting, win/loss/retry, per-round
effect ticking, the `FactionRule` hook contract (consulted, never owned).
Excluded — damage/heal math (Stats & Damage Resolution), faction-specific
rules and enemy AI (Faction Rule Modifiers, documented alongside this GDD),
the quirk-state/combo layer described in `game-concept.md` (not yet built),
presentation (UI Framework — not yet a designed system; a battle HUD slice
exists for the MVP build under `src/battle/ui/`).

**Current Implementation**: `BattleCore` (`RefCounted`, no scene-tree
dependency) drives a squad `Array[Combatant]` vs an enemies `Array[Combatant]`,
consulting an injected `FactionRule` and `RandomNumberGenerator` (never
global, per Stats & Damage F6).

**Design Intent** (clarified):
- Serves Pillar 4 (Readable in One Turn): one state machine, one outcome log,
  one set of signals — every system downstream reads the same facts.
- The `FactionRule` hook exists specifically so Faction Rule Modifiers never
  needs `BattleCore` to know Bureaucratia or MegaCorp exist (the circular-
  dependency resolution `systems-index.md` already states).
- `[inferred — confirm]` The four named specials (Stun / Heal-party /
  Heal-single / Damage-debuff / Direct-damage) were built as the MVP's
  simplest version of what the full vision's quirk-state/combo system may
  eventually generalize.

---

## 2. Player Fantasy

`[inferred — confirm]` Confident, readable command-menu combat in the Dragon
Quest lineage: the player always knows *why* a move succeeded, failed, or is
unavailable (a Special banned by the current faction rule, a move an empty MP
pool can't afford), and losing never costs progress — a retry restores the
exact fight just lost, never the start of a whole chapter.

---

## 3. Detailed Design

### 3.1 Core Mechanics

**Turn State Machine**
- **Description**: `SQUAD_TURN` / `ENEMY_TURN` / `WON` / `LOST`. Squad acts
  member-by-member in fixed roster order, skipping anyone already knocked
  out; once every living squad member has acted, the enemy phase runs in one
  synchronous pass via the injected `FactionRule`.
- **Implementation**: `_active_squad_index`, `_skip_to_living_squad_member()`,
  `_run_enemy_phase()` in `battle_core.gd`.
- **Design Rationale**: a single owning state machine, not per-combatant turn
  flags, so nothing outside `BattleCore` can desync "whose turn is it."
- **Player-Facing**: `turn_started`, `action_resolved`, `round_advanced`,
  `battle_ended` signals; a HUD never polls.

**Moves: Attack / Defend / Special**
- **Description**: three categories. Attack: fixed power-10, 0 MP, full damage
  pipeline. Defend: 0 MP, halves incoming damage until the user's own next
  turn. Special: MP-gated, dispatches on a `SpecialEffect` enum (`STUN`,
  `HEAL_PARTY`, `HEAL_SINGLE`, `DAMAGE_DEBUFF`, `DIRECT_DAMAGE`).
- **Implementation**: `Move` (`display_name`, `category`, `mp_cost`, `power`,
  `target_type`, `special_effect`, `effect_rounds`); `BattleCore._resolve_move()`'s
  `match move.category` / nested `match move.special_effect`.
- **Design Rationale**: category is a closed, small enum so the dispatch
  stays exhaustive and typed — Godot 4.7's inherited-typed-return override
  rule was a live constraint here (see `faction_rule.gd`'s own doc comment).
- **Player-Facing**: four named specials exist today — Karen's *Speak to the
  Manager* (stun), the Chef's *Family Meal*/*Appetizer* (party/single heal),
  Florida Man's *Viral Stunt* (damage-taken debuff), the Baguette Thrower's
  *Home Run* (direct damage, Attack's own pipeline with a different power).

**MP Gating and Targeting**
- **Description**: a move is rejected if its `mp_cost` exceeds the actor's
  current MP, if `FactionRule.move_allowed()` rejects it (e.g. MegaCorp's
  suspension), if `FactionRule.specials_allowed()` bans Specials this round,
  or if its `target_type` (`SELF`/`SINGLE_ENEMY`/`SINGLE_ALLY`) doesn't
  resolve to a legal, living target.
- **Implementation**: `submit_action()`'s ordered gate checks;
  `_validate_and_resolve_target()`.
- **Design Rationale**: every gate is a single `if` in one function, so "why
  was this rejected" is always answerable from one read.
- **Player-Facing**: a rejected submission returns `null` and changes no
  state — intended as a HUD-level "this option is disabled," not a hidden
  failure (not yet built; UI Framework doesn't exist as a designed system).

**Round Ticking and Retry**
- **Description**: `_tick_round_effects()` decrements damage-debuff durations
  once per round; `start_battle(reset_squad: bool = true)` resets everyone for
  a standalone or lost-and-retried battle, or (`reset_squad=false`) carries
  the squad's current HP/MP into a fresh `BattleCore` for multi-fight
  sequencing.
- **Implementation**: `battle_core.gd`'s `_tick_round_effects()`,
  `start_battle()`, `retry_battle()`.
- **Design Rationale**: `reset_squad` was added specifically so a multi-fight
  chapter (built on top of this system, outside it) could carry HP/MP between
  fights without this system knowing chapters exist.
- **Player-Facing**: "no permadeath and no lost progress" on a single-fight
  retry; cross-fight carryover is a separate system's choice to make, not
  forced by this one.

### 3.2 State and Data

**Data Structures** (from code):
- `Combatant`: `display_name`, `max_hp`/`max_mp`, `attack`/`defense`/`speed`,
  `is_enemy`, `is_boss`, `hp`, `mp`, `is_defending`, `is_stunned`,
  `vulnerable_rounds_left`
- `Move`: `display_name`, `category`, `mp_cost`, `power`, `target_type`,
  `special_effect`, `effect_rounds`
- `BattleOutcome`: `actor`, `move_name`, `category`, `target`, `hp_delta`,
  `mp_delta`, `target_knocked_out`, `round_number`

**State Machine**:
```
SQUAD_TURN → (all squad acted) → ENEMY_TURN → (round tick) → SQUAD_TURN (next round)
                                                             | WON
                                                             | LOST
```
`WON`/`LOST` are terminal until `start_battle()`/`retry_battle()` runs again.

**Persistence**:
- Saved: nothing — this system holds no save-relevant state itself.
- Not saved: `outcome_log` is session-only.

### 3.3 Integration Points

**Dependencies**:
- Stats & Damage Resolution (hard): `DamageCalculator.calculate_damage()` for
  all Attack/Special direct-damage math. *(ADR-0007, Proposed 2026-10-22:
  becomes `DamageResolver.resolve()` for both damage and heals, with Defend and
  Viral Stunt as registered modifiers and their magnitudes in `StatsConfig`.
  Today's code is unchanged until ADR-0007's migration.)*
- Faction Rule Modifiers (hard, documented alongside this GDD):
  `specials_allowed`, `choose_enemy_action`, `apply_round_upkeep`,
  `move_allowed`.

**Dependents**:
- Faction Rule Modifiers: consumed via the `FactionRule` hook, never the
  reverse.
- *(Not yet designed)* UI Framework: would read the four signals and
  `get_living_squad()`/`get_living_enemies()`/`get_active_combatant()`. An MVP
  battle-HUD slice already does this (`src/battle/ui/`).
- *(Not yet built)* a future chapter/overworld layer: `start_battle(reset_squad)`
  exists specifically for this; a simple chapter sequencer (`src/chapters/`)
  already uses it.

**API Surface**:
- `BattleCore.new(squad, enemies, rng, faction_rule)`
- `start_battle(reset_squad := true)`, `retry_battle()`
- `submit_action(move, target) -> BattleOutcome`
- `get_living_squad()`, `get_living_enemies()`, `get_active_combatant()`

---

## 4. Formulas

**Formulas Discovered in Code**: none native to this system — Attack/Special
direct-damage and heal math are entirely Stats & Damage Resolution's
(F3–F7), already Designed and followed exactly (`POWER_SCALE`,
`DAMAGE_VARIANCE`, `DEFEND_PCT`, `MULT_MIN`/`MULT_MAX`,
`MIN_DAMAGE`/`DAMAGE_CAP`, `HEAL_ATTACK_SCALE` all match that GDD's values).

---

## 5. Edge Cases

**Handled in Code**:
- ✅ A squad member knocked out mid-chapter and carried over at 0 HP is
  correctly skipped by `_skip_to_living_squad_member()` even with
  `reset_squad=false` (verified live during a prior story's testing).
- ✅ A rejected submission changes no state and returns `null`.
- ✅ Defend's halved-damage window clears exactly on the owner's own next
  turn, not a fixed duration.
- ✅ A compound enemy turn (e.g. Defend then Attack) resolves as an ordered
  action list from `FactionRule.choose_enemy_action()`.

**Not Yet Handled**:
- ⚠️ No revival mechanic exists anywhere in this system — a squad member at 0
  HP stays knocked out for the rest of any sequence built on top of it.
  `[inferred — confirm]` intentional for this MVP tier; open question for the
  full vision's Leveling & Loyalty system.

**Unclear**:
- ❓ Whether the stacked transient `Combatant` flags (`is_defending`,
  `is_stunned`, `vulnerable_rounds_left`) are the long-term shape, or whether
  Quirk State System (not yet designed) is meant to generalize these into a
  single data-driven "active states" list per Content Data Definitions'
  `QuirkState` record type.

---

## 6. Dependencies

**Technical Dependencies**: none beyond GDScript/Godot 4.7.2 `RefCounted` (no
scene-tree dependency, matching every other battle class's convention).

**Design Dependencies**:
- Stats & Damage Resolution (hard, already Designed).
- Faction Rule Modifiers (hard, documented alongside this GDD).
- Content Data Definitions (soft today — `Character`/`Enemy`/`Move` records
  are the designed replacement for today's hardcoded `Combatant`/`Move`
  construction; migration in progress at the user's request).
- Input System (hard, via Game State routing; 2026-10-23 sync): `confirm`, `cancel`, `inspect`, `page_left/right` and `fast_forward` (the replay tap latch). `input-system.md` lists this system as a consumer.
- Game State & Scene Flow (hard): battle entry and the outcome report, including **Fled** (`battle_fled`, ADR-0010 §5). *A Flee design section for this GDD is owed (game-designer follow-up from the 2026-10-23 Game State review): flee chance from `TurnBattleConfig`, `can_flee` from the Encounter descriptor, failure passes the turn.*

**Content Dependencies**: none yet — all content is in-code (see Tuning Knobs).

**Downstream dependents**:
- Sprite & Camera Presentation (`design/gdd/sprite-camera-presentation.md`, hard for Battle). It receives each `action_resolved` outcome in order through `BattleReplayController` (ADR-0006) and **replays** them beat by beat, because this system resolves a whole round, including the enemy phase, synchronously. The battle's command menu opens only after the replay finishes, and the battle outcome is reported to Game State only after the last beat. A replay never changes a result.
  - **Open, owned here:** the `fast_forward` replay speed (`ff_mult`, proposed 2.0×).
  - **Open, owned here:** a possible `action_started` signal for a separate wind-up beat.
  - **Open, owned here:** a miss/evade flag, if misses become a mechanic.
- Beatbox Battle Score (`design/gdd/beatbox-battle-score.md`, soft, 2026-10-29). It listens to the same `BattleReplayController` signals (knockout reactors at `beat_impact`, the released round and battle end) to drop each alien's layer of the music as its knockout lands. It never gates the replay.
  - **Open, owned here (user direction 2026-10-29):** rosters of 1 to 8 enemies (typical 2–5, late game and hard areas up to 8, bosses with minions). Targeting and enemy-turn pacing must be specified for 8 (`beatbox-battle-score.md` OQ-12).

---

## 7. Tuning Knobs

**Current Values** (as implemented):

| Parameter | Current Value | Rationale | Needs Tuning? |
|-----------|--------------|-----------|---------------|
| Attack power | 10 | Stats & Damage F3's documented "power 10 = basic attack" baseline | ✅ |
| Karen's *Speak to the Manager* MP cost | 4 | Story 003 starting estimate, no formal balance pass | ⚠️ |
| Chef's *Family Meal* MP/power | 5 / 5 | Story 003 starting estimate | ⚠️ |
| Chef's *Appetizer* MP/power | 3 / 10 | Story 003 starting estimate | ⚠️ |
| Florida Man's *Viral Stunt* MP/rounds | 3 / 2 | Story 003 starting estimate; the +50% magnitude lives in the Faction Rule Modifiers GDD as a `DamageCalculator` constant (ADR-0007, Proposed: moves to `StatsConfig.vulnerable_pct`) | ⚠️ |
| Baguette Thrower's *Home Run* MP/power | 4 / 18 | Story 003 starting estimate | ⚠️ |

**Balance Concerns Identified**:
- ⚠️ None of the four specials' MP/power values have had a `/balance-check`
  pass — they're first-guess values, explicitly flagged as such in their own
  source comments.

**Recommended Balance Pass**:
- Run `/balance-check` once the Content Data Definitions migration (in
  progress) moves these into data.
- Playtest focus: whether the Chef's heals keep a full chapter (no full heal
  between fights) survivable against an escalating boss — a live concern
  already surfaced during manual playtesting of the chapter-flow system.

---

## 8. Acceptance Criteria

**What Exists**:
- ✅ Attack/Defend/Special resolve correctly, gated by MP and `FactionRule`.
- ✅ Four named specials with distinct effects.
- ✅ Win/loss/retry, with and without full squad reset.
- ✅ Full outcome log + 4 signals for a presentation layer to read.

**What's Missing**:
- ❌ Quirk State System (states as reusable, stackable, data-driven records)
  — not built; today's specials are direct one-shot effects.
- ❌ Combo System & Codex — not built at all.
- ❌ Content Data Definitions migration — `Character`/`Enemy`/`Move` records
  don't exist yet; everything is still hardcoded `Combatant`/`Move`
  construction.

**Definition of Done** (for this reverse-documentation, not the full vision):
- [x] Every mechanic in `src/battle/{battle_core,move,combatant,battle_outcome}.gd`
  and `squad/specials.gd` is described above.
- [ ] Quirk State/Combo relationship confirmed (open question below).
- [ ] Content Data Definitions migration (in progress).

---

## Open Questions and Follow-Up Work

### Questions Needing User Decision

1. **Quirk State / Combo relationship** `INTENT UNKNOWN — inferred from
   implementation, not confirmed`: is the current `SpecialEffect` enum meant
   to become Quirk State System's effect vocabulary (today's `STUN` becomes a
   generic "Stunned" state anything could apply), or is Quirk State/Combo a
   new layer built on top, leaving these four specials as simpler one-off
   effects?
   - Option A: generalize `SpecialEffect` into data-driven `QuirkState`
     records now, ahead of building Combo System & Codex.
   - Option B: leave the four specials as-is; design Quirk State/Combo as an
     additive layer later.

2. **Viral Stunt → Gone Viral** `INTENT UNKNOWN`: is Florida Man's Viral
   Stunt the MVP placeholder for the concept doc's "Gone Viral" quirk state
   specifically, or a coincidentally similar, separate effect?

### Flagged Follow-Up Work

- [ ] Migrate `Combatant`/`Move` construction to Content Data Definitions
  records (`Character`, `Enemy`, `Move`) — **in progress**, user has
  requested the real system be built now.
- [ ] Run `/balance-check` on the four specials once they're data-driven.
- [ ] Design Quirk State System and Combo System & Codex, informed by the
  answers to the open questions above.
- [ ] Extend this doc once a Content Data Definitions-driven Move/Character/
  Enemy loading path replaces today's hardcoded constructors.

---

## Version History

| Date | Author | Changes |
|------|--------|---------|
| 2026-10-21 | Claude (reverse-doc) | Initial reverse-documentation from `src/battle/{battle_core,move,combatant,battle_outcome}.gd`, `squad/specials.gd` |

---

**Next Steps**:
1. Build Content Data Definitions (user-requested) and migrate this system's
   hardcoded content into it.
2. Resolve the Quirk State/Combo open questions above before designing those
   two systems.
3. Design Overworld Exploration & Encounters next (explicit user request for
   overworld travel).

**Related Skills**:
- `/balance-check` — Validate formulas and progression
- `/architecture-decision` — Document technical decisions
- `/code-review` — Ensure code matches clarified design

---

*This document was generated by `/reverse-document design src/battle`*
