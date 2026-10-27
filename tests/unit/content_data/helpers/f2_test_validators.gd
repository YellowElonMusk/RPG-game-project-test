## Story 016 test doubles: range validators proving the generic
## register_record_validator() mechanism (ADR-0004 §4) against every GDD F2
## boundary in the story's table. Each function stands in for a validator a
## real owning system will register (StatsValidators with StatsConfig, the
## Overworld's validators -- neither exists yet). The bounds are test
## constants equal to GDD F2 (the "No hardcoded data" exception for boundary
## tests), never literals in ContentCatalog (TR-content-011). Every function
## is pure: it reads only `record` and returns Array[Dictionary] entries in
## the ADR-0004 §4 shape (`severity`, `field`, `message`); the catalog fills
## `record_id` and `location`. Deliberately has no `class_name`, like
## spy_content_catalog.gd: load it with preload().
##
## Usage example:
## [codeblock]
## const F2TestValidators := preload("res://tests/unit/content_data/helpers/f2_test_validators.gd")
## catalog.register_record_validator(&"character", Callable(F2TestValidators, "validate_character"))
## [/codeblock]
extends RefCounted

## stat_block.max_hp bounds (GDD F2).
const MAX_HP_MIN := 1
const MAX_HP_MAX := 999
## stat_block.max_mp bounds (GDD F2).
const MAX_MP_MIN := 0
const MAX_MP_MAX := 99
## stat_block.attack bounds (GDD F2).
const ATTACK_MIN := 1
const ATTACK_MAX := 99
## stat_block.defense bounds (GDD F2).
const DEFENSE_MIN := 0
const DEFENSE_MAX := 99
## stat_block.speed bounds (GDD F2).
const SPEED_MIN := 1
const SPEED_MAX := 99
## Move.cost lower bound (GDD F2); there is no upper bound.
const MOVE_COST_MIN := 0
## reward.xp bounds (GDD F2).
const REWARD_XP_MIN := 0
const REWARD_XP_MAX := 9999
## reward.money bounds (GDD F2).
const REWARD_MONEY_MIN := 0
const REWARD_MONEY_MAX := 9999
## Occupation stage bounds (GDD F2), shared by OccupationStage.stage,
## Map.base_stage and every Map.stage_table value.
const OCCUPATION_STAGE_MIN := 1
const OCCUPATION_STAGE_MAX := 3
## Map.zone_rate bounds (GDD F2).
const ZONE_RATE_MIN := 0.0
const ZONE_RATE_MAX := 1.0
## OccupationStage.liberation_grumble_min bounds (GDD F2).
const LIBERATION_GRUMBLE_MIN_MIN := 0.1
const LIBERATION_GRUMBLE_MIN_MAX := 0.4


## Checks a CharacterData record's stat block (GDD F2).
## Example: [code]var entries: Array[Dictionary] = F2TestValidators.validate_character(rec)[/code]
static func validate_character(record: CharacterData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_check_range(out, &"max_hp", record.max_hp, MAX_HP_MIN, MAX_HP_MAX)
	_check_range(out, &"max_mp", record.max_mp, MAX_MP_MIN, MAX_MP_MAX)
	_check_range(out, &"attack", record.attack, ATTACK_MIN, ATTACK_MAX)
	_check_range(out, &"defense", record.defense, DEFENSE_MIN, DEFENSE_MAX)
	_check_range(out, &"speed", record.speed, SPEED_MIN, SPEED_MAX)
	return out


## Checks an EnemyData record's stat block and reward (GDD F2).
## Example: [code]var entries: Array[Dictionary] = F2TestValidators.validate_enemy(rec)[/code]
static func validate_enemy(record: EnemyData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_check_range(out, &"max_hp", record.max_hp, MAX_HP_MIN, MAX_HP_MAX)
	_check_range(out, &"max_mp", record.max_mp, MAX_MP_MIN, MAX_MP_MAX)
	_check_range(out, &"attack", record.attack, ATTACK_MIN, ATTACK_MAX)
	_check_range(out, &"defense", record.defense, DEFENSE_MIN, DEFENSE_MAX)
	_check_range(out, &"speed", record.speed, SPEED_MIN, SPEED_MAX)
	_check_range(out, &"reward_xp", record.reward_xp, REWARD_XP_MIN, REWARD_XP_MAX)
	_check_range(out, &"reward_money", record.reward_money, REWARD_MONEY_MIN, REWARD_MONEY_MAX)
	return out


## Checks a MoveData record's cost (GDD F2); there is no upper bound.
## Example: [code]var entries: Array[Dictionary] = F2TestValidators.validate_move(rec)[/code]
static func validate_move(record: MoveData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_check_range(out, &"cost", record.cost, MOVE_COST_MIN)
	return out


## Checks a MapData record's base_stage, every stage_table value and
## zone_rate (GDD F2). A stage_table entry is reported on field `stage_table`.
## Example: [code]var entries: Array[Dictionary] = F2TestValidators.validate_map(rec)[/code]
static func validate_map(record: MapData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_check_range(out, &"base_stage", record.base_stage, OCCUPATION_STAGE_MIN, OCCUPATION_STAGE_MAX)
	for flag: String in record.stage_table:
		_check_range(out, &"stage_table", record.stage_table[flag], OCCUPATION_STAGE_MIN, OCCUPATION_STAGE_MAX)
	_check_range(out, &"zone_rate", record.zone_rate, ZONE_RATE_MIN, ZONE_RATE_MAX)
	return out


## Checks an OccupationStageData record's stage and liberation_grumble_min (GDD F2).
## Example: [code]var entries: Array[Dictionary] = F2TestValidators.validate_occupation_stage(rec)[/code]
static func validate_occupation_stage(record: OccupationStageData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_check_range(out, &"stage", record.stage, OCCUPATION_STAGE_MIN, OCCUPATION_STAGE_MAX)
	_check_range(out, &"liberation_grumble_min", record.liberation_grumble_min,
			LIBERATION_GRUMBLE_MIN_MIN, LIBERATION_GRUMBLE_MIN_MAX)
	return out


# Appends one error entry to `out` when `value` is outside [minimum, maximum]
# inclusive; `maximum` defaults to INF for an unbounded field. The fixture
# stores the exact literal and the constant is the same literal, so a float
# boundary such as 0.1 compares equal, never drifts (story 016 Engine Notes).
static func _check_range(out: Array[Dictionary], field: StringName, value: float,
		minimum: float, maximum: float = INF) -> void:
	if value < minimum or value > maximum:
		out.append({"severity": &"error", "field": field,
				"message": "%s is %s, outside [%s, %s]." % [field, value, minimum, maximum]})
