## Influencia's faction rule (Chapter 3, Sydney): the attention economy.
## Every hit an Influencia enemy takes earns it a Follower, worth
## `follower_attack` Attack each, up to `max_followers`. An influencer nobody
## hit all round loses one. Focus one target down; spreading damage feeds
## the whole room. Also owns the chapter's roster: Micro-Influencers, Ring
## Lights and the Mega-Influencer boss.
##
## Plugs into BattleCore through `on_damage_taken()` (gain) and
## `on_round_end()` (decay); the HUD shows the count through
## `get_stack_badge()`. Followers live on `Combatant.rule_stacks`, so a Retry
## (`reset_for_battle()`) clears them.
##
## Usage example:
## [codeblock]
## var rule := InfluenciaRule.new()
## rule.configure({"follower_attack": 2, "max_followers": 5})
## var battle := BattleCore.new(squad, enemies, null, rule)
## [/codeblock]
class_name InfluenciaRule
extends FactionRule

const FEED_MAGENTA: Color = Color("#E83E9C")

## Attack each Follower adds (rule record `params.follower_attack`).
var follower_attack: int = 2
## Most Followers one influencer can hold (`params.max_followers`).
var max_followers: int = 5

var _texts: Dictionary = {
	"banner": "INFLUENCIA — Attention economy. Every hit an influencer takes earns it a Follower: +{follower_attack} ATK each, up to {max_followers}. Ignore one for a round and it loses one.",
	"tooltip": "Influencia feeds on attention. Each hit gives that enemy a Follower (+{follower_attack} ATK, max {max_followers}). An enemy nobody hit this round loses a Follower. Focus one down instead of spreading damage.",
	"badge": "Followers {n}",
	"note_followers": "{n} Followers: +{atk} ATK.",
}


## Reads `params` (`follower_attack`, `max_followers`) and `texts` from the
## rule record; missing keys keep the defaults.
func configure(params: Dictionary, texts: Dictionary = {}) -> void:
	follower_attack = int(params.get("follower_attack", follower_attack))
	max_followers = int(params.get("max_followers", max_followers))
	for key: String in texts:
		_texts[key] = texts[key]


## An Influencia enemy that loses HP gains a Follower (capped) and is marked
## as hit this round. The squad never gains Followers.
func on_damage_taken(defender: Combatant, _attacker: Combatant, _amount: int) -> void:
	if not defender.is_enemy:
		return
	defender.hit_this_round = true
	_set_followers(defender, defender.rule_stacks + 1)


## Every living enemy nobody hit this round loses a Follower; the marks clear.
func on_round_end(living_enemies: Array[Combatant]) -> void:
	for enemy: Combatant in living_enemies:
		if not enemy.hit_this_round and enemy.rule_stacks > 0:
			_set_followers(enemy, enemy.rule_stacks - 1)
		enemy.hit_this_round = false


func _set_followers(c: Combatant, n: int) -> void:
	c.rule_stacks = clampi(n, 0, max_followers)
	c.rule_attack_bonus = c.rule_stacks * follower_attack


## Influencia's turn. Micro-Influencers pick on the healthiest squad member
## (clout), Ring Lights glare at the weakest, and the Mega-Influencer
## alternates Going Viral (hits everyone, odd rounds) with Cancelled on the
## weakest (even rounds).
func choose_enemy_action(enemy: Combatant, living_squad: Array[Combatant],
		round_number: int, _rng: RandomNumberGenerator) -> Array:
	if enemy.is_boss:
		if round_number % 2 == 1:
			var actions: Array = []
			for member in living_squad:
				actions.append({"move": _named_attack("move_going_viral"), "target": member})
			return actions
		return [{"move": _named_attack("move_cancelled"), "target": _weakest(living_squad)}]
	if enemy.record_id == "enemy_micro_influencer":
		return [{"move": _named_attack("move_hot_take"), "target": _healthiest(living_squad)}]
	return [{"move": _named_attack("move_blinding_glow"), "target": _weakest(living_squad)}]


func _named_attack(move_id: String) -> Move:
	return MoveAdapter.from_catalog(BattleCatalog.shipped(), move_id)


func _weakest(combatants: Array[Combatant]) -> Combatant:
	var pick: Combatant = combatants[0]
	for c in combatants:
		if _hp_fraction(c) < _hp_fraction(pick):
			pick = c
	return pick


func _healthiest(combatants: Array[Combatant]) -> Combatant:
	var pick: Combatant = combatants[0]
	for c in combatants:
		if c.hp > pick.hp:
			pick = c
	return pick


func _hp_fraction(c: Combatant) -> float:
	return float(c.hp) / float(maxi(1, c.max_hp))


func _fill(text: String, extra: Dictionary = {}) -> String:
	var values: Dictionary = {"follower_attack": follower_attack, "max_followers": max_followers}
	values.merge(extra)
	return text.format(values)


func get_banner_text(_round_number: int) -> String:
	return _fill(_texts["banner"])


## Feed Magenta (art bible), stable for the whole fight.
func get_identity_color() -> Color:
	return FEED_MAGENTA


func get_tooltip_text(_round_number: int) -> String:
	return _fill(_texts["tooltip"])


func get_combatant_tooltip_note(combatant: Combatant) -> String:
	if combatant.is_enemy and not combatant.is_knocked_out() and combatant.rule_stacks > 0:
		return _fill(_texts["note_followers"], {"n": combatant.rule_stacks, "atk": combatant.rule_attack_bonus})
	return ""


func get_stack_badge(stacks: int) -> String:
	return _fill(_texts["badge"], {"n": stacks}) if stacks > 0 else ""
