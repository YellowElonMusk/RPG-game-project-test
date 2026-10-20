<!-- PROTOTYPE - NOT FOR PRODUCTION -->
<!-- Question: see Hypothesis below -->
<!-- Date: 2026-10-20 -->

# Concept Prototype Report: Battle (Bureaucratia faction rule)

> **Date**: 2026-10-20
> **Prototype Path**: Engine (Godot 4.7.2, GDScript, flat 2D UI)
> **Concept File**: design/gdd/game-concept.md

---

## Hypothesis

**Iteration 1:** If the player fights a Bureaucratia squad that ignores all damage
until a target is *Approved*, they will feel the "aha" of reading the rule and
cracking it with a quirk combo. Evidence: they find Expedited Review (Complained +
Notarized) within 2 rounds and win through combos rather than spamming attacks.

**Iteration 2** (rule redesigned by the tester): If special moves from both sides
are banned for 3 rounds while the permit is pending, the wait builds tension that
pays off when all-out war begins.

---

## Riskiest Assumption Tested

The systems index flags it: a faction's satire can *be* a combat rule, and the
squad's quirks are how the player beats it. The tester confirmed that a
faction-rule fight is fun to play. The tester also replaced the specific rule (damage
immunity broken by a combo) with a different one (a timed ban on specials). That
means *the joke as a combat rule* holds up, but the first version of the joke wasn't
the one they wanted.

---

## Approach

One battle: four recruits against two Clerks and a Supervisor. Two iterations were
built and playtested in one session. Damage, heal and modifier math comes straight
from `design/gdd/stats-damage-resolution.md` (F3–F7).

**Path chosen:** Engine.
**Reason for path:** the tester wanted to play it in Godot, and the engine was
already set up. The game is turn-based, so feel was not under test; flat 2D panels
were enough.

**Shortcuts taken (intentional):**
- Colored panels and text instead of sprites or a 3D diorama, and no audio.
- All values hardcoded in one script, with no data files.
- One fight; no overworld, menus, saves or progression.
- Enemy AI is a few hand-written rules.
- A dev-only `--autoplay` / `--naive` switch that smoke-tests whole fights headless.

---

## Result

- **Iteration 1** ("DENIED until Approved" plus quirk combos): the tester called it
  **"fun"**. They asked for a different Bureaucratia rule (a 3-turn government permit
  before either side may use specials, with Bureaucratia hunkering down and preying on
  anyone at half HP) and different recruit moves: Karen's complaint stuns but not
  bosses; the baguette is swung like a baseball bat ("funnier"); the Chef cooks
  healing dishes instead of throwing food.
- **Iteration 2** (the permit rule plus the new moves): the tester called it
  **"decent"**. They want the Chef to also have single-target heals (appetizers) and
  more specials overall, both later.
- **Automated reference runs, iteration 2:**
  - A player who uses specials wins in 7–8 rounds, at about 80% squad HP when the
    permit arrives.
  - An attack-only player wins 2 of 3 fights, in 9 rounds.
  - No runtime errors in any of the 14 automated fights across both iterations.
- The tester didn't report the in-game playtest data lines, so the measurable signals
  in the hypotheses (round of first approval, Attack vs Defend choices during the
  wait) weren't checked against real play.

---

## Metrics

| Metric | Value |
|--------|-------|
| Path used | Engine |
| Iterations to playable | 1 (both iterations ran on the first try) |
| Prototype duration | About half a day, 2 iterations |
| Playtesters | 1 internal (the developer) / 0 external |
| Feel assessment | Iteration 1 "fun"; iteration 2 "decent". The tester redesigned the faction rule and three of the four recruits' specials after the first play. |
| Hypothesis verdict | PARTIALLY CONFIRMED. A faction rule as a combat mechanic is fun, but the measurable signals weren't collected, and the rule changed between iterations. |

---

## Recommendation: PROCEED

The core idea, that a faction's satire is a combat rule the squad has to play
around, was fun on its first build and still "decent" after the tester's own
redesign. The tester chose to move on. The open questions are about content, not
concept: which version of the Bureaucratia rule, how many specials, single-target
heals. Those belong in design, not more prototyping. One caveat: the only tester is
the developer, so the "aha" isn't proven with fresh players yet.

---

## If Proceeding

- **Core tuning values discovered (provisional):**
  - Permit wait of 3 rounds.
  - Defend = −50% damage taken.
  - Gone Viral = +50% damage taken.
  - Bureaucratia targets anyone at ≤50% HP.
  - Enemy HP of Clerk 40 / Supervisor 110 against a 4-recruit squad keeps the
    post-permit phase meaningful.
  - The Stats & Damage formulas (ratio damage, ±10%, F4 heal) produced sensible
    numbers with no changes.
- **Assumptions confirmed:** the joke works as the mechanic; the ratio damage formula
  feels readable; the misfit roster carries the humor.
- **Assumptions disproved:**
  - The concept's Bureaucratia rule ("ignores damage until *Approved*") was replaced
    by the tester with the 3-round permit ban.
  - Quirk-state *combos* weren't missed when removed in iteration 2. Whether combos
    stay core (the concept's Combo Codex) is now an open design question.
- **Emergent mechanics:**
  - A both-sides ban turns the opening rounds into an Attack/Defend/HP-management
    puzzle, and the permit arrival becomes a natural mid-fight escalation beat.
  - "The Supervisor *is* the manager" boss immunity is a good joke-as-rule.

**Design follow-ups:**
- Update `design/gdd/game-concept.md` (Unique Hook) and the Bureaucratia examples in
  `design/gdd/stats-damage-resolution.md` to the permit rule.
- Michelin Chef: single-target heal (appetizers); later, offensive dishes (spicy
  chilli: burn damage over time plus 1-turn blind).
- Design more specials per recruit.
- Decide whether quirk combos remain a core pillar.

**Next steps (rigor: minimal):** `/brainstorm` to write `design/game-brief.md` (the
design record at this tier), then `/create-stories`, then `/dev-story`.

---

## Lessons Learned

- **What assumptions were broken by actually building this?** The concept doc's
  version of the faction rule wasn't the one the designer wanted once they played it.
  Building it made the real rule obvious within one session.
- **What surprised us that didn't show up in the brainstorm?** Flavor drove the
  mechanics: "baseball bat, not javelin" and "the chef heals, he doesn't throw food"
  came from what's funnier, and they changed the roster's roles (the Chef became the
  healer).
- **What would we test differently next time?** Have the tester copy the in-game
  playtest data line every time, and get at least one person who hasn't seen the
  game. The developer can't test whether a rule is discoverable.

---

> *Prototype code location: `prototypes/battle-concept/`*
> *This code is throwaway. Never refactor it into production.*
