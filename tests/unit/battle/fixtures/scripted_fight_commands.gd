## Story 008: the two fixed command scripts driving `BattleCore.submit_action()`
## in `battle_scripted_fight_characterization_test.gd` -- constants only, no
## logic. Each entry is submitted once, in order, whenever it is next a
## living squad member's turn (never a specific named member -- the engine
## does not check which character "owns" a move, so the test harness submits
## straight down the list regardless of who is active). `target_index`
## resolves against the CURRENT living roster at submit time
## (`min(target_index, living.size() - 1)`), for whichever side the move's
## `target_type` reads (enemies for `SINGLE_ENEMY`, squad for `SINGLE_ALLY`;
## ignored for `SELF`/Defend). `"move_id"` is `"attack"` for the generic
## power-10 Attack, `"defend"` for Defend, or a `BattleContentSeam` move id.
##
## Both scripts open with a short coverage block (each of the squad's 5
## specials used once, a Defend, and the one deliberately rejected command
## this story's AC asks for), then a long filler tail so the fight is very
## likely to reach `battle_ended` on its own before the script or
## `CharacterizationExpected.ROUND_CAP` runs out.
##
## The clamp is exercised: once only one enemy is left alive, the remaining
## commands use `target_index: 2`, which must clamp to 0 -- the same survivor
## index 0 would pick, so the fight (and its frozen pins) is unchanged, but a
## missing or wrong clamp would index past the living list. The one
## ally-targeting command (Appetizer) keeps index 0: clamping it would pick a
## different ally and change the fight.
class_name ScriptedFightCommands
extends RefCounted

## Bureaucratia fight (fixture squad vs. Clerk, Clerk, Supervisor).
## Round 1: Karen's Speak to the Manager is rejected -- specials are banned
## until the permit (round 4) -- then she Defends instead. Rounds 1-3: plain
## Attacks (specials still banned). Round 4 (permit granted): all 4 specials
## not yet used; Home Run knocks out the second Clerk, leaving only the
## Supervisor. Round 5 on: Chef's second special, Appetizer, then filler, all
## enemy-targeting entries at the clamped index 2.
const BUREAUCRATIA: Array[Dictionary] = [
	# Round 1
	{"move_id": "move_speak_to_the_manager", "target_index": 0},  # REJECTED: specials banned round 1-3
	{"move_id": "defend", "target_index": 0},
	{"move_id": "attack", "target_index": 0},
	{"move_id": "attack", "target_index": 0},
	{"move_id": "attack", "target_index": 0},
	# Round 2
	{"move_id": "attack", "target_index": 0},
	{"move_id": "attack", "target_index": 0},
	{"move_id": "attack", "target_index": 0},
	{"move_id": "attack", "target_index": 0},
	# Round 3
	{"move_id": "attack", "target_index": 0},
	{"move_id": "attack", "target_index": 0},
	{"move_id": "attack", "target_index": 0},
	{"move_id": "attack", "target_index": 0},
	# Round 4 (permit granted): the 4 specials not yet used
	{"move_id": "move_speak_to_the_manager", "target_index": 0},
	{"move_id": "move_family_meal", "target_index": 0},
	{"move_id": "move_viral_stunt", "target_index": 0},
	{"move_id": "move_home_run", "target_index": 0},  # knocks out the last Clerk
	# Round 5: Chef's second special; only the Supervisor is left, so index 2 clamps to 0
	{"move_id": "attack", "target_index": 2},
	{"move_id": "move_appetizer", "target_index": 0},
	{"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2},
	# Filler: Attacks on the last living enemy (index 2, clamped), rounds 6-15
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
]

## MegaCorp fight (fixture squad vs. Security Drone, Middle Manager, CEO).
## Florida Man is arranged to 4 MP right after `start_battle()` (RC-1, not
## part of this script): she casts Viral Stunt (cost 3) in round 1, leaving
## 1; MegaCorp's round-1 billing (1 MP) drops her to 0, so her round-2 Defend
## is the suspension case this story's AC asks for -- rejected, then she
## Attacks instead (Attack is never suspended). Karen's round-4 Attack
## knocks out the Middle Manager, leaving only the CEO; from there every
## entry uses the clamped index 2.
const MEGACORP: Array[Dictionary] = [
	# Round 1: the 4 specials not yet used (Chef's second, Appetizer, is round 2)
	{"move_id": "move_speak_to_the_manager", "target_index": 0},
	{"move_id": "move_family_meal", "target_index": 0},
	{"move_id": "move_viral_stunt", "target_index": 0},
	{"move_id": "move_home_run", "target_index": 0},
	# Round 2
	{"move_id": "defend", "target_index": 0},
	{"move_id": "move_appetizer", "target_index": 0},
	{"move_id": "defend", "target_index": 0},  # REJECTED: Florida Man suspended (0 MP)
	{"move_id": "attack", "target_index": 0},
	{"move_id": "attack", "target_index": 0},
	# Rounds 3-4: on the Middle Manager until Karen's round-4 Attack knocks it out
	{"move_id": "attack", "target_index": 0}, {"move_id": "attack", "target_index": 0},
	{"move_id": "attack", "target_index": 0}, {"move_id": "attack", "target_index": 0},
	# Filler: only the CEO is left, so index 2 clamps to 0, rounds 4-12
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
	{"move_id": "attack", "target_index": 2}, {"move_id": "attack", "target_index": 2},
]
