# Leveling (lite)

> **Status**: Designed (lean; written 2026-11-03 for v1, during an autonomous run)
> **System**: Leveling & Loyalty, systems index 14. This doc covers **leveling only**; loyalty stays undesigned.
> **Depends on**: Stats & Damage Resolution (F9 rewards, stat blocks), Content Data Definitions (Character records), Save/Load (ADR-0009)
> **Direction**: classic Dragon Quest-style JRPG (user ruling 2026-11-03, game concept revision note)

## 1. Overview

Each squad member has a level and a running XP total. When a battle is won, every member still standing earns the battle's full XP (F9). Crossing a level's threshold raises that member's stats by their character's growth. Levels, XP, HP and MP are saved. The battle's money goes into the squad's wallet, kept for shops later.

## 2. Player Fantasy

You watch your misfits get visibly tougher across the Paris chapter, the classic Dragon Quest beat of "Karen reached level 3!". A fight you scraped through early is one you walk through by the boss. A member who got knocked out sits that fight's XP out, so keeping everyone standing pays off.

## 3. Detailed Rules

1. Every member starts New Game at **level 1 with 0 XP**.
2. **XP award:** on Victory, every member with HP above 0 at the end of the fight gains `total_xp` (F9) in full. It is not split. Knocked-out members gain nothing. Fled and Defeat give nothing (F9).
3. **Level-up:** while a member's XP is at or above `xp_total(level + 1)`, they gain a level, up to `level_max`. Several levels can be gained from one award.
4. **Growth:** each level gained adds the character's `growth_*` (Character record) to `max_hp`, `max_mp`, `attack`, `defense` and `speed`. **Current HP and MP rise by the same amount**, so damage already taken stays taken, as in Dragon Quest.
5. **Money:** on Victory, `total_money` (F9) is added to the squad's wallet (`WorldState.money`). Nothing spends it yet.
6. **Shown:** the results screen lists one line per level gained, for example "Karen reached level 3!".
7. **Saved:** each member's level, XP, HP and MP, keyed by character ID. On load, stats are rebuilt from the record, `base + growth × (level − 1)`, and never stored.

## 4. Formulas

- `xp_total(L) = xp_curve_k × L × (L − 1)`. This is the total XP needed to reach level L. With k = 10: L2 = 20, L3 = 60, L4 = 120, L5 = 200, L6 = 300.
- `stat(L) = base_stat + growth_stat × (L − 1)` for each of the five stats.
- **Worked chapter total:** the Paris fights field 29 Clerks (8 XP each) plus the Supervisor fight (20 + 3 × 8). That is 232 + 44 = **276 XP** for a member who never gets knocked out, which is about level 5.

## 5. Edge Cases

- **A member knocked out in a won fight:** gains no XP. Camp later restores their HP, but the XP is not made up.
- **An award past several thresholds:** levels up repeatedly in one award, with one line per level.
- **At `level_max`:** XP still accumulates, but no level is gained.
- **A save naming a character the catalog no longer has:** that entry is dropped and reported. Members missing from the save start at level 1.
- **Corrupt numbers in a save:** level is clamped to [1, `level_max`], XP to ≥ 0, and HP/MP to [0, max]. Each clamp is reported.

## 6. Dependencies

- Stats & Damage Resolution: F9 totals and the five-stat block.
- Content Data: the Character record gains `growth_hp`, `growth_mp`, `growth_attack`, `growth_defense` and `growth_speed`.
- Save/Load: a new `squad` participant.
- Camp: restores HP and MP (Stats & Damage rule 3), not levels.

## 7. Tuning Knobs

| Knob | Default | Range | Effect |
|---|---|---|---|
| `xp_curve_k` | 10 | 6–20 | Higher means slower leveling |
| `level_max` | 99 | 20–99 | Cap |
| `growth_*` per character | see Character records | 0–10 | Per-level stat gains; sets each character's role |

v1 growth, chosen by role:

| Character | HP | MP | ATK | DEF | SPD |
|---|---|---|---|---|---|
| Baguette Thrower (striker) | 3 | 1 | 2 | 1 | 1 |
| Florida Man (bruiser) | 4 | 1 | 2 | 1 | 1 |
| Karen (tank) | 4 | 1 | 1 | 2 | 1 |
| Five-Star Chef (healer) | 3 | 2 | 1 | 1 | 1 |

## 8. Acceptance Criteria

- **AC-1:** on Victory with 40 XP, a level-1 member at 0 XP who is standing reaches level 2 with 40 XP, and their stats rise by exactly their growth. A knocked-out member gains nothing.
- **AC-2:** an award of 120 XP to a level-1 member gives level 4 and three level-up lines.
- **AC-3:** a save and load keeps each member's level, XP, HP and MP, and rebuilds stats from `base + growth × (level − 1)`.
- **AC-4:** New Game starts everyone at level 1, 0 XP and full HP/MP, with an empty wallet.
- **AC-5:** the results screen shows one line per level gained.
