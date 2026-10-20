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


## Per-round upkeep hook for a faction that drains or restores a resource
## every round (MegaCorp's subscription billing — Story 004). BattleCore
## calls this once per round, right after _tick_round_effects() and before
## _advance_round(), with the living squad only (enemies are never billed).
## Default: no-op — a faction with no upkeep (Bureaucratia, the neutral
## default) just inherits this.
## Example: [code]faction_rule.apply_round_upkeep(battle.get_living_squad())[/code]
func apply_round_upkeep(_living_squad: Array[Combatant]) -> void:
	pass


## True if `actor` may submit `move` right now, beyond the generic
## specials_allowed()/can_afford() gates BattleCore already runs. MegaCorp's
## suspension rule (Story 004: 0 MP permits Attack only) lives here; a
## faction with no such restriction just inherits true. BattleCore.
## submit_action() consults this alongside specials_allowed().
## Example: [code]if not faction_rule.move_allowed(actor, move): return null[/code]
func move_allowed(_actor: Combatant, _move: Move) -> bool:
	return true


## Banner headline for the HUD's rule banner (Story 005), given the current
## round. Neutral default: no faction rule is restricting anything.
## Example: [code]banner_label.text = faction_rule.get_banner_text(battle.round_number)[/code]
func get_banner_text(_round_number: int) -> String:
	return "No faction rule in effect — Attack, Defend, and Specials are all available."


## Stable per-faction accent color (Story 005), used for a faction's card
## identity (enemy card borders/HP fill). Unlike get_banner_color(), this
## never varies by round — a faction whose banner color is also always
## stable (MegaCorp) only needs to override this one. Neutral default: a
## plain panel blue with no faction association.
func get_identity_color() -> Color:
	return Color("#4a5a8a")


## Accent color for the rule banner itself (Story 005), given the current
## round. Defaults to get_identity_color(); a faction whose banner color
## changes with the rule's state (Bureaucratia's pending/granted) overrides
## this separately from get_identity_color().
func get_banner_color(round_number: int) -> Color:
	return get_identity_color()


## Plain-language tooltip text explaining the active rule (Story 005), shown
## when the player hovers the banner or a combatant's card. Neutral default:
## nothing to explain.
func get_tooltip_text(_round_number: int) -> String:
	return "This fight has no special faction rule."


## Per-combatant tooltip addendum beyond get_tooltip_text()'s general rule
## explanation, for state that applies to one combatant rather than the
## whole battle (e.g. MegaCorp's suspension note). Default: nothing extra.
func get_combatant_tooltip_note(_combatant: Combatant) -> String:
	return ""
