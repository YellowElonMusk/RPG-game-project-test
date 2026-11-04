## Which ending plays when the campaign's last chapter ends (narrative bible
## §6.6): the side the squad leaned to across every alien boss's
## spare-or-finish choice. More alien points = the true ending (the
## alliance re-runs its numbers, M-1); more street cred = the human ending,
## which is not the bad one (the resistance keeps thriving); a tie = the
## split ending. Pure.
##
## Usage example:
## [codeblock]
## var ending: EndingData = EndingData.load_by_id(EndingRules.pick_id(world_state))
## [/codeblock]
class_name EndingRules
extends RefCounted

const HUMAN: String = "ending_human"
const ALIEN: String = "ending_alien"
const SPLIT: String = "ending_split"


## The ending ID for `world_state`'s reputation.
static func pick_id(world_state: WorldState) -> String:
	match Reputation.standing(world_state):
		Reputation.Standing.HUMAN:
			return HUMAN
		Reputation.Standing.ALIEN:
			return ALIEN
	return SPLIT
