## Tuning for the Rat Catchers' ambushes (narrative bible §6.5: human bounty
## hunters whose frequency rises with alien points). Shipped at
## `res://data/config/rat_catcher_config.tres`.
##
## Usage example:
## [codeblock]
## var cfg := RatCatcherConfig.load_default()
## var chance: float = RatCatchers.ambush_chance(world_state.alien_points, cfg)
## [/codeblock]
class_name RatCatcherConfig
extends Resource

const DEFAULT_PATH: String = "res://data/config/rat_catcher_config.tres"

## Map id -> chapter tier (`paris`, `london`, ...): the maps the Rat Catchers
## ambush on (each chapter's street segment). The tier names the records:
## `enc_rat_ambush_<tier>` and `enc_rat_captain_<tier>`.
@export var tier_by_map: Dictionary[String, String] = {}
## `chance = base + per_point * alien_points`, capped at `max_chance`; 0 at
## 0 alien points (the human-famous route never meets them).
@export_range(0.0, 1.0) var ambush_base_chance: float = 0.2
@export_range(0.0, 1.0) var ambush_per_point: float = 0.15
@export_range(0.0, 1.0) var ambush_max_chance: float = 0.8
## Ambushes at most this many times per map (a mild tax, not a wall).
@export_range(0, 5) var ambushes_per_map_max: int = 2
## The Captain comes once per chapter, on the walk home after the boss, when
## the squad has at least this many alien points.
@export_range(0, 10) var captain_min_alien_points: int = 1
## The conversations before each fight (`data/dialogue/`).
@export var ambush_conversation_id: String = "conv_rat_catchers_ambush"
@export var captain_conversation_id: String = "conv_rat_catchers_captain"


## The shipped config, or a default one when the file is missing.
static func load_default() -> RatCatcherConfig:
	if ResourceLoader.exists(DEFAULT_PATH):
		var cfg: RatCatcherConfig = ResourceLoader.load(DEFAULT_PATH) as RatCatcherConfig
		if cfg != null:
			return cfg
	return RatCatcherConfig.new()
