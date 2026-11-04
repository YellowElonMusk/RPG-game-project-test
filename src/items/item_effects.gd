## Item records -> battle moves, and the one place an item's effect is
## applied (Items & Shops GDD rules 4-5, F1-F2), shared by battle and the
## Overworld Menu so the two can never disagree.
##
## An `ItemData.effects` entry is `{"type": <type>, "amount": <int>}` with
## type `heal_hp`, `restore_mp`, `revive` (amount = percent of max HP) or
## `heal_party`. Only the first entry is read.
##
## Usage example:
## [codeblock]
## var move: Move = ItemEffects.move_for(catalog.get_record(&"item", "item_croissant"))
## battle.submit_action(move, battle.squad[0])
## [/codeblock]
class_name ItemEffects
extends RefCounted

const TYPE_TO_EFFECT: Dictionary = {
	"heal_hp": Move.ItemEffect.HEAL_HP,
	"restore_mp": Move.ItemEffect.RESTORE_MP,
	"revive": Move.ItemEffect.REVIVE,
	"heal_party": Move.ItemEffect.HEAL_PARTY,
}


## Registers the item effect types as the `&"items"` system's vocabulary
## (ADR-0004 §1 step 1), so item records validate.
static func register(catalog: ContentCatalogService) -> void:
	catalog.register_known_effect_types(&"items", PackedStringArray(TYPE_TO_EFFECT.keys()))


## The ITEM `Move` for `rec`, or null when `rec` is not a consumable with a
## known effect. 0 MP; the target type follows the effect.
static func move_for(rec: ItemData) -> Move:
	if rec == null or rec.kind != "consumable" or rec.effects.is_empty():
		return null
	var e: Dictionary = rec.effects[0]
	var effect: Move.ItemEffect = TYPE_TO_EFFECT.get(String(e.get("type", "")), Move.ItemEffect.NONE)
	if effect == Move.ItemEffect.NONE:
		return null
	var target: Move.TargetType = Move.TargetType.SINGLE_ALLY
	if effect == Move.ItemEffect.REVIVE:
		target = Move.TargetType.SINGLE_KO_ALLY
	elif effect == Move.ItemEffect.HEAL_PARTY:
		target = Move.TargetType.SELF
	var move := Move.new(rec.display_name, Move.Category.ITEM, 0, int(e.get("amount", 0)), target)
	move.item_id = rec.id
	move.item_effect = effect
	return move


## `true` when `move` would do something to `target` (or, for HEAL_PARTY,
## to anyone in `party`): rule 6, an item is never spent for nothing.
static func has_effect(move: Move, target: Combatant, party: Array[Combatant]) -> bool:
	match move.item_effect:
		Move.ItemEffect.HEAL_HP:
			return target != null and not target.is_knocked_out() and target.hp < target.max_hp
		Move.ItemEffect.RESTORE_MP:
			return target != null and not target.is_knocked_out() and target.mp < target.max_mp
		Move.ItemEffect.REVIVE:
			return target != null and target.is_knocked_out()
		Move.ItemEffect.HEAL_PARTY:
			for m: Combatant in party:
				if not m.is_knocked_out() and m.hp < m.max_hp:
					return true
	return false


## Applies `move`'s effect. Returns the HP restored (summed for HEAL_PARTY;
## 0 for RESTORE_MP). F1: flat amounts, clamped to max. F2: a revive sets
## HP to max(1, floor(max_hp * amount / 100)).
static func apply(move: Move, target: Combatant, party: Array[Combatant]) -> int:
	match move.item_effect:
		Move.ItemEffect.HEAL_HP:
			return target.heal(move.power)
		Move.ItemEffect.RESTORE_MP:
			target.mp = mini(target.max_mp, target.mp + move.power)
			return 0
		Move.ItemEffect.REVIVE:
			return target.heal(revive_hp(target.max_hp, move.power))
		Move.ItemEffect.HEAL_PARTY:
			var total: int = 0
			for m: Combatant in party:
				if not m.is_knocked_out():
					total += m.heal(move.power)
			return total
	return 0


## F2: the HP a revive returns a knocked-out ally to.
static func revive_hp(max_hp: int, percent: int) -> int:
	return maxi(1, int(floor(max_hp * percent / 100.0)))
