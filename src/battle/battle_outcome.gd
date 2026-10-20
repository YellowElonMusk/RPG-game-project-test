## The reported result of one resolved action (one Attack, Defend, or
## Special use by one combatant). A later HUD story (005) reads these to
## show damage numbers, MP spent, and knockouts; this story only needs the
## data to exist and be accurate (Acceptance Criterion 8).
##
## Usage example:
## [codeblock]
## battle_core.action_resolved.connect(func(outcome: BattleOutcome):
##     print("%s used %s: %d HP, %d MP" % [
##         outcome.actor.display_name, outcome.move_name,
##         outcome.hp_delta, outcome.mp_delta]))
## [/codeblock]
class_name BattleOutcome
extends RefCounted

## Who acted.
var actor: Combatant
## Display name of the move used (kept as a String, not a Move reference,
## so an outcome stays valid even if the move object is later discarded).
var move_name: String
var category: Move.Category
## Who was affected, if any (null for a self-only move like Defend).
var target: Combatant
## Net HP change applied to `target` this action: negative for damage,
## positive for a heal (no move in this story heals; the field exists so
## Story 003's Chef specials can reuse it without an API change).
var hp_delta: int
## Net MP change applied to `actor` this action (negative = spent).
var mp_delta: int
## True if this action's damage brought `target` to 0 HP.
var target_knocked_out: bool
## The round this action happened in, for log display.
var round_number: int


func _init(p_actor: Combatant, p_move_name: String, p_category: Move.Category,
		p_target: Combatant, p_hp_delta: int, p_mp_delta: int,
		p_target_knocked_out: bool, p_round_number: int) -> void:
	actor = p_actor
	move_name = p_move_name
	category = p_category
	target = p_target
	hp_delta = p_hp_delta
	mp_delta = p_mp_delta
	target_knocked_out = p_target_knocked_out
	round_number = p_round_number
