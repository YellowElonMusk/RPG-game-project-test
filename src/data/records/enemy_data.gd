## Content-catalog record: a hostile combatant, including bosses (Content
## Data GDD Rule 1, type `enemy`, prefix `enemy_`). The GDD's `stat_block`
## and `reward` groups are flattened into scalar exports (ADR-0001: every
## scalar is its own typed export). Data only, no logic (Rule 4).
##
## Usage example:
## [codeblock]
## var rec: EnemyData = ContentCatalog.get_record(&"enemy", "enemy_bureaucrat_drone")
## print(rec.faction_id, " boss=", rec.is_boss, " xp=", rec.reward_xp)
## [/codeblock]
class_name EnemyData
extends Resource

## Permanent lowercase snake_case ID with the `enemy_` prefix (Rule 2).
@export var id: String = ""
## Prior IDs this record still answers to (Rule 2).
@export var aliases: PackedStringArray = PackedStringArray()
## Player-visible name.
@export var display_name: String = ""
## Faction record ID (an `alien` faction).
@export var faction_id: String = ""
## True for a boss-tier enemy.
@export var is_boss: bool = false
## Stat block (Stats & Damage F1 ranges own the meaning and bounds).
@export var max_hp: int = 0
@export var max_mp: int = 0
@export var attack: int = 0
@export var defense: int = 0
@export var speed: int = 0
## Move record IDs this enemy can use.
@export var move_ids: PackedStringArray = PackedStringArray()
## AIProfile record ID (reserved type; Enemy AI owns it).
@export var ai_profile_id: String = ""
## Asset ID of the sprite set.
@export var sprite_set_id: String = ""
## Reward on defeat (Stats & Damage Rule 12 owns the ranges).
@export var reward_xp: int = 0
@export var reward_money: int = 0

## Player-visible text exports (TR-content-012, ADR-0013 §4).
const LOC_FIELDS: Array[StringName] = [&"display_name"]
## IDs and asset IDs (ADR-0013 §4).
const NON_LOC_FIELDS: Array[StringName] = [
	&"id", &"aliases", &"faction_id", &"move_ids", &"ai_profile_id", &"sprite_set_id",
]
