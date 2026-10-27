## Story 016, AC-26 (TR-content-011; ADR-0004 §4 register_record_validator):
## proves the generic registered-validator mechanism against every GDD F2
## boundary, using the test-double validators in f2_test_validators.gd whose
## bounds equal GDD F2. The real bounds belong to StatsValidators (Stats &
## Damage epic) and the Overworld's validators; AC-26 closes fully only when
## those epics re-run these fixtures against their real validators. Each
## boundary test loads its own fixture root under range_boundaries/. The
## mechanism checks at the end reuse valid_one_of_each (one record per type).
## Each test builds a fresh ContentCatalogService (never the autoload).
##
## Lambdas capture locals by value (GDScript 4.5+), so a counter shared with a
## lambda lives in an Array, never a bare int.
extends GdUnitTestSuite

const ReportFilters := preload("res://tests/unit/content_data/helpers/report_filters.gd")

const ROOT := "res://tests/unit/content_data/fixtures/range_boundaries"
const VALID_ONE_OF_EACH := "res://tests/unit/content_data/fixtures/valid_one_of_each"
## The one character record in valid_one_of_each.
const VALID_CHARACTER_ID := "char_baguette_thrower"

const F2TestValidators := preload("res://tests/unit/content_data/helpers/f2_test_validators.gd")

var _catalog: ContentCatalogService


func before_test() -> void:
	_catalog = auto_free(ContentCatalogService.new())


## Registers the five F2 test validators before load_all(), as
## ContentBootstrap would register the real ones.
func _register_all_f2_validators() -> void:
	_catalog.register_record_validator(&"character", Callable(F2TestValidators, "validate_character"))
	_catalog.register_record_validator(&"enemy", Callable(F2TestValidators, "validate_enemy"))
	_catalog.register_record_validator(&"move", Callable(F2TestValidators, "validate_move"))
	_catalog.register_record_validator(&"map", Callable(F2TestValidators, "validate_map"))
	_catalog.register_record_validator(&"occupation_stage", Callable(F2TestValidators, "validate_occupation_stage"))


## Loads the fixture root `dir` with the F2 validators registered, then
## asserts FAILED with exactly one error naming record_id and the flat field.
func _assert_invalid(dir: String, record_id: String, field: String) -> void:
	_register_all_f2_validators()

	var result: Error = _catalog.load_all(ROOT.path_join(dir))

	assert_int(result).is_equal(FAILED)
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.FAILED)
	assert_int(ReportFilters.errors(_catalog.report).size()).override_failure_message(
			"report: %s" % [_catalog.report]).is_equal(1)
	if ReportFilters.errors(_catalog.report).size() != 1:
		return  # Indexing an empty report would abort the whole suite.
	var entry: Dictionary = ReportFilters.errors(_catalog.report)[0]
	assert_str(String(entry["severity"])).is_equal("error")
	assert_str(entry["record_id"]).is_equal(record_id)
	assert_str(String(entry["field"])).is_equal(field)


## Loads the fixture root `dir` with the F2 validators registered, then
## asserts OK, READY and no report entry at all.
func _assert_valid(dir: String) -> void:
	_register_all_f2_validators()

	var result: Error = _catalog.load_all(ROOT.path_join(dir))

	assert_int(result).is_equal(OK)
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.READY)
	assert_array(ReportFilters.errors(_catalog.report)).override_failure_message(
			"report: %s" % [_catalog.report]).is_empty()


# --- max_hp: invalid 0, 1000; valid 1, 999 ---

func test_max_hp_below_min_errors_naming_record_and_field() -> void:
	_assert_invalid("max_hp_below_min", "char_max_hp_below_min", "max_hp")


func test_max_hp_above_max_errors_naming_record_and_field() -> void:
	_assert_invalid("max_hp_above_max", "char_max_hp_above_max", "max_hp")


func test_max_hp_at_min_loads_ready() -> void:
	_assert_valid("max_hp_at_min")


func test_max_hp_at_max_loads_ready() -> void:
	_assert_valid("max_hp_at_max")


# --- max_mp: invalid -1, 100; valid 0, 99 ---

func test_max_mp_below_min_errors_naming_record_and_field() -> void:
	_assert_invalid("max_mp_below_min", "char_max_mp_below_min", "max_mp")


func test_max_mp_above_max_errors_naming_record_and_field() -> void:
	_assert_invalid("max_mp_above_max", "char_max_mp_above_max", "max_mp")


func test_max_mp_at_min_loads_ready() -> void:
	_assert_valid("max_mp_at_min")


func test_max_mp_at_max_loads_ready() -> void:
	_assert_valid("max_mp_at_max")


# --- attack: invalid 0, 100; valid 1, 99 ---

func test_attack_below_min_errors_naming_record_and_field() -> void:
	_assert_invalid("attack_below_min", "char_attack_below_min", "attack")


func test_attack_above_max_errors_naming_record_and_field() -> void:
	_assert_invalid("attack_above_max", "char_attack_above_max", "attack")


func test_attack_at_min_loads_ready() -> void:
	_assert_valid("attack_at_min")


func test_attack_at_max_loads_ready() -> void:
	_assert_valid("attack_at_max")


# --- defense: invalid -1, 100; valid 0, 99 ---

func test_defense_below_min_errors_naming_record_and_field() -> void:
	_assert_invalid("defense_below_min", "char_defense_below_min", "defense")


func test_defense_above_max_errors_naming_record_and_field() -> void:
	_assert_invalid("defense_above_max", "char_defense_above_max", "defense")


func test_defense_at_min_loads_ready() -> void:
	_assert_valid("defense_at_min")


func test_defense_at_max_loads_ready() -> void:
	_assert_valid("defense_at_max")


# --- speed: invalid 0, 100; valid 1, 99 ---

func test_speed_below_min_errors_naming_record_and_field() -> void:
	_assert_invalid("speed_below_min", "char_speed_below_min", "speed")


func test_speed_above_max_errors_naming_record_and_field() -> void:
	_assert_invalid("speed_above_max", "char_speed_above_max", "speed")


func test_speed_at_min_loads_ready() -> void:
	_assert_valid("speed_at_min")


func test_speed_at_max_loads_ready() -> void:
	_assert_valid("speed_at_max")


# --- Move.cost: invalid -1; valid 0; no maximum ---

func test_move_cost_below_min_errors_naming_record_and_field() -> void:
	_assert_invalid("move_cost_below_min", "move_cost_below_min", "cost")


func test_move_cost_at_min_loads_ready() -> void:
	_assert_valid("move_cost_at_min")


## Edge case: Move.cost has no upper bound, so a cost of 100000 loads.
func test_move_cost_very_large_loads_ready() -> void:
	_assert_valid("move_cost_very_large")


# --- reward_xp: invalid -1, 10000; valid 0, 9999 ---

func test_reward_xp_below_min_errors_naming_record_and_field() -> void:
	_assert_invalid("reward_xp_below_min", "enemy_reward_xp_below_min", "reward_xp")


func test_reward_xp_above_max_errors_naming_record_and_field() -> void:
	_assert_invalid("reward_xp_above_max", "enemy_reward_xp_above_max", "reward_xp")


func test_reward_xp_at_min_loads_ready() -> void:
	_assert_valid("reward_xp_at_min")


func test_reward_xp_at_max_loads_ready() -> void:
	_assert_valid("reward_xp_at_max")


# --- reward_money: invalid -1, 10000; valid 0, 9999 ---

func test_reward_money_below_min_errors_naming_record_and_field() -> void:
	_assert_invalid("reward_money_below_min", "enemy_reward_money_below_min", "reward_money")


func test_reward_money_above_max_errors_naming_record_and_field() -> void:
	_assert_invalid("reward_money_above_max", "enemy_reward_money_above_max", "reward_money")


func test_reward_money_at_min_loads_ready() -> void:
	_assert_valid("reward_money_at_min")


func test_reward_money_at_max_loads_ready() -> void:
	_assert_valid("reward_money_at_max")


# --- OccupationStage.stage: invalid 0, 4; valid 1, 3 ---

func test_occupation_stage_below_min_errors_naming_record_and_field() -> void:
	_assert_invalid("ostage_stage_below_min", "ostage_stage_below_min", "stage")


func test_occupation_stage_above_max_errors_naming_record_and_field() -> void:
	_assert_invalid("ostage_stage_above_max", "ostage_stage_above_max", "stage")


func test_occupation_stage_at_min_loads_ready() -> void:
	_assert_valid("ostage_stage_at_min")


func test_occupation_stage_at_max_loads_ready() -> void:
	_assert_valid("ostage_stage_at_max")


# --- Map.base_stage: invalid 0, 4; valid 1, 3 ---

func test_map_base_stage_below_min_errors_naming_record_and_field() -> void:
	_assert_invalid("map_base_stage_below_min", "map_base_stage_below_min", "base_stage")


func test_map_base_stage_above_max_errors_naming_record_and_field() -> void:
	_assert_invalid("map_base_stage_above_max", "map_base_stage_above_max", "base_stage")


func test_map_base_stage_at_min_loads_ready() -> void:
	_assert_valid("map_base_stage_at_min")


func test_map_base_stage_at_max_loads_ready() -> void:
	_assert_valid("map_base_stage_at_max")


# --- Map.stage_table value: invalid 4; valid 1, 3 ---

func test_map_stage_table_above_max_errors_naming_record_and_field() -> void:
	_assert_invalid("map_stage_table_above_max", "map_stage_table_above_max", "stage_table")


func test_map_stage_table_at_min_loads_ready() -> void:
	_assert_valid("map_stage_table_at_min")


func test_map_stage_table_at_max_loads_ready() -> void:
	_assert_valid("map_stage_table_at_max")


# --- Map.zone_rate: invalid -0.01, 1.01; valid 0, 1 ---

func test_map_zone_rate_below_min_errors_naming_record_and_field() -> void:
	_assert_invalid("map_zone_rate_below_min", "map_zone_rate_below_min", "zone_rate")


func test_map_zone_rate_above_max_errors_naming_record_and_field() -> void:
	_assert_invalid("map_zone_rate_above_max", "map_zone_rate_above_max", "zone_rate")


func test_map_zone_rate_at_min_loads_ready() -> void:
	_assert_valid("map_zone_rate_at_min")


func test_map_zone_rate_at_max_loads_ready() -> void:
	_assert_valid("map_zone_rate_at_max")


# --- OccupationStage.liberation_grumble_min: invalid 0.09, 0.41; valid 0.1, 0.4 ---

func test_liberation_grumble_min_below_min_errors_naming_record_and_field() -> void:
	_assert_invalid("liberation_grumble_min_below_min", "ostage_grumble_below_min", "liberation_grumble_min")


func test_liberation_grumble_min_above_max_errors_naming_record_and_field() -> void:
	_assert_invalid("liberation_grumble_min_above_max", "ostage_grumble_above_max", "liberation_grumble_min")


func test_liberation_grumble_min_at_min_loads_ready() -> void:
	_assert_valid("liberation_grumble_min_at_min")


func test_liberation_grumble_min_at_max_loads_ready() -> void:
	_assert_valid("liberation_grumble_min_at_max")


# --- Mechanism checks ---

## A validator returning one warning entry adds exactly one warning entry
## with record_id and location filled in by the catalog; the catalog stays READY.
func test_validator_warning_entry_adds_warning_and_stays_ready() -> void:
	var validator := func(_record: Resource) -> Array[Dictionary]:
		return [{"severity": &"warning", "field": "x", "message": "m"}]
	_catalog.register_record_validator(&"character", validator)

	var result: Error = _catalog.load_all(VALID_ONE_OF_EACH)

	assert_int(result).is_equal(OK)
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.READY)
	# Only this validator's entries (field "x"); the fixture may carry others,
	# such as an unreferenced-record warning (story 019).
	var mine: Array[Dictionary] = []
	for candidate: Dictionary in _catalog.report:
		if String(candidate["field"]) == "x":
			mine.append(candidate)
	assert_int(mine.size()).is_equal(1)
	if mine.size() != 1:
		return
	var entry: Dictionary = mine[0]
	assert_str(String(entry["severity"])).is_equal("warning")
	assert_str(entry["record_id"]).is_equal(VALID_CHARACTER_ID)
	assert_str(String(entry["field"])).is_equal("x")
	var location: Dictionary = entry["location"]
	assert_str(location["file_path"]).ends_with(VALID_CHARACTER_ID + ".tres")
	assert_int(location["record_index"]).is_equal(0)
	assert_array(entry["related_locations"]).is_empty()


## A validator returning an entry without `field` gives one error entry on
## that record instead of crashing the load. Only the structured fields are
## asserted, never message (the catalog's report convention).
func test_validator_entry_missing_field_reports_error_not_crash() -> void:
	var validator := func(_record: Resource) -> Array[Dictionary]:
		return [{"severity": &"warning", "message": "m"}]
	_catalog.register_record_validator(&"character", validator)

	var result: Error = _catalog.load_all(VALID_ONE_OF_EACH)

	assert_int(result).is_equal(FAILED)
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.FAILED)
	assert_int(ReportFilters.errors(_catalog.report).size()).is_equal(1)
	if ReportFilters.errors(_catalog.report).size() != 1:
		return
	var entry: Dictionary = ReportFilters.errors(_catalog.report)[0]
	assert_str(String(entry["severity"])).is_equal("error")
	assert_str(entry["record_id"]).is_equal(VALID_CHARACTER_ID)


## register_record_validator() called from inside a running validator during
## the load is rejected: the late validator never runs and the load is
## otherwise unchanged (READY, empty report).
func test_register_during_load_is_rejected_and_late_validator_never_runs() -> void:
	var late_calls: Array[int] = [0]
	var late_validator := func(_record: Resource) -> Array[Dictionary]:
		late_calls[0] += 1
		return []
	var mid_load_validator := func(_record: Resource) -> Array[Dictionary]:
		_catalog.register_record_validator(&"move", late_validator)
		return []
	_catalog.register_record_validator(&"character", mid_load_validator)

	var result: Error = _catalog.load_all(VALID_ONE_OF_EACH)

	assert_int(result).is_equal(OK)
	assert_int(_catalog.state).is_equal(ContentCatalogService.State.READY)
	assert_array(ReportFilters.errors(_catalog.report)).is_empty()
	assert_int(late_calls[0]).override_failure_message("late validator ran").is_equal(0)


## register_record_validator() called after a load has finished is rejected:
## the late validator never runs and state and report are unchanged.
func test_register_after_load_is_rejected_and_late_validator_never_runs() -> void:
	assert_int(_catalog.load_all(VALID_ONE_OF_EACH)).is_equal(OK)
	var report_before: Array[Dictionary] = _catalog.report.duplicate(true)
	var late_calls: Array[int] = [0]
	var late_validator := func(_record: Resource) -> Array[Dictionary]:
		late_calls[0] += 1
		return []

	_catalog.register_record_validator(&"character", late_validator)

	assert_int(_catalog.state).is_equal(ContentCatalogService.State.READY)
	assert_int(_catalog.report.size()).is_equal(report_before.size())
	assert_int(late_calls[0]).override_failure_message("late validator ran").is_equal(0)
	# A second load is refused too, so the late validator still cannot run.
	assert_int(_catalog.load_all(VALID_ONE_OF_EACH)).is_equal(ERR_ALREADY_IN_USE)
	assert_int(late_calls[0]).is_equal(0)
