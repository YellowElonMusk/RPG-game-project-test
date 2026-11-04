# Items & Shops

> **Status**: Designed (consumables and the camp shop built 2026-11-04). Equipment: Not Started.
> **System**: #16 in `systems-index.md`. Rigor: `standard`.
> **Owner**: economy-designer. **Created**: 2026-11-04, autonomous run (user: "keep building"; classic JRPG direction, 2026-11-03).

## 1. Overview

The squad carries a bag of consumables, buys them with Victory money at a camp's shop, and uses them in battle as a command alongside Attack, Defend and the Specials. Items are the classic JRPG safety net. They also give the player one honest way round a faction rule: an item is not a Special, so Bureaucratia's permit ban never blocks it. Equipment is out of scope for this version.

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
- **AC-8 [visual]** In the real game, the café shop and the battle Items list and target pick are on screen: `production/qa/evidence/items-shop/` (`tools/capture/items_shop_capture.gd`).

## Open Questions

- **OQ-1** Equipment (weapons and outfits per hero) is not designed. It needs a stat-modifier hook in Stats & Damage.
- **OQ-2** Using items from the Overworld Menu, outside battle. Camp already heals for free, so this matters only in the dungeon. Not built yet.
- **OQ-3** Selling, and alien-route prices (narrative bible §6: reputation changes shop prices) are not built.
