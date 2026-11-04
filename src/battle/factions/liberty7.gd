## Liberty-7's faction rule (Chapter 4, New York): Mandatory Freedom.
## Nobody may use the same command twice in a row: after an Attack a squad
## member must Defend, use a special or an item, and so on. Everything else
## stays free. The Liberty-7 roster alternates its own two moves, so the rule
## reads the same on both sides. Also owns the chapter's roster: Star
## Troopers, Eagle Drones and the Super Patriot boss.
##
## Plugs into BattleCore through `on_action_resolved()` (remember the
## command) and `move_allowed()` (refuse a repeat); the command menu shows
## the refusal through `get_combatant_tooltip_note()`. The memory lives on
## `Combatant.rule_last_command`, so a Retry or a new fight clears it.
##
## Usage example:
## [codeblock]
## var rule := Liberty7Rule.new()
## var battle := BattleCore.new(squad, enemies, null, rule)
## [/codeblock]
class_name Liberty7Rule
extends FactionRule

const ANTHEM_BLUE: Color = Color("#2F5BEA")

var _texts: Dictionary = {
	"banner": "LIBERTY-7 — Mandatory Freedom. Nobody may use the same command twice in a row. You're free to pick anything else!",
	"tooltip": "Liberty-7 enforces freedom of choice: no one may repeat the command they used last turn (Attack, Defend, a special or an item). Alternate. Liberty-7's troops follow the rule too.",
	"note_repeat": "Freedom! {name} just used {command}. Choose anything else.",
}


## Reads `texts` from the rule record; missing keys keep the defaults. The
## rule has no numeric params.
func configure(_params: Dictionary, texts: Dictionary = {}) -> void:
	for key: String in texts:
		_texts[key] = texts[key]


## Remembers the command `actor` just used (both sides).
func on_action_resolved(actor: Combatant, move: Move) -> void:
	actor.rule_last_command = move.display_name


## A command is refused only when it repeats the actor's previous one.
## Attack and Defend never repeat each other, so a member always has a
## legal command.
func move_allowed(actor: Combatant, move: Move) -> bool:
	return actor.rule_last_command.is_empty() or move.display_name != actor.rule_last_command


## Liberty-7's turn. Star Troopers alternate Marching Orders (the healthiest
## squad member) and Baton Twirl (the weakest); Eagle Drones alternate
## Screech of Liberty (the weakest) and Talon Swoop (the healthiest); the
## Super Patriot alternates Fireworks Finale (everyone, odd rounds) and
## Anthem Solo (the weakest, even rounds). Nobody repeats a command.
func choose_enemy_action(enemy: Combatant, living_squad: Array[Combatant],
		round_number: int, _rng: RandomNumberGenerator) -> Array:
	var odd: bool = round_number % 2 == 1
	if enemy.is_boss:
		if odd:
			var actions: Array = []
			for member in living_squad:
				actions.append({"move": _named_attack("move_fireworks_finale"), "target": member})
			return actions
		return [{"move": _named_attack("move_anthem_solo"), "target": _weakest(living_squad)}]
	if enemy.record_id == "enemy_star_trooper":
		if odd:
			return [{"move": _named_attack("move_marching_orders"), "target": _healthiest(living_squad)}]
		return [{"move": _named_attack("move_baton_twirl"), "target": _weakest(living_squad)}]
	if odd:
		return [{"move": _named_attack("move_screech_of_liberty"), "target": _weakest(living_squad)}]
	return [{"move": _named_attack("move_talon_swoop"), "target": _healthiest(living_squad)}]


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


func get_banner_text(_round_number: int) -> String:
	return _texts["banner"]


## Anthem Blue (art bible), stable for the whole fight.
func get_identity_color() -> Color:
	return ANTHEM_BLUE


func get_tooltip_text(_round_number: int) -> String:
	return _texts["tooltip"]


## The command menu's refusal text for a repeat (and the card tooltip): who
## used what last turn.
func get_combatant_tooltip_note(combatant: Combatant) -> String:
	if combatant.is_enemy or combatant.is_knocked_out() or combatant.rule_last_command.is_empty():
		return ""
	return String(_texts["note_repeat"]).format({"name": combatant.display_name,
			"command": combatant.rule_last_command})
