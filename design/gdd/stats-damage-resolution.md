# Stats & Damage Resolution

> **Status**: Designed (pending `/design-review`)
> **Creative Director Review (CD-GDD-ALIGN)**: skipped — Lean mode
> **Author**: user + agents
> **Last Updated**: 2026-10-20
> **Last Verified**: 2026-10-20
> **Implements Pillar**: Challenge, Competence (inferred from game-concept.md's MDA table — no game-pillars.md exists yet)

## Summary

Stats & Damage Resolution owns the five combat stats, MP costs, enemy rewards
and the fixed six-step pipeline that turns a move into a damage or heal number.
Players see its output as damage numbers and HP bars in battle and full stats at
camp. It exists to give faction rules and quirks a clear, consistent baseline to
bend: only a rule can make a hit show 0.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Content Data Definitions`

## Overview

Stats & Damage Resolution is the rulebook behind every number in a battle. It
defines the `stat_block` that Character and Enemy records share, what a Move's
`cost` means and how it is paid, and what an Enemy's `reward` contains. It also
turns "this combatant used this Move on that target" into an outcome: damage
dealt, healing done, and resources spent. The player meets it as damage numbers
popping off targets and HP bars draining in battle. Full stat detail lives on
the camp/party screen, so a fight reads at a glance and the deeper numbers are
there for anyone planning a squad. The system exists so the game's jokes have
something firm to bend: faction rules ("Bureaucratia ignores damage until
*Approved*") and quirk states are only legible as rule-breaks if the normal
rules are clear, consistent and visible. Other systems change its inputs and
outputs through defined hooks; this system owns the baseline math they modify.

## Detailed Design

> `game-designer`, `systems-designer`, `ai-programmer` and `art-director` not
> consulted — Lean mode. Review manually before production.

### Core Rules

**The stat block**

1. Every Character and Enemy record carries one `stat_block` with exactly five
   integer stats: `max_hp`, `max_mp`, `attack`, `defense`, `speed`. Their
   allowed ranges are defined in Formulas. There are no other stats; anything a
   quirk or faction does is expressed as a modifier on these five or as an
   effect, never as a sixth stat. Stat modifiers (e.g. "+5 defense") are
   applied before step 1 of the pipeline (Formulas F2); modifiers on a damage
   or heal amount are applied at step 2 (F5).
2. `max_hp` is how much damage a combatant can take. `max_mp` is the pool that
   pays for moves. `attack` raises damage dealt, `defense` lowers damage taken,
   and `speed` is read by the Turn Battle System to order turns. This system
   supplies the **effective** speed (after stat modifiers, F2), so a speed
   modifier visibly changes turn order. It does not define turn order itself.
3. In battle each combatant also has two runtime values, `current_hp` and
   `current_mp`. They are never stored in content data. Enemies start every
   battle at full HP and MP. Characters carry their current HP and MP between
   battles; they are restored to full at camp *(provisional: Camp & Party
   Management owns when restoration happens)*. At MVP nothing restores MP in
   battle: `current_mp` only falls until camp. Items may add MP restore at
   Vertical Slice.

**Move costs**

4. `Move.cost` is a non-negative integer of MP. A cost of 0 means the move is
   free; every combatant's basic attack has cost 0.
5. A move is usable only if the user's `current_mp` is at least its cost. This
   system answers "can this combatant afford this move?"; how an unaffordable
   move is shown is the UI Framework's concern.
6. The cost is paid in full when the move starts to resolve, before any effect
   is applied, and only if both are true at that moment: the user's
   `current_mp` still covers the cost, and at least one valid target exists.
   If either fails, the move does not resolve and no MP is spent (an
   `unaffordable` or `no_target` outcome is reported). Once paid, the cost is
   not refunded, even if the move's effects end up doing nothing.

**Effects this system interprets**

7. This system owns two EffectDescriptor types (Content Data Definitions rule 4
   assigns damage and heal here):
   - `damage {power}`: deals damage to the target using the damage formula.
   - `heal {power}`: restores HP to the target using the heal formula.
   Every other `type` (quirk, combo, faction hooks) belongs to its own system.
   Handing the resolver a type it does not own is a programming error: it
   raises an error naming the type and changes nothing.
8. Every attack hits. There are no misses, dodges or random critical hits.
   Damage has a small random variance (±10%, defined in Formulas) so repeated
   hits don't look identical. With variance at 0.10, any single amount
   modifier of ±25% or more gives a range of varied amounts (before rounding)
   that does not overlap the unmodified range, so the player can see it. After
   rounding, the two ranges can touch at a single value. (Modifiers under about
   23% can be hidden by variance; content should avoid them for rules the
   player must read.)

**The resolution pipeline**

9. Resolving one `damage` or `heal` effect against one target always runs
   these steps in this order:
   1. **Base**: compute the base amount from `power`, the user's `attack` and
      (for damage) the target's `defense`.
   2. **Modify**: apply every active modifier from other systems (quirk states,
      faction rules, combos), in the order Formulas defines.
   3. **Vary**: apply the random variance.
   4. **Round and clamp**: round to an integer and clamp to the allowed range.
   5. **Override**: a registered override may replace the final amount (e.g.
      Bureaucratia: "damage is 0 until the target is *Approved*"). Overrides
      run after variance so their result is exact and readable.
   6. **Apply**: subtract from (damage) or add to (heal) `current_hp`, clamped
      to `0..max_hp`, and report the result.
10. `current_hp` has no public setter: only the resolver's Apply step writes
    it. Other systems never change it directly. They register modifiers
    (step 2) or overrides (step 5), or emit effects this system resolves. That
    keeps every HP change on the same visible path, so it always produces a
    damage or heal number on screen.
11. Every resolution reports exactly one outcome record: `user`, `target`,
    `effect_type`, `final_amount`, `overridden` (true when any Override ran on
    this effect, even if it returned the same value), `new_hp`, and `skipped`
    (true when the target was already Knocked Out; no number is shown). A move
    that does not resolve reports one record with `result` = `unaffordable` or
    `no_target`. The Turn Battle System, UI and Combo Codex read these records;
    none of them recompute them.

**Rewards**

12. `Enemy.reward` holds two non-negative integers, `xp` and `money`.
13. Rewards are granted only when the battle is won, once per defeated enemy,
    summed across all enemies in the battle. A lost or fled battle grants
    nothing. This system reports the totals; how XP is split across the squad
    belongs to Leveling & Loyalty, and where money is stored belongs to Items,
    Equipment & Shops *(both Vertical Slice; provisional until designed)*.

### States and Transitions

Each combatant is in exactly one of two states during a battle.

| State | Meaning | Enters when | Leaves when |
|---|---|---|---|
| **Active** | Can act and be targeted | Battle starts with `current_hp > 0` | `current_hp` reaches 0 → **Knocked Out** |
| **Knocked Out** | Cannot act; ignored by `damage` | `current_hp` reaches 0 after the Apply step | Only a revive effect (not in MVP); otherwise stays KO'd until the battle ends |

- `heal` has no effect on a Knocked Out target. Revive is a separate future
  effect type, not a large heal.
- A character KO'd at battle end leaves the battle with 1 HP if the battle was
  won *(provisional: confirm with Turn Battle System / Camp)*. If the whole squad
  is KO'd the battle is lost; what happens next belongs to Game State & Scene
  Flow.

### Interactions with Other Systems

| System | Direction | What flows | Who owns the interface |
|---|---|---|---|
| Content Data Definitions | In | `stat_block`, `Move.cost`, `damage`/`heal` descriptors, `Enemy.reward` (schema only) | This system owns the meaning and ranges; CDD stores and validates them |
| Turn Battle System | In / Out | In: "user X uses move M on target T". Out: affordability check, outcome records, KO events, `speed` | Turn Battle owns sequencing and targeting; this system owns the numbers |
| Quirk State System | In | Modifiers registered against step 2 | Quirk State owns which modifiers exist; this system owns where and in what order they apply |
| Faction Rule Modifiers | In | Modifiers (step 2) and overrides (step 5), plus MP drains (e.g. MegaCorp billing) delivered as effects or costs | Faction Rule Modifiers owns the rules; this system owns the hook points |
| Combo System & Codex | In / Out | In: combo damage as `damage` effects and modifiers. Out: outcome records for the Codex | Combo owns combo logic |
| Enemy AI | Out | Read-only stat and HP/MP queries so AI can judge targets and affordability | This system owns the query results |
| Leveling & Loyalty *(Vertical Slice)* | Out / In | Out: XP total. In: stat growth applied to characters' `stat_block` values | Leveling owns growth curves; this system owns the stat ranges they must stay within |
| Items, Equipment & Shops *(Vertical Slice)* | Out / In | Out: money total. In: equipment stat modifiers (step 2) and item effects | Items owns items; this system owns how their numbers apply |
| UI Framework | Out | Outcome records, current/max HP and MP, full stats for the camp/party screen | UI owns presentation |

## Formulas

> Proposed by `systems-designer` (consulted — Lean mode, high-risk section);
> choices made by the user on 2026-10-20: ratio damage form, attack-scaled heal,
> no heal variance, 0.1×–3.0× multiplier clamp.

### F1. Stat ranges

| Stat | Range (data) | Recruit (start → boss) | Normal enemy (early → late) | MVP boss |
|---|---|---|---|---|
| `max_hp` | 1–999 | 30 → 60 | 20 → 45 | 400 |
| `max_mp` | 0–99 | 10 → 20 | 0 → 10 | 30 |
| `attack` | 1–99 | 12 → 20 | 10 → 18 | 24 |
| `defense` | 0–99 | 8 → 14 | 6 → 12 | 18 |
| `speed` | 1–99 | 10 → 14 | 8 → 12 | 12 |

The middle columns are tuning targets for content authors, not rules. The
ranges are enforced: a stat_block outside them fails content validation.

### F2. Effective stat

The effective_stat formula is defined as:

`stat_eff = clamp((stat + Σstat_flat) × (1 + Σstat_pct), stat_eff_min, stat_eff_max)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| stat | int | per F1 | data file (stat_block) | The base stat |
| Σstat_flat | int | typically −199 to 199 (not clamped) | calculated | Sum of flat stat modifiers (quirks, factions, equipment) |
| Σstat_pct | float | typically −1.0 to 2.0 (not clamped) | calculated | Sum of percent stat modifiers, added, not multiplied |
| stat_eff_min | int | 1 for `attack`, 0 otherwise | constant | Keeps `attack_eff` ≥ 1 so F3 never divides by zero |
| stat_eff_max | int | 199 | data file | Ceiling on any modified stat |

**Output Range:** 0–199 (`attack` 1–199). The sums are not clamped; only the
result is. The product is rounded down (floor) before clamping, so effective
stats are always integers.
**Example:** Defense 14, a +4 flat guard quirk and −25% from a faction rule: (14 + 4) × 0.75 = 13.5 → **13** (floor).

Stat modifiers feed F3 (step 1). Modifiers on the damage or heal *amount* are
F5 (step 2). The two are separate lists; a modifier declares which it is.

### F3. Base damage (pipeline step 1)

The base_damage formula is defined as:

`base_damage = (power / power_scale) × attack_eff² / (attack_eff + defense_eff)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| power | int | 1–100 | data file (Move `damage` effect) | Move strength; 10 = basic attack |
| power_scale | int | 10 | data file | Makes power 10 equal 1.0× |
| attack_eff | int | 1–199 | calculated (F2) | User's effective attack |
| defense_eff | int | 0–199 | calculated (F2) | Target's effective defense |

**Output Range:** 0.0005 (power 1, attack 1, defense 199) to 1,990 (power 100,
attack 199, defense 0). With equal attack and defense it is exactly
`power/10 × attack/2`. Never 0 for any valid input.
**Example:** A recruit (attack 12) basic-attacks an early enemy (defense 6):
1.0 × 144 / 18 = **8.0**, so a 20-HP enemy falls in 3 hits. The MVP boss
(attack 24) hits a late recruit (defense 14): 576 / 38 = **15.2**, so a 60-HP
recruit falls in 4 hits.

*Why ratio, not Dragon Quest subtraction:* subtraction reaches 0 once defense
is about 2× attack, so stacked defense would look like immunity and blur
Bureaucratia's rule. This form never reaches 0, has a fixed ceiling, and
doubling defense gives a predictable drop.

### F4. Base heal (pipeline step 1)

The base_heal formula is defined as:

`base_heal = power × (1 + attack_eff / heal_attack_scale)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| power | int | 1–100 | data file (Move `heal` effect) | Heal strength before scaling |
| attack_eff | int | 1–199 | calculated (F2) | Healer's effective attack |
| heal_attack_scale | int | 50 | data file | Attack needed to add +100% to a heal |

**Output Range:** 1.02 (power 1, attack 1) to 498 (power 100, attack 199);
normal play 15–30 for a power-15 heal. Heals ignore the target's defense.
**Example:** "Coffee Break" (power 15) from a recruit with attack 12:
15 × 1.24 = **18.6**; at attack 20 it is 15 × 1.4 = **21**.

*Trade-off accepted:* a healer with high attack also hits harder. Heal grows
linearly with attack while damage grows faster (F3), so heals cannot outpace
damage by levelling alone. Content guideline: one heal's power should stay at
or below about 1.5× an enemy hit at the same point in the game.

### F5. Amount modifiers (pipeline step 2)

The modified_amount formula is defined as:

`modified_amount = max(0, base + Σflat) × clamp(1 + Σpct, mult_min, mult_max)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| base | float | 0.0005–1,990 (damage) / 1.02–498 (heal) | calculated (F3/F4) | Output of step 1 |
| Σflat | int | −999 to 999 | calculated | Sum of flat amount modifiers |
| Σpct | float | unbounded sum | calculated | Sum of percent amount modifiers, added, not multiplied |
| mult_min | float | 0.1 | data file | Lowest combined multiplier |
| mult_max | float | 3.0 | data file | Highest combined multiplier |

**Output Range:** 0 to 8,967 ((1,990 + 999) × 3.0), clamped to 999 in step 4.
Flat modifiers apply before percent modifiers. Percent modifiers can never
take the multiplier below 0.1×. Flat modifiers can bring the amount to 0, and
F7 then raises it to 1. Stopping damage entirely is an Override's job (step 5).
Modifiers and Overrides apply to heals as well as damage.
**Example:** base 10, +2 flat from equipment, Influencia attention 3 × +25%, and
a −50% quirk: (10 + 2) × clamp(1 + 0.75 − 0.5) = 12 × 1.25 = **15.0**.

### F6. Variance (pipeline step 3)

The varied_amount formula is defined as:

`varied_amount = modified_amount × U(1 − v, 1 + v)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| U | float | 1−v to 1+v | injected RNG | Uniform random multiplier |
| v | float | 0.10 for damage (`damage_variance`), 0.0 for heal (`heal_variance`) | data file | Swing in each direction |

**Output Range:** 0 to 9,864 for damage; heals are unchanged.
The RNG is passed in, never global, so tests seed it or stub it to return 1.0.
Heals do not draw from the RNG at all, so adding or removing a heal never
shifts a seeded sequence.
**Example:** 15.0 × 0.93 = **13.95**.

### F7. Round and clamp (pipeline step 4)

The final_amount formula is defined as:

`final_amount = clamp(floor(varied_amount + 0.5), min_amount, amount_cap)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| varied_amount | float | 0–9,864 | calculated (F6) | Output of step 3 |
| min_amount | int | 1 (`min_damage`, `min_heal`) | data file | Floor after rounding |
| amount_cap | int | 999 (`damage_cap`, `heal_cap`) | data file | Ceiling per effect |

**Output Range:** 1–999. Rounding is half-up.
**Example:** 13.95 → **14**. A varied amount of 0.4 → 0 → raised to **1**.
Only an Override (step 5) can produce 0, so a 0 on screen always means a rule fired.

### F8. Apply (pipeline step 6)

`new_hp = clamp(current_hp − final_damage, 0, max_hp)` for damage;
`new_hp = clamp(current_hp + final_heal, 0, max_hp)` for heal.
The reported amount is the number shown on screen: the full `final_amount`,
even when it exceeds the HP removed (overkill is shown, not trimmed)
*(provisional: confirm with UI Framework)*.

### F9. Reward totals

The reward_totals formula is defined as:

`total_xp = Σ reward.xp over defeated enemies`; `total_money = Σ reward.money over defeated enemies`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| reward.xp | int | 0–9,999 | data file (Enemy) | XP for one enemy |
| reward.money | int | 0–9,999 | data file (Enemy) | Money for one enemy |

**Output Range:** 0 to 9,999 × the most enemies a battle can hold (Turn Battle
System owns that number; at 6 enemies the most is 59,994). A loss or flee
gives 0.
**Example:** 3 Clerks (8 XP, 5 money each) + 1 Supervisor (20 XP, 15 money) =
**44 XP, 30 money**.

## Edge Cases

> `systems-designer` not consulted — Lean mode. Review manually before production.

**Costs and MP**
- **If a combatant's `current_mp` drops below a chosen move's cost before the move resolves** (e.g. MegaCorp billing runs first): the move does not resolve, no MP is spent, and an `unaffordable` outcome is reported. Whether the turn is lost belongs to the Turn Battle System.
- **If every target of a move is Knocked Out or gone when it starts to resolve and Turn Battle finds no replacement**: Core Rule 6 applies — the move does not resolve, no MP is spent, and a `no_target` outcome is reported.
- **If an MP drain would take `current_mp` below 0**: it stops at 0. The drain reports the MP actually removed.

**Resolution order**
- **If a move has several effects**: they resolve in the order listed on the Move record, each through the full pipeline.
- **If a move hits several targets**: each target resolves separately, with its own variance roll, in the target order Turn Battle supplies.
- **If an earlier effect knocks out a target**: later `damage` and `heal` effects on that target are skipped. Each still reports an outcome record with `skipped` = true, and no number is shown.
- **If one move knocks out both the last enemy and the last squad member**: this system reports each KO in the order it happened. Turn Battle decides who wins.

**Amounts**
- **If flat modifiers make an amount negative**: F5 raises it to 0 before the multiplier, and F7 raises the result to 1. The hit still shows 1.
- **If the varied amount rounds to 0**: F7 raises it to 1. Only an Override can show 0.
- **If two or more Overrides apply to the same effect**: they run in ascending `priority`, then by source ID alphabetically. Each sees the previous result, so the last one decides. Faction Rule Modifiers assigns priorities *(provisional until that GDD exists)*.
- **If an Override returns a value outside 0 to `amount_cap`**: it is clamped to 0 to `amount_cap` (the F7 cap, a data value).
- **If damage exceeds the target's remaining HP**: HP goes to 0 and the full amount is shown (F8).
- **If a heal targets a combatant at full HP**: HP is unchanged and the full heal amount is still shown (F8). *(Provisional, linked to F8.)*
- **If a combatant targets itself with damage**: allowed. It uses its own attack and defense.

**Stats and data**
- **If a modifier targets `max_hp` or `max_mp`**: content validation rejects it at MVP. Only `attack`, `defense` and `speed` can be modified in battle, so `current_hp > max_hp` can never happen.
- **If a stat_block value is outside the F1 ranges**: content validation fails with an error naming the record and stat. Nothing is clamped silently.
- **If `attack_eff` would reach 0**: F2 holds it at 1, so F3 never divides by zero.

**Rewards**
- **If an enemy leaves the battle without being knocked out** (removed by a rule or a script): it gives no reward. Only KO'd enemies count.
- **If the battle is fled or lost after some enemies were KO'd**: nothing is given, including for those enemies.

## Dependencies

**Upstream (this system depends on):**

| System | Type | Nature | What it needs |
|---|---|---|---|
| Content Data Definitions | Hard | Cannot compute anything without stat blocks, costs and effect descriptors | `stat_block`, `Move.cost`, `damage`/`heal` EffectDescriptors, `Enemy.reward`; validation of F1 ranges and the max_hp/max_mp modifier ban |

CDD's Dependencies table already lists this system as a hard downstream
dependent needing `stat_block`, `reward` and costs, so this link is two-way.

**Downstream (these systems depend on this one):**

| System | Type | What it needs | GDD status |
|---|---|---|---|
| Turn Battle System | Hard | Affordability checks, resolution, outcome records, KO events, `speed` | Not started |
| Quirk State System | Hard | Stat (F2) and amount (F5) modifier hooks | Not started |
| Faction Rule Modifiers | Hard | Modifier hooks, Override hook (step 5) with priorities, MP drain | Not started |
| Combo System & Codex | Hard | `damage` resolution and outcome records | Not started |
| Enemy AI | Hard | Read-only stat, HP and MP queries | Not started |
| Leveling & Loyalty *(Vertical Slice)* | Hard | XP totals (F9); F1 stat ranges as growth limits | Not started |
| Items, Equipment & Shops *(Vertical Slice)* | Hard | Money totals (F9); modifier hooks for equipment; `heal` resolution for items | Not started |
| UI Framework | Soft | Outcome records, HP/MP values, full stats for the camp screen (works with placeholder text without them) | Not started |

**Index gap:** `systems-index.md` lists only Turn Battle, Quirk State, Enemy AI,
Leveling & Loyalty and Items as depending on this system. Faction Rule
Modifiers, Combo System & Codex and UI Framework also depend on it, through the
modifier, Override and outcome-record hooks. Each of those GDDs must list this
system as a dependency when written.

## Visual/Audio Requirements

> Drafted with `art-director` (consulted — Lean mode; this system's numbers are
> how the player reads faction rules). Sources: art bible §1–4.

**Scope.** Only the outcome-record events this system emits. Move VFX belong to
moves and Turn Battle; faction rule meters belong to their faction GDDs.

**Visual feedback**

| Event | Treatment | Non-color backup |
|---|---|---|
| Damage number | Chalk-white pixel numerals with a 2px Outline Ink border. They pop with a small overshoot, hold, then fade. Hit-flash and a short shake on the target (Principle 2: "motion carries the hurt") | Downward pop and shake |
| Heal number | Heal Leaf numerals with a "+" prefix. They rise slowly; the sprite brightens softly | "+" glyph, rising motion |
| Override result (incl. 0) | Not a number style. The result sits inside the **firing faction's rule shape and color**. Bureaucratia: a Stamp Red rectangular DENIED stamp slams over the target with a small "0". No hit-flash, no shake: the target visibly does not flinch, and that stillness is the joke. A non-zero override uses the same frame around its number | Faction shape (square, circle, wedge, star) plus the missing impact |
| Large hit (threshold TBD) | Larger cream numerals in a jagged frame (reuses the art bible's "Critical" treatment), longer hit-stop, stronger shake | Size and frame shape |
| KO | The number resolves first, then the HP bar empties, then the defeated-slump frame and a pop/poof. Overkill shows the full number (F8); the KO beat never covers it | Pose and exit animation |
| MP spend | Small cream "−N" with an MP glyph near the actor's HUD plate, not over the target. MP bar ticks down. Quiet | MP glyph, sits at the HUD |
| MP drain (MegaCorp) | Terminal Cyan wedge-shaped invoice tag ("−N MP, BILLED") slides in at the victim's HUD plate | Wedge shape, invoice icon |
| HP bar change | Two layers: the fill snaps to the new HP, then a cream "ghost" segment drains to match over about 0.4 s (a Heal Leaf ghost for heals). The bar is neutral navy/cream and never takes a faction color | Ghost-segment direction |

**Readability constraints**
- Numerals use the shared pixel scale, integer upscaling only. Minimum height about 4% of screen height (more for large hits). A single number stays about 0.8–1.0 s.
- **Stacking:** several targets → all numbers pop at the same moment, one above each target. Several effects on one target → each new number is offset upward and staggered about 0.12 s. Never merge numbers. An override takes visual priority over a number on the same target.
- Numbers and tags are flat, unlit UI. They ignore scene color grading and boss lighting (§4 UI vs world).
- No event relies on color alone (§4).
- Faction color appears only when an override or drain fires; normal numbers are neutral (§4 "faction color means a rule, never a result").

**Audio intent** (mood only; `audio-director` owns specs)
- Damage: a meaty, toy-like thwack. Large hit: a heavier crunch with hit-stop.
- Heal: a rising chime.
- Override: the faction's own sting (stamp thunk, notification ping, register cha-ching, anthem sting); the impact sound is withheld.
- KO: a comic deflate or poof.
- MP spend: a soft tick. MP drain: a cash-register ka-ching.
- HP bar drain: silent or a very faint tick.

**Art bible principles that apply most:** the Visual Rule (rules told in color,
light and shape; an override is where joke and rule are the same event);
Principle 2 (numbers read second only to the actors); Principle 3 and §4
(faction color means a rule); §3 UI shape grammar (faction-shaped means a
faction rule).

> 📌 **Asset Spec** — Visual/Audio requirements are defined. After the art
> bible is approved, run `/asset-spec system:stats-damage-resolution` to produce
> per-asset visual descriptions, dimensions and generation prompts from this
> section.

## Game Feel

This system's feel is about **pace and legibility of numbers**, not input
response (it has no direct input). Targets:

| Feel target | Spec | Why |
|---|---|---|
| Fights end at a brisk pace | Normal enemy: 2–4 squad hits to KO. Recruit: 4–6 enemy hits to KO. MVP boss: about 6–10 rounds with a full squad (F1 + F3 targets) | DQ pacing without grind (concept: "no grind loops") |
| Resolution never waits | All math for an action finishes before its first number appears (see the performance criterion). Animation timing is the only delay | Players should never feel the game "thinking" |
| Numbers match the hit | A damage number appears on the impact frame of the move's animation, not at the start of the action *(Turn Battle / Sprite & Camera own the impact frame)* | Number and impact land together, which makes hits feel chunky |
| HP bars confirm the number | The bar drains over 0.3–0.5 s after the number appears, with a lingering "ghost" segment showing the chunk lost | The size of the hit is felt, not only read |
| Multi-hits have rhythm | Multi-target results pop together, one above each target. Several effects on one target appear in sequence about 0.12 s apart, never on one frame (see Visual/Audio) | Each number stays readable; a combo on one target feels like a combo |
| A rule-break feels different from a weak hit | An Override result (0, or a forced value) has its own timing beat: a short hold before the number appears | The punchline lands; "0" reads as "the rule fired", not "I missed" |
| Variance is felt, not noticed | ±10% damage: repeated hits differ slightly; no hit is ever surprisingly large or small | Liveliness without luck deciding fights |

All durations above are tuning targets for UI Framework and Turn Battle, not
values this system enforces.

## UI Requirements

This system supplies data; the UI Framework owns layout. What must be shown:

| Where | Must show | Source |
|---|---|---|
| Battle — each squad member | Name, current/max HP as numbers and a bar, current/max MP as numbers and a bar, KO state | Runtime values, `stat_block` |
| Battle — each enemy | HP bar only (no numbers), KO state. Boss HP bar is larger | Runtime values |
| Battle — floating numbers | Every outcome record: damage, heal, Override result, MP spent, MP drained | Outcome records (Core Rule 11) |
| Battle — command menu | Each move's MP cost; moves the user can't afford are visibly disabled and say why | `Move.cost`, affordability check (Core Rule 5) |
| Camp / party screen | All five stats for each character, with effective values and the modifiers behind them when any apply (e.g. "Defense 14 → 18, +4 Unionized") | `stat_block`, F2 |
| Battle results | XP and money totals | F9 |

- Enemy HP stays numberless in battle so bosses don't become a math exercise;
  the bar is enough to plan *(open question: reveal numbers via a scan move or
  the Codex?)*.
- Any modified value shown anywhere must say what modified it. Hidden modifiers
  break the "rule-breaks are readable" goal.

> **📌 UX Flag — Stats & Damage Resolution**: This system has UI requirements. In
> Pre-Production, run `/ux-design` to create a UX spec for each screen or HUD
> element it contributes to (battle HUD, command menu, camp party screen,
> results screen) **before** writing epics. Stories that reference UI should
> cite `design/ux/[screen].md`, not this GDD directly.

## Cross-References

| This document | References | In | Relationship |
|---|---|---|---|
| Core Rules 1–3, F1 | `stat_block` schema on Character and Enemy | `content-data-definitions.md` — record types table | This GDD owns the meaning and ranges; CDD stores and validates |
| Core Rules 4–6 | `Move.cost` | `content-data-definitions.md` — record types table | Owned here |
| Core Rule 7 | EffectDescriptor `type` ownership (rule 4) | `content-data-definitions.md` — Detailed Design rule 4 | CDD assigns `damage`/`heal` to this system |
| Core Rules 12–13, F9 | `Enemy.reward` | `content-data-definitions.md` — record types table | Owned here |
| Edge Cases (Stats and data) | Validation errors name record and field; nothing clamped silently | `content-data-definitions.md` — Edge Cases (Structure) | Same strict-validation stance |
| Overview, Edge Cases | Bureaucratia "immune until Approved", MegaCorp billing, Influencia attention | `game-concept.md` — Unique Hook | Behaviour realized via Override and modifier hooks; rules owned by Faction Rule Modifiers (not yet designed) |
| Visual/Audio | Faction colors and shapes | `art/art-bible.md` §3–4 | Feedback uses the art bible's faction language |
| Dependencies | Systems depending on this one | `systems-index.md` | Index is missing three dependents (see Dependencies) |

## Acceptance Criteria

> Drafted with `qa-lead` (consulted — Lean mode, high-risk section).

**Test conventions.** The RNG is always injected: tests stub it to a fixed value
or seed it. Floats are compared with a 1e-6 tolerance (`is_equal_approx`), never
exact equality. Fixtures are factory functions in
`tests/unit/stats_damage/fixtures/`: `recruit_start` (attack 12, defense 8),
`recruit_late` (attack 20, defense 14), `enemy_early` (defense 6), `mvp_boss`
(attack 24), `even_pair` (attack 20 vs defense 20), `clerk` (8 XP, 5 money),
`supervisor` (20 XP, 15 money). Tuning constants (`power_scale`,
`heal_attack_scale`, `damage_variance`, `mult_min`, `mult_max`, caps, floors,
`stat_eff_max`) are injected from config, never hardcoded in the resolver.
Bare numbers appear only in boundary tests.

**Tags:** **[L]** Logic — automated gdUnit4 test under `tests/unit/stats_damage/`
(BLOCKING). **[I]** Integration — CDD validation test or static check. **[P]**
Performance benchmark.

**Stubs for undesigned systems** (they implement this system's own hook
interfaces, so no test waits on another GDD): **[stub:QS]** a fake modifier
source (Quirk State); **[stub:FR]** a fake Override or MP drain (Faction Rule
Modifiers); **[stub:TB]** a fake caller supplying targets, replacements and the
battle result (Turn Battle).

**Stat block and effective stats**
- **AC-1 [I]** (Rule 1, F1) GIVEN stat_blocks with one stat one step outside its range — `max_hp` 0 and 1000, `max_mp` −1 and 100, `attack` 0 and 100, `defense` −1 and 100, `speed` 0 and 100 — and one with a sixth stat field, WHEN the catalog validates, THEN each produces a CDD error naming the record and stat. A stat_block at every minimum and one at every maximum both load, and no value is clamped.
- **AC-2 [L] [stub:QS]** (F2) GIVEN defense 14 with +4 flat and −25%, WHEN the effective stat is computed, THEN it is exactly 13 (floored), and a hit on that target passes `defense_eff` = 13 to F3.
- **AC-3 [L] [stub:QS]** (F2 bounds) GIVEN attack 1 with −10 flat, defense 5 with −10 flat, and attack 99 with +199 flat and +200%, WHEN computed, THEN the results are 1, 0 and 199, and F3 with `attack_eff` 1 and `defense_eff` 0 returns a finite value without error.
- **AC-4 [I]** (Edge: max_hp/max_mp) GIVEN a content modifier targeting `max_hp`, and separately one targeting `max_mp`, WHEN validated, THEN each is an error; modifiers on `attack`, `defense` and `speed` load.
- **AC-5 [L] [stub:QS]** (Rule 2) GIVEN speed 10 and a +2 speed modifier, WHEN Turn Battle queries speed, THEN it receives 12 (effective speed).
- **AC-6 [L]** (Rule 3) GIVEN an enemy, WHEN a battle starts, THEN `current_hp == max_hp` and `current_mp == max_mp`. GIVEN a character carrying 17 of 40 HP, WHEN a battle starts, THEN `current_hp` is 17. AFTER the battle, the content records deep-equal their loaded values.

**Costs and MP**
- **AC-7 [L]** (Rules 4–5) GIVEN `current_mp`/cost of 5/5, 5/6 and 0/0, WHEN affordability is checked, THEN the results are affordable, not affordable, affordable.
- **AC-8 [I]** (Rule 4) GIVEN a Move with cost −1, WHEN validated, THEN CDD rejects it; a lint over shipping content confirms every combatant's basic attack costs 0.
- **AC-9 [L] [stub:FR]** (Rule 6) GIVEN a cost-3 move and an Override forcing damage to 0, WHEN it resolves, THEN `current_mp` drops by 3 before the first outcome is reported and is not refunded after the 0 outcome.
- **AC-10 [L] [stub:FR]** (Rule 6, unaffordable) GIVEN a cost-5 move chosen at 5 MP and a drain to 2 MP before it resolves, WHEN it resolves, THEN one outcome with `result` = `unaffordable` is reported, `current_mp` stays 2, the target's HP is unchanged and no damage outcome is emitted.
- **AC-11 [L] [stub:TB]** (Rule 6, no target) GIVEN a cost-4 move whose targets are all Knocked Out and no replacement, WHEN it resolves, THEN one outcome with `result` = `no_target` is reported and `current_mp` is unchanged.
- **AC-12 [L] [stub:FR]** (Edge: MP drain) GIVEN 3 MP and a drain of 5, WHEN applied, THEN `current_mp` is 0 and the drain reports 3 removed.

**Effect types and hits**
- **AC-13 [L]** (Rule 7) GIVEN an EffectDescriptor of type `quirk`, WHEN passed to the resolver, THEN it raises an error naming the type, and HP, MP and outcome records are unchanged.
- **AC-14 [L]** (Rule 8) GIVEN power 1, `attack_eff` 1 and `defense_eff` 199, WHEN resolved 1,000 times with a fixed seed, THEN every final amount is at least 1, and the outcome record has no miss, dodge or crit field.
- **AC-15 [L] [stub:QS]** (Rule 8, readability) GIVEN base 15.0, WHEN varied with no modifier at RNG 1.1 and with a single +25% modifier at RNG 0.9, THEN the varied (pre-rounding) amounts are 16.5 and 16.875, and the modified minimum is greater than the unmodified maximum.

**Formulas**
- **AC-16 [L]** (F3, power 10) GIVEN `recruit_start` vs `enemy_early`, `mvp_boss` vs `recruit_late`, and `even_pair`, WHEN base damage is computed, THEN the results are 8.0, 15.1579 and 10.0. Integer-division guard: power 15 with 12 vs 6 gives 12.0, not 8.0.
- **AC-17 [L]** (F3 bounds) GIVEN power 1, attack 1, defense 199, and power 100, attack 199, defense 0, WHEN computed, THEN the results are 0.0005 (> 0) and 1,990.0.
- **AC-18 [L]** (F4) GIVEN power 15, WHEN healed by `attack_eff` 12 and 20, THEN base heal is 18.6 (not 15) and 21.0. Bounds: power 1/attack 1 gives 1.02; power 100/attack 199 gives 498.0. The same heal on targets with defense 0 and 99 gives identical amounts.
- **AC-19 [L] [stub:QS]** (F5) GIVEN base 10, +2 flat, three +25% and one −50%, WHEN modified, THEN the result is 15.0. GIVEN base 10, +2 flat and +100%, THEN 24.0 (flat before percent), not 22.0.
- **AC-20 [L] [stub:QS]** (F5 clamps, Edge: negative) GIVEN base 10 with Σpct −2.0, base 10 with Σpct +5.0, and base 5 with −20 flat, WHEN modified, THEN 1.0 (0.1× floor), 30.0 (3.0× ceiling), and 0 — which F7 raises to a final 1.
- **AC-21 [L]** (F6) GIVEN 15.0 damage, WHEN the RNG is stubbed to 0.93, 0.90 and 1.10, THEN 13.95, 13.5 and 16.5. A seeded RNG over 10,000 rolls stays within [0.9, 1.1]. GIVEN a heal of 18.6, WHEN resolved, THEN it stays 18.6 and the RNG stub records zero calls.
- **AC-22 [L]** (F7, damage and heal) GIVEN varied amounts 13.95, 14.5, 14.49, 0.4 and 1,200.0, WHEN rounded and clamped, THEN 14, 15, 14, 1 and 999. With `damage_cap` injected as 500, 600.0 gives 500.

**Pipeline, overrides and apply**
- **AC-23 [L] [stub:QS] [stub:FR]** (Rule 9 order) GIVEN `even_pair` (base 10.0), +2 flat, +25% and the RNG stubbed to 1.06, WHEN resolved with no Override, THEN the final amount is 16 (12 × 1.25 × 1.06 = 15.9). WHEN an Override returning 7 is added, THEN the final amount is 7 and `overridden` is true.
- **AC-24 [L] [stub:FR]** (Edge: multiple Overrides) GIVEN Override A (priority 20) returning 0 and B (priority 10) returning 50, THEN the final is 0. GIVEN equal priority, `faction_b` returning 3 and `faction_a` returning 9, THEN `faction_b` runs last and the final is 3. GIVEN an Override returning 1,500, THEN 999; returning −5, THEN 0. GIVEN an Override that returns its input unchanged, THEN `overridden` is still true.
- **AC-25 [L]** (F8, States) GIVEN damage 14 on a target at 10/40 HP, WHEN applied, THEN HP is 0, the reported amount is 14, the target is Knocked Out and a KO event fires. GIVEN a heal of 21 on a target at 35/40, THEN HP is 40 and the reported amount is 21.
- **AC-26 [L]** (Rule 11) GIVEN any damage or heal resolution, WHEN it completes, THEN exactly one outcome record is emitted with `user`, `target`, `effect_type`, `final_amount`, `overridden`, `new_hp` and `skipped`, all matching the inputs and results.
- **AC-27 [I]** (Rule 10) GIVEN the code root, WHEN a static check runs, THEN no code outside the resolver's Apply step assigns `current_hp`, and `current_hp` has no public setter.
- **AC-28 [L] [stub:TB]** (Edge: KO skip, multi-effect, multi-target) GIVEN a move with effects [damage, damage, heal] on a target at 5 HP where the first damage knocks it out, WHEN resolved, THEN the second damage and the heal each emit a record with `skipped` = true and no amount, HP stays 0 and the target stays Knocked Out. GIVEN two identical targets and the RNG returning [0.9, 1.1], THEN the amounts use those rolls in Turn Battle's target order.
- **AC-29 [L]** (Edge: self-target) GIVEN a combatant with attack 20 and defense 20 using a power-10 damage move on itself, WHEN resolved with the RNG stubbed to 1.0, THEN it takes 10 damage.

**Rewards**
- **AC-30 [L] [stub:TB]** (F9, Rule 13) GIVEN three `clerk` and one `supervisor`, WHEN all are knocked out and the battle is won, THEN 44 XP and 30 money. WHEN the battle is lost or fled after two Clerks are knocked out, THEN 0 and 0. WHEN won but the Supervisor was removed without a KO, THEN 24 XP and 15 money.
- **AC-31 [I]** (Rule 12) GIVEN `reward.xp` −1 and `reward.money` 10000, WHEN validated, THEN CDD rejects both; 0 and 9,999 are accepted.

**Performance**
- **AC-32 [P]** GIVEN one `damage` effect with 3 stat modifiers, 3 amount modifiers and 1 Override, WHEN resolved 10,000 times headless on the development PC with a seeded RNG, THEN the median time per resolution is under 50 µs. *Why:* a worst-case move (6 targets × 3 effects = 18 resolutions) then stays under 1 ms, about 5% of a 16.6 ms frame. *Provisional:* target hardware is an open question, as in Content Data Definitions.

**Not yet covered** (provisional rules waiting on their owners): camp HP/MP
restoration timing, KO'd characters leaving a won battle at 1 HP, F9's upper
bound (Turn Battle's maximum enemy count), and "a 0 on screen always means a
rule fired" — a [UI] screenshot criterion that belongs in the UI Framework GDD.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **When are HP and MP restored?** Assumed: full restore at camp (Core Rule 3). | Camp & Party Management GDD | When that GDD is designed |
| 2 | **Does a KO'd character leave a won battle at 1 HP?** (States and Transitions) | Turn Battle System / Camp GDDs | When Turn Battle is designed |
| 3 | **Overkill and over-heal display:** show the full amount (F8) or only what HP actually changed? | UI Framework + user | Before `/ux-design` for the battle HUD |
| 4 | **Override priority values:** who assigns them, and what range? (Edge Cases) | Faction Rule Modifiers GDD | When that GDD is designed |
| 5 | **Can quirks register Overrides, or only factions?** If quirks can, a non-faction override needs its own frame in the sticker-tag grammar. | Quirk State System GDD + art-director | When Quirk State is designed |
| 6 | **Large-hit threshold:** absolute (≥500), relative (% of target max HP), or cap only (999)? | art-director + user | Before `/asset-spec` for this system |
| 7 | **Art bible "Critical" treatment:** this game has no crits. Reuse it as "Large hit" (proposed), or remove it? Needs an art bible edit either way. | art-director | Before the art bible is approved |
| 8 | **MP color:** the palette has none, and classic MP blue clashes with Anthem Blue and Terminal Cyan. Proposed: neutral cream plus an MP glyph. | art-director | Before the art bible is approved |
| 9 | **Enemy HP numbers:** hidden in battle (UI Requirements). Should a scan move or the Codex reveal them? | user + game-designer | Before `/ux-design` for the battle HUD |
| 10 | **Maximum enemies per battle**, which sets F9's upper bound. | Turn Battle System GDD | When Turn Battle is designed |
| 11 | **Target hardware** for the AC-32 performance budget (shared with Content Data Definitions Open Question 4). | user + performance-analyst | Before Vertical Slice |
| 12 | **Modifiers under ~23%** can be hidden by variance (Core Rule 8). Should content validation warn about them? | systems-designer | When Quirk State / Faction Rule Modifiers are designed |
