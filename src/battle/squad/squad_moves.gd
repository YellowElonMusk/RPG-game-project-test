## INTERIM per-combatant move list (Story 007). `TODO(content-migration)`:
## content-migration story 028 (squad specials adapter) replaces this with
## record-driven moves.
##
## `moves_for()` returns Attack, Defend and whichever of the five Story 003
## Specials `combatant.move_ids` names, via this file's own `move_id ->
## SquadSpecials` table. An enemy, or a squad member built without a backing
## character record (so `move_ids` is empty), gets Attack and Defend only.
##
## Usage example:
## [codeblock]
## var moves: Array[Move] = SquadMoves.moves_for(combatant)
## [/codeblock]
class_name SquadMoves
extends RefCounted


## Attack, Defend and `combatant`'s specials, in that order. A `move_id` not
## recognized by this file's interim table is skipped silently, so an
## unmapped id degrades to no special rather than an error.
## Example: [code]SquadMoves.moves_for(karen)  # [Attack, Defend, Speak to the Manager][/code]
static func moves_for(combatant: Combatant) -> Array[Move]:
	var moves: Array[Move] = [Move.make_attack(), Move.make_defend()]
	for move_id: String in combatant.move_ids:
		var special: Move = _special_for(move_id)
		if special != null:
			moves.append(special)
	return moves


## The interim `move_id -> SquadSpecials` table (story 003's five specials).
## `null` for any id outside this table.
static func _special_for(move_id: String) -> Move:
	match move_id:
		"move_speak_to_the_manager":
			return SquadSpecials.make_speak_to_the_manager()
		"move_family_meal":
			return SquadSpecials.make_family_meal()
		"move_appetizer":
			return SquadSpecials.make_appetizer()
		"move_viral_stunt":
			return SquadSpecials.make_viral_stunt()
		"move_home_run":
			return SquadSpecials.make_home_run()
	return null
