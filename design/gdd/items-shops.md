# Items & Shops

> **Status**: Designed. Consumables, the camp shop, menu item use and equipment were built 2026-11-04.
> **System**: #16 in `systems-index.md`. Rigor: `standard`.
> **Owner**: economy-designer. **Created**: 2026-11-04, autonomous run (user: "keep building"; classic JRPG direction, 2026-11-03).

## 1. Overview

The squad carries a bag of consumables, buys them with Victory money at a camp's shop, and uses them in battle as a command alongside Attack, Defend and the Specials. Items are the classic JRPG safety net. They also give the player one honest way round a faction rule: an item is not a Special, so Bureaucratia's permit ban never blocks it. Each hero also has a weapon slot and an outfit slot for gear bought at the same shop.

## 3. Detailed Rules

1. **The bag.** `WorldState.inventory` holds item id → count. It is saved with the rest of `WorldState`, emptied by New Game, and shared by every battle and every camp.
2. **The cap.** At most `max_per_item` of one item. A purchase that would go over it is refused, and the money is kept.
3. **Records.** Items are `item_` records (`data/items/`, `ItemData`). This version reads only `kind = "consumable"` records, and only their first `effects` entry: `{type, amount}`, with type `heal_hp`, `restore_mp`, `revive` or `heal_party`. These four types are registered as the `items` system's vocabulary at boot.
4. **Using an item in battle.** On a squad member's turn, the command menu lists **Items** under the moves, disabled ("the bag is empty") when the bag is empty. Choosing it opens the bag; choosing an item opens a target pick among the allies it would help. Using an item takes the user's turn, costs no MP and spends one from the bag. An item is not a Special, so a Special ban (Bureaucratia) never blocks it. A faction rule's own `move_allowed()` still applies: a MegaCorp-suspended member (0 MP) can only Attack, so they cannot use items, but an ally can use one on them. On screen, the user plays the brief defend pose and the recipient plays its heal reaction.
5. **Effects.**
   - `heal_hp`: one living ally regains `amount` HP (F1).
   - `restore_mp`: one living ally regains `amount` MP (F1).
   - `revive`: one knocked-out ally returns at `amount`% of max HP (F2). A revived member acts on their next turn this round if their slot has not come up yet; otherwise next round.
   - `heal_party`: every living ally regains `amount` HP (F1). The knocked-out stay down.
6. **Never spent for nothing.** An item is refused, and nothing is spent, when it would do nothing: an HP item on someone at full HP, an MP item on someone at full MP, a revive on someone standing, or a party heal when everyone standing is at full HP. The menu disables such an item ("No one needs it") and offers only targets it would help.
7. **Retry refunds.** A lost battle's Retry restores the bag to what it held when the fight started, as it restores HP and MP (no lost progress).
8. **Shops live at camps.** `data/config/shop_config.tres` lists each camp's shelf (`stock_by_camp`), in shelf order. A camp with no entry and an empty `default_stock` has no shop. Paris's café (`camp_paris_cafe`) sells all four Paris items.
9. **Buying.** The camp screen lists **Set out**, then **Shop**. Set out is first and highlighted, so one confirm still leaves, as before. The shop lists each item with its price and how many are in the bag, plus Done. Confirm buys one; the price leaves the wallet. The reason is shown when a purchase is refused (not enough money, bag full). Cancel or Done returns to the camp screen. Selling is not in this version.

10. **Equipment.** An `item_` record with `kind = "equipment"` whose first effect is `{type: "equip", slot: "weapon"|"outfit", attack, defense, user}`. `user` names the one character who can use it; empty means anyone. Each hero has one weapon slot and one outfit slot. Paris weapons are each hero's own (ATK +4, price 30). The outfits fit anyone: Resolute Beret (DEF +2, price 20) and Trench Coat (DEF +3, price 40).
11. **Equipping.** Open the Menu outside battle, choose **Party**, then a member, then a slot. The slot list shows each fitting item in the bag, plus **Take off**. Equipping takes the item out of the bag and puts whatever the slot held back into it. It is refused when the old item's stack is full. Gear is bought at the shop like any item.
12. **Bonuses.** Gear adds flat ATK and DEF on top of the levelled stats (`effective_attack()`/`effective_defense()`), and Stats & Damage F3 reads those effective values. Leveling still sets only the base stats. Each member's equipment is saved by slot and id in the `squad` save section, and its bonuses are recomputed from the records on load. A save from before equipment existed loads with empty slots.

## 4. Formulas

**F1, flat restore.** `new = min(max, current + amount)`. The amount restored is `new − current`. No stat scaling, unlike the Chef's Specials (Stats & Damage F4), so an item's value is the same whoever uses it.

**F2, revive.** `hp = max(1, floor(max_hp × amount / 100))`. With `amount` 50 and max HP 31, `hp = 15`.

**Price guide.** A Paris street fight pays 10–25 money (2–5 Clerks × 5, Leveling F9), and the chapter pays roughly 150 in total. A croissant (8) costs about half a fight, and a picnic basket (35) about two fights.

| Item | Effect | Amount | Price |
|---|---|---|---|
| Croissant (`item_croissant`) | `heal_hp` | 25 | 8 |
| Espresso (`item_espresso`) | `restore_mp` | 10 | 12 |
| Unpasteurised Cheese (`item_unpasteurised_cheese`) | `revive` | 50% | 30 |
| Picnic Basket (`item_picnic_basket`) | `heal_party` | 20 | 35 |

**City cafés (2026-11-04).** Each later café sells its own stock, one tier up per chapter: amounts grow with the squad's HP (about 1.6× per chapter), and prices grow with fight pay (about 1.6× per chapter). Weapons fit the recruit who joins in that city.

| Café | Single heal | MP | Revive | Party heal | Weapon | Outfit |
|---|---|---|---|---|---|---|
| London | Bacon Butty 45 / 14 | Builder's Tea 16 / 18 | Sticky Toffee Pudding 60% / 45 | Full English 35 / 55 | Rolled Broadsheet (Commuter) ATK +6 / 60 | Waxed Raincoat DEF +5 / 70 |
| Sydney | Meat Pie 70 / 22 | Flat White 24 / 26 | Lamington 75% / 60 | Pavlova 50 / 80 | Ringside Gloves (Kangaroo) ATK +8 / 90 | Wide-Brim Sun Hat DEF +7 / 100 |
| New York | Street Pretzel 100 / 30 | Corner-Shop Coffee 32 / 36 | Cheesecake 100% / 85 | Whole Pizza 75 / 110 | Infomercial Headset (Host) ATK +10 / 120 | Puffer Jacket DEF +9 / 140 |

## 5. Edge Cases

- **Two members want the last croissant.** Each action resolves before the next member chooses, so the second member's menu already shows the item gone.
- **Revive with no one knocked out.** The revive item is disabled ("No one needs it").
- **The battle is lost after items were used.** Retry restores the bag (rule 7). Retreat after a Defeat keeps the bag as it was when the fight was lost: the items were used.
- **A save from before items existed.** It has no `items` key, so it loads with an empty bag.
- **A saved id with no record** (content removed). It stays in the bag and is not listed in battle (`move_for` returns null). Shops never sell it.
- **Wallet at exactly the price.** The purchase succeeds and leaves 0.

## 6. Dependencies

- **Turn Battle System:** `Move.Category.ITEM`, `TargetType.SINGLE_KO_ALLY`, `BattleCore.inventory` and `item_usable()`, the command menu's Items entry, the `BeatPlan` mapping.
- **Leveling (wallet):** `WorldState.money` is earned there (rule 5) and spent here.
- **Content Data Definitions:** `ItemData` (type `item`, prefix `item_`), and effect-type registration in `ContentBootstrap`.
- **Save/Load:** the `items` field of the `overworld` save section.
- **Camp & Party Management (not designed):** the interim camp mode hosts the shop until that system replaces it.
- **Faction Rule Modifiers:** a Special ban does not cover items; `move_allowed()` does.

## 7. Tuning Knobs

| Knob | Where | Value | Safe range | Too low | Too high |
|---|---|---|---|---|---|
| `max_per_item` | `Inventory.MAX_PER_ITEM` | 9 | 3–99 | Stocking up is a chore | Fights stop mattering |
| Each item's `amount` | `data/items/*.tres` | see F-table | 10–100% of a member's max | Not worth a turn | Specials redundant |
| Each item's `price` | `data/items/*.tres` | see F-table | 0.3–3 fights' pay | Free healing | Never bought |
| Shelves | `data/config/shop_config.tres` | café: all four | — | — | — |

## 8. Acceptance Criteria

- **AC-1** Under Bureaucratia in round 1, a croissant on a hurt ally heals 25 HP and leaves one fewer in the bag (`items_in_battle_test`).
- **AC-2** An item that would do nothing is refused, the bag is unchanged, and it is still that member's turn (`items_in_battle_test`).
- **AC-3** A revive targets only the knocked-out and returns them at F2's HP (`items_in_battle_test`).
- **AC-4** A party heal skips the knocked-out (`items_in_battle_test`).
- **AC-5** The Retry snapshot gives back items used in the lost attempt (`items_in_battle_test`).
- **AC-6** At the café, Set out is first and selected; buying moves money into the bag; a refusal names its reason and spends nothing (`camp_shop_test`).
- **AC-7** The bag survives a save round trip, and New Game empties it (`camp_shop_test`).
- **AC-9** A weapon fits only its user and an outfit fits anyone; equipping moves the item from the bag to the slot, and a swap returns the old item; the levelled base stat is untouched; the damage formula reads the bonus (`equipment_test`).
- **AC-10** Equipment is saved per member; a bad slot or id is dropped and reported (`squad_equipment_save_test`).
- **AC-11** The Menu's Party screen equips a trench coat from the bag (`menu_items_test`; evidence `items-shop/06-equipped.png`, `07-party.png`).
- **AC-8 [visual]** In the real game, the café shop and the battle Items list and target pick are on screen: `production/qa/evidence/items-shop/` (`tools/capture/items_shop_capture.gd`).

## Open Questions

- **OQ-1 — Resolved 2026-11-04.** Equipment is rules 10-12. Possible later additions: accessories, speed or MP gear, and gear dropped by bosses.
- **OQ-2 — Resolved 2026-11-04.** Using items outside battle: the Overworld and camp Menu shows **Items** under Resume (never in Battle). It lists the bag with the same rule-6 disabling, then a target pick showing each member's HP and MP, and applies the same `ItemEffects` that battle uses (`menu_items_test`; evidence `items-shop/05-menu-items.png`).
- **OQ-3** Selling, and alien-route prices (narrative bible §6: reputation changes shop prices) are not built.
