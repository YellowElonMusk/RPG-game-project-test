## Base class for a faction's battle rule: the hook BattleCore consults so
## faction-specific behavior (Bureaucratia's permit ban — Story 002;
## MegaCorp's billing — Story 004) never has to be hardcoded into the core.
##
## The defaults here ARE the neutral, rule-free battle: specials are always
## allowed, and each enemy makes one basic Attack on a random living squad
## member. BattleCore uses a plain FactionRule.new() when no faction rule is
## injected, so it never needs a null check.
##
## A faction overrides either or both methods. Not @abstract on purpose (the
## base class must be instantiable as the neutral default). Godot 4.7:
## overrides inherit the typed return, so every override must `return` on
## every path.
##
## Usage example:
## [codeblock]
## class_name MyFactionRule
## extends FactionRule
##
## func specials_allowed(round_number: int) -> bool:
##     return round_number > 1
## [/codeblock]
class_name FactionRule
extends RefCounted


## True if Move.Category.SPECIAL may be used this round, by either side.
## BattleCore.submit_action() rejects a squad Special when this is false;
## a rule's own choose_enemy_action() is responsible for not emitting enemy
## Specials while it is false. Default: always true.
## Example: [code]if battle.faction_rule.specials_allowed(battle.round_number): ...[/code]
func specials_allowed(_round_number: int) -> bool:
	return true


## One enemy's turn, as an ordered list of actions BattleCore resolves in
## sequence. Each element is a Dictionary [code]{"move": Move, "target": Combatant}[/code];
## `target` is null for a self-only move such as Defend. Returning more than
## one action expresses a compound turn (e.g. Defend, then Attack).
##
## `living_squad` is never empty when BattleCore calls this, and `enemy` is
## alive. Default: one basic power-10 Attack on a random living squad member.
## Example: [code]var actions := rule.choose_enemy_action(enemy, battle.get_living_squad(), battle.round_number, battle.rng)[/code]
func choose_enemy_action(_enemy: Combatant, living_squad: Array[Combatant],
		_round_number: int, rng: RandomNumberGenerator) -> Array:
	var target: Combatant = living_squad[rng.randi_range(0, living_squad.size() - 1)]
	return [{"move": Move.make_attack(), "target": target}]
