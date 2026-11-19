## Turn Battle tuning that is not per-encounter (Turn Battle GDD's owed Flee
## section: flee chance from config, `can_flee` from the encounter, a failed
## attempt passes the turn). Read from `data/config/battle_config.tres`.
##
## Usage example:
## [codeblock]
## var cfg: BattleConfig = BattleConfig.load_default()
## var got_away: bool = rng.randf() < cfg.flee_chance
## [/codeblock]
class_name BattleConfig
extends Resource

const PATH: String = "res://data/config/battle_config.tres"

## Chance that one Run attempt succeeds and the squad leaves the fight.
@export_range(0.0, 1.0, 0.05) var flee_chance: float = 0.75


## The shipped config, or the defaults when it is missing.
static func load_default() -> BattleConfig:
	if ResourceLoader.exists(PATH):
		var cfg: BattleConfig = load(PATH) as BattleConfig
		if cfg != null:
			return cfg
	return BattleConfig.new()
