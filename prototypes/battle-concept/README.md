<!-- PROTOTYPE - NOT FOR PRODUCTION -->
<!-- Question (iteration 2): Does Bureaucratia's 3-round permit wait build tension that pays off when all-out war begins? -->
<!-- Date: 2026-10-20 -->

# Battle concept prototype (iteration 3)

Pick a planet, then fight one battle. **Bureaucratia:** two Clerks and the
Supervisor. **MegaCorp:** a Security Drone, a Middle Manager and the CEO.
Throwaway code. Nothing here goes into the real game.

**New in iteration 3:** the planet select, the Chef's **Appetizer** (heals one ally;
pick it, then click Target on an ally card), and **MegaCorp**: every squad member is
billed 2 MP at the end of each round, and at 0 MP they are SUSPENDED (basic Attack
only). The Middle Manager's Upsell drains extra MP. See `PLAYTEST-LOG.md`.

## How to play

- **Easiest:** double-click `play.bat` in this folder.
- **From the Godot editor:** open `prototypes/battle-concept/battle.tscn` and press
  **F6** (Run Current Scene).

Controls: mouse, or the arrow keys/gamepad plus Enter. Pick a command at the bottom,
then a target on the right if it needs one. Hover over cards and buttons for details.
**R** restarts at any time.

## The rule

**Bureaucratia:** no special moves for *either* side until the government permit
arrives, which takes 3 rounds. Until then only Attack and Defend are allowed. The
officials hunker down (they take half damage and only jab with a pen), but if anyone
in your squad drops to half HP, they all go for that person. From round 4 it's
**all-out war**: your specials unlock, and the officials start using theirs too.

| Recruit | Special (from round 4) |
|---|---|
| Karen | **Speak to the Manager**: stuns one enemy for 1 turn. Doesn't work on bosses (the Supervisor *is* the manager). |
| Michelin Chef | **Family Meal**: every ally regenerates HP at the end of each round for 3 rounds. |
| Florida Man | **Viral Stunt**: one enemy takes 50% more damage for 2 rounds. |
| Baguette Thrower | **Baguette Home Run**: swings the baguette like a baseball bat (power 18). |

Enemy specials after the permit: Clerks charge a **Late Fee** (a big single hit on
your weakest member). The Supervisor alternates **Mass Audit** (hits everyone) and
**Final Notice** (a huge single hit).

## What to write down after each fight

Copy the "Playtest data" line from the end of the log, then answer in a sentence each:
1. During the 3-round wait, did choosing between Attack and Defend feel like a real
   decision, or like waiting?
2. Did the permit arriving feel like a payoff?
3. Which special felt best? Which felt weakest?
4. Anything confusing or frustrating?

Reference runs (autoplay, 2026-10-20):
- **Uses specials well:** wins in 7–8 rounds, at about 80% squad HP when the permit arrives.
- **Attack-only:** wins 2 of 3, in 9 rounds.

## Developer notes

- Formulas come from `design/gdd/stats-damage-resolution.md`: F3 damage, F4 heal,
  F5 modifiers (Defending −50%, Gone Viral +50%), ±10% variance, a minimum of 1.
- Self-test: `godot --headless --path . res://prototypes/battle-concept/battle.tscn -- --autoplay`
  (add `--naive` for the attack-only player). It prints `PROTOTYPE RESULT:` and quits.
- Playtest history: `PLAYTEST-LOG.md`.
