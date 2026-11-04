## The Rat Catchers' battle rule (narrative bible §6.5): human bounty
## hunters, so there is no alien rule at all, only a fair fight. Owns their
## turn: Trappers alternate Net Throw (the healthiest) and Rat Trap (the
## weakest), Tunnel Scouts alternate Headlamp Glare (the healthiest) and
## Tunnel Rush (the weakest), and the Captain alternates Wanted Poster
## (everyone, odd rounds) with Citizen's Arrest (the weakest, even rounds).
## Each chapter has its own records (`enemy_rat_trapper_london`, ...), matched
## here by prefix.
##
## Built by `BattleFactory` for `faction_rat_catchers`, a `human_nation`
## faction, which may not carry a rule record (content GDD Rule 8), so the
## texts live here.
##
## Usage example:
## [codeblock]
## var battle := BattleCore.new(squad, enemies, rng, RatCatchersRule.new())
## [/codeblock]
class_name RatCatchersRule
extends FactionRule

## Tunnel Brown: a human colour, never an alien faction's.
const TUNNEL_BROWN: Color = Color("#8A6A3A")
const BANNER: String = "RAT CATCHERS — Human bounty hunters. No alien rule: a fair fight. They think you're the traitors."
const TOOLTIP: String = "The Rat Catchers are the human resistance's bounty hunters. Nothing is banned, billed or followed: Attack, Defend, specials and items all work. They come more often the more alien points you have."


func choose_enemy_action(enemy: Combatant, living_squad: Array[Combatant],
		round_number: int, _rng: RandomNumberGenerator) -> Array:
	var odd: bool = round_number % 2 == 1
	if enemy.is_boss:
		if odd:
			var actions: Array = []
			for member in living_squad:
				actions.append({"move": _named_attack("move_wanted_poster"), "target": member})
			return actions
		return [{"move": _named_attack("move_citizens_arrest"), "target": _weakest(living_squad)}]
	if enemy.record_id.begins_with("enemy_rat_trapper"):
		if odd:
			return [{"move": _named_attack("move_net_throw"), "target": _healthiest(living_squad)}]
		return [{"move": _named_attack("move_rat_trap"), "target": _weakest(living_squad)}]
	if odd:
		return [{"move": _named_attack("move_headlamp_glare"), "target": _healthiest(living_squad)}]
	return [{"move": _named_attack("move_tunnel_rush"), "target": _weakest(living_squad)}]


func get_banner_text(_round_number: int) -> String:
	return BANNER


func get_identity_color() -> Color:
	return TUNNEL_BROWN


func get_tooltip_text(_round_number: int) -> String:
	return TOOLTIP


func _named_attack(move_id: String) -> Move:
	return MoveAdapter.from_catalog(BattleCatalog.shipped(), move_id)


func _weakest(combatants: Array[Combatant]) -> Combatant:
	var pick: Combatant = combatants[0]
	for c in combatants:
		if float(c.hp) / float(maxi(1, c.max_hp)) < float(pick.hp) / float(maxi(1, pick.max_hp)):
			pick = c
	return pick


func _healthiest(combatants: Array[Combatant]) -> Combatant:
	var pick: Combatant = combatants[0]
	for c in combatants:
		if c.hp > pick.hp:
			pick = c
	return pick
