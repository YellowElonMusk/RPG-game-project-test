<!-- PROTOTYPE - NOT FOR PRODUCTION -->
<!-- Question: see README.md -->
<!-- Date: 2026-10-20 -->

# Playtest log: battle-concept

## Playtest 1 (2026-10-20): iteration 1, the "DENIED until Approved" rule

**Tester:** the developer. **Verdict from the tester:** fun.

**Changes requested:**
1. **Bureaucratia rule redesign.** Special moves from *both* sides are banned until
   their government approves them, which takes 3 turns. During the wait only normal
   Attack and Defend are allowed. Bureaucratia hunkers down and lowers its attack
   damage unless the party already has characters at half HP or lower; then it
   attacks those first. After 3 turns the government permits all-out war, and both
   sides can use specials.
2. **Karen**, *Speak to the Manager*: stuns an enemy for 1 turn; doesn't work on bosses.
3. **Baguette Thrower**: swings the baguette like a baseball bat instead of throwing
   it like a javelin ("funnier").
4. **Michelin Chef**: his special cooks dishes that regenerate allies' HP instead of
   throwing food at enemies.

**Later idea (not in the prototype):** the Chef gains offensive dishes later in the
game, such as spicy chilli, which burns (damage over time) and blinds for 1 turn.

**Interpretations made when building iteration 2** (confirm or correct them):
- "Hunker down and lower attack damage": enemies Defend (take half damage) *and* make
  a weak jab (power 5) on a random squad member. If anyone is at 50% HP or lower, they
  skip defending and make a full attack on the weakest member.
- The Chef's regen hits *all* allies (Family Meal: F4 heal, power 5, for 3 rounds).
- Florida Man wasn't mentioned. Viral Stunt now makes the target take +50% damage for
  2 rounds (the old Complained combo it fed is gone).
- The old DENIED/Approved rule and both combos (Expedited Review, Public Outcry) are
  removed.
- Enemy specials after the permit (invented for the prototype): Clerk *Late Fee*
  (power 16, on the weakest member); Supervisor alternates *Mass Audit* (power 8, all)
  and *Final Notice* (power 18, the weakest member).
- Enemy HP was raised (Clerks 40, Supervisor 110) so the war phase still matters after
  the wait.

## Playtest 2 (2026-10-20): iteration 2, the permit rule

**Tester:** the developer. **Verdict from the tester:** "decent."

**Requested for the real game (not the prototype):**
- The Michelin Chef needs single-target healing: **appetizers** to heal one specific
  squad mate, alongside the party-wide meal.
- More special attacks overall, to be designed later.

The tester chose to move on from prototyping.

## Iteration 3 (2026-10-20): latest brief changes, built on request

Built after `design/game-brief.md` was written, to match it:
- **Planet select** at launch: Bureaucratia or MegaCorp.
- **Michelin Chef: Appetizer** (3 MP) heals one chosen ally right away (F4, power 10).
  Family Meal is unchanged.
- **MegaCorp (cyberpunk planet):** subscription billing charges every squad member
  2 MP at the end of each round. At 0 MP you are SUSPENDED: basic Attack only, no
  Defend. Specials are allowed from round 1.
  - Enemies: Security Drone (Laser Scan on the weakest), Middle Manager (Upsell:
    drains 3 MP from whoever has the most, plus a small hit), CEO boss (alternates
    Layoffs on everyone and Hostile Takeover on the weakest; immune to Karen's
    complaint because he "outsourced customer service").
  - The billing amount, enemy stats and moves are prototype guesses; the brief fixes
    none of them.

Reference runs (autoplay):
- **Bureaucratia:** a player who uses specials wins in 7–8 rounds; attack-only wins
  1 of 2.
- **MegaCorp:** a player who uses specials wins in 8–9 rounds (about 16 turns spent
  suspended); attack-only loses 2 of 2, because unspent MP just gets billed away.

## Playtest 3: iteration 3

*(pending)*
