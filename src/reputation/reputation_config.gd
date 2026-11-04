## Faction Reputation tuning (narrative bible §6.3: reputation changes how
## NPCs treat you -- prices and who joins -- never battle rules). Read from
## `data/config/reputation_config.tres`.
##
## Usage example:
## [codeblock]
## var cfg: ReputationConfig = ReputationConfig.load_default()
## var price: int = Reputation.price_of(rec.price, world_state, cfg)
## [/codeblock]
class_name ReputationConfig
extends Resource

const PATH: String = "res://data/config/reputation_config.tres"

## Price change per point of lead: each point of street cred over alien
## points takes this fraction off shop prices (human-famous is cheaper
## early, §6.4); each point the other way adds it.
@export_range(0.0, 0.5, 0.01) var price_step: float = 0.1
## The cheapest prices can get, as a multiplier.
@export_range(0.1, 1.0, 0.05) var price_min_multiplier: float = 0.7
## The dearest prices can get, as a multiplier.
@export_range(1.0, 3.0, 0.05) var price_max_multiplier: float = 1.3
## Added to a recruit's join line when the squad is human-famous.
@export var recruit_aside_human: String = "They've heard about you on the street."
## Added to a recruit's join line when the squad is alien-friendly.
@export var recruit_aside_alien: String = "They keep one eye on your alien friends."


## The shipped config, or the defaults when it is missing.
static func load_default() -> ReputationConfig:
	if ResourceLoader.exists(PATH):
		var cfg := load(PATH) as ReputationConfig
		if cfg != null:
			return cfg
	return ReputationConfig.new()
