## Faction Reputation (systems index #15; narrative bible §6). Street cred
## comes from finishing an alien boss, alien points from letting him go
## (`BattleMode._on_boss_chosen`); both live in `WorldState` and are saved.
## Pure: reads only what it is given.
##
## Usage example:
## [codeblock]
## var line: String = Reputation.status_line(world_state)
## var price: int = Reputation.price_of(rec.price, world_state)
## [/codeblock]
class_name Reputation
extends RefCounted

enum Standing { EVEN, HUMAN, ALIEN }


## Which side the squad leans to: more street cred = HUMAN, more alien
## points = ALIEN, a tie (or no choices yet) = EVEN.
static func standing(world_state: WorldState) -> Standing:
	if world_state == null or world_state.street_cred == world_state.alien_points:
		return Standing.EVEN
	return Standing.HUMAN if world_state.street_cred > world_state.alien_points else Standing.ALIEN


## `1 - price_step * (street_cred - alien_points)`, clamped to the config's
## range: the factor shop prices are multiplied by.
static func price_multiplier(world_state: WorldState, cfg: ReputationConfig = null) -> float:
	if cfg == null:
		cfg = ReputationConfig.load_default()
	if world_state == null:
		return 1.0
	var lead: int = world_state.street_cred - world_state.alien_points
	return clampf(1.0 - cfg.price_step * lead, cfg.price_min_multiplier, cfg.price_max_multiplier)


## `base` after reputation, rounded to the nearest whole coin and never
## below 1 (a price of 0 or less is left as it is: free stays free).
static func price_of(base: int, world_state: WorldState, cfg: ReputationConfig = null) -> int:
	if base <= 0:
		return base
	return maxi(1, roundi(base * price_multiplier(world_state, cfg)))


## The Menu's one-line summary: "Street cred N  Alien points N".
static func status_line(world_state: WorldState) -> String:
	if world_state == null:
		return ""
	return "Street cred %d   Alien points %d" % [world_state.street_cred, world_state.alien_points]


## What a new recruit adds to their join line, by standing ("" when even).
static func recruit_aside(world_state: WorldState, cfg: ReputationConfig = null) -> String:
	if cfg == null:
		cfg = ReputationConfig.load_default()
	match standing(world_state):
		Standing.HUMAN:
			return cfg.recruit_aside_human
		Standing.ALIEN:
			return cfg.recruit_aside_alien
	return ""
