# Game Brief: Go back to your planet!

> **Superseded by the full design.** This brief drove the MVP vertical slice
> (Bureaucratia + MegaCorp, 6 stories, all Complete) at `rigor: minimal`. Now
> that rigor is `full`, `design/gdd/game-concept.md` and `design/gdd/systems-index.md`
> are the authoritative design record going forward — this brief is kept as the
> historical record of what the MVP proved, not a doc to keep in sync.

**One-sentence pitch:** Earth's military has fallen to a satirical alien alliance, and you lead humanity's most unlikely heroes into turn-based battles, cracking each planet's absurd rule to send the invaders home.

## Core loop
- Fight a chain of turn-based battles on a faction's planet.
- Read that faction's rule and play around it with Attack, Defend and your squad's specials.
- Win to move up the chain to the faction's boss.
- Beat the boss to liberate the planet, then take on the next faction.

## Player goal & fail state — what "working" looks like
- **Goal:** beat both faction bosses: Bureaucratia's Supervisor and MegaCorp's CEO.
- **Fail:** the whole squad is knocked out. You retry that battle from its start, with no permadeath and no lost progress.

## MVP — what must exist to be the game
1. **Battle core:** turn-based combat with Attack, Defend, specials, MP, win/lose and retry, using the Stats & Damage formulas (`design/gdd/stats-damage-resolution.md`).
2. **The squad**, four recruits with their specials:
   - Karen's *Speak to the Manager* stuns one enemy, but not bosses.
   - The Chef has *Family Meal* (heals the whole party) and *Appetizer* (heals one ally).
   - Florida Man's *Viral Stunt*.
   - Baguette Thrower's *Home Run*.
3. **Bureaucratia:** specials banned for both sides until the permit arrives in round 3, with Bureaucratia hunkering down meanwhile (it focuses anyone at half HP or lower); Clerks; and the Supervisor boss ("he *is* the manager").
4. **MegaCorp (cyberpunk planet):** *subscription billing*. Each round, every squad member is billed MP, and anyone out of MP is "suspended" and can only use a basic attack. Enemies are security drones and middle managers, with a CEO boss.
5. **A linear chapter per planet:** 3 fights, then the boss. No free roaming.
6. **Battle HUD:** HP/MP bars, a faction rule banner, floating numbers, and tooltips that explain the rule.

## Out of scope — not building this
- The other factions: Influencia, Liberty7/Super Patriot, Oratio, Only Male Alpha.
- Overworld exploration, recruiting beyond the starting 4, loyalty, faction reputation and endings.
- Leveling, items, shops, and the Chef's offensive dishes (spicy chilli burn and blind).
- Quirk-state combos and the Combo Codex.
- Saving, menus beyond the battle, localization, controller remapping.
- Final pixel art, 3D dioramas and audio. The MVP uses placeholders.

## Build order
1. Battle core and Bureaucratia: rebuild what the prototype proved (`prototypes/battle-concept/REPORT.md`), as real code.
2. The four squad specials, including the Chef's appetizer.
3. MegaCorp's billing rule and its enemies. This is the least proven idea, so test it right after the core.
4. The battle HUD and rule tooltips.
5. Chapter flow: the fight chain and the boss, for both planets.

---
**Who it's for / what they feel:** players who love story and satirical comedy, laughing as they figure out each alien world's dumb rule, in 30–60 minute chapters.

**Art & audio direction:** pixel sprites in lit low-poly 3D dioramas (HD-2D) later. The MVP uses flat placeholder panels, and faction colors come from `design/art/art-bible.md`.

**Reference game:** Dragon Quest XI. The MVP keeps only its command-menu battle screen and a linear run of fights.
