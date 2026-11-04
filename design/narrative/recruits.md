# Recruits beyond the first four

> Written 2026-11-04 at `rigor: minimal`. Picks writing.md **D-9 → A** (Claude
> proposes six, one per region). **Status: DEFAULT, not user-approved.** Change
> any row and the records in `data/characters/` follow.

Each recruit is a caricature of a **behaviour and a prop**, never of a body,
an ethnicity or a nationality (narrative bible §8.3; art bible §1). Each
specials kit uses the five existing effect types (stun, heal one, heal party,
vulnerable, direct damage). There are no quirks and no combos (classic JRPG
combat, 2026-11-03).

## How joining works

- New Game starts with the four (records with no `joins_on_flag`).
- A recruit joins when their region's liberation flag is set (the boss
  Victory). The line "X joins the squad!" shows on the walk home's first map.
- They join at the squad's average level (rounded down) with full HP/MP.
- The first **4** in the roster fight. Everyone else waits on the bench and
  gets no XP. Swap them in **Menu > Party > (member) > Bring into the party /
  Send to the bench**. A swap that leaves nobody standing in the party is
  refused.
- The save keeps who joined (their level, XP, HP, MP and gear) and the order.

## The six

| Recruit | Region (joins on) | Personality line | Specials | Stat role |
|---|---|---|---|---|
| **Street Mime** | Paris (`paris_liberated`) | Has been trapped in an invisible box since 2009 and is finally ready to talk about it. Silently. | *Invisible Rope*: one enemy takes more damage for 2 rounds (3 MP). *Trapped in a Box*: stuns one enemy, not bosses (5 MP) | Support / debuffer, sturdy (DEF 10) |
| **Rush-Hour Commuter** | London (`london_liberated`) | Has never once missed the 8:12. Umbrella in one hand, cold coffee in the other. | *Brolly Jab*: power-14 hit (3 MP). *Elbow Through the Doors*: power-22 hit (6 MP) | Fast striker (SPD 15, ATK 15, DEF 7) |
| **Infomercial Host** | USA (`usa_liberated`, future) | Cannot stop selling. Headset mic always on. Call now. | *But Wait, There's More!*: power-20 hit (5 MP). *Limited-Time Offer*: one enemy takes more damage for 3 rounds (4 MP) | Attacker / debuffer |
| **Boxing Kangaroo** | Sydney (`sydney_liberated`, future) | Wears the gloves to every occasion, including brunch. | *One-Two*: power-16 hit (3 MP). *Pouch Snack*: heals one ally 10 (4 MP) | Bruiser (HP 42, ATK 16, low MP) |
| **The Goalie** | Toronto (`toronto_liberated`, future) | Blocks everything. Shots, doors, conversations. | *Penalty Box*: stuns one enemy, not bosses (5 MP). *Team Huddle*: heals the party 5 (6 MP) | Tank (HP 44, DEF 12, slow) |
| **Fitness Instructor** | Mexico City (`mexico_city_liberated`, future, city provisional) | Whistle, stopwatch and a smile that never rests. Five more minutes! | *Hydration Break*: heals the party 6 (6 MP). *Cool-Down Stretch*: heals one ally 12 (3 MP) | Healer (MP 15) |

The base stats and growth sit inside the starters' ranges: HP 30-44, MP 9-15,
ATK 11-16, DEF 7-12, SPD 8-15, with growth of 3-5 HP and 1-2 for everything
else. Special powers sit next to Home Run (18 for 4 MP) and Appetizer (heal 10
for 3 MP).

## Placeholders

There is no art yet. Each recruit's battle set (`sprite_<id>`, marked
`is_placeholder`) borrows a starter's strips, recoloured to one flat fill in
an Outline Ink edge by `tools/art/recruit_placeholder_sprites.gd`. The
silhouette lineup check skips placeholder sets. The art rows are in
`production/asset-requests/art.md` § Recruits.

The four future regions' flags are never set yet, so those four recruits
exist as data only.
