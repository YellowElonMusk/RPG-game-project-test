## Story 098, AC-38 (GDD Formulas, "Load-time invariants"): the default
## `OverworldConfig` passes `validate()`. One fixture per invariant I1-I13
## and I15-I18 breaks only that invariant, and the only error names that
## ID. The GDD's own example values (some of which break neighbours too,
## since the invariants share knobs) each name their ID.
extends GdUnitTestSuite


func test_the_default_config_passes() -> void:
	assert_array(Array(OverworldConfig.new().validate())).is_empty()


## Each fixture: [id, {knob: value}, dt_max]. Paired knobs keep every other
## invariant true (worked by hand from the table's inequalities).
func test_each_fixture_breaks_only_its_invariant(id: String, knobs: Dictionary, dt_max: float,
		test_parameters := [
			["I1", {"f_patrol": 0.8}, 0.1],
			["I2", {"escape_max_s": 9.0}, 0.1],
			["I3", {"encounter_grace_s": 0.5}, 0.1],
			["I4", {"symbol_chase_m": 2.0, "notice_path_cap_m": 3.0, "notice_delay_s": 0.0,
					"symbol_notice_rear_m": 1.5, "symbol_giveup_m": 3.9}, 0.1],
			["I5", {"flee_grace_s": 1.8, "encounter_grace_s": 1.5}, 0.1],
			["I6", {"flee_grace_s": 1.9}, 0.1],
			["I7", {"safe_radius_m": 3.5}, 0.1],
			["I8", {"body_radius": 0.5}, 0.1],
			["I9", {"corner_assist_m": 0.45}, 0.1],
			["I10", {"d_min_overworld": 300}, 0.1],
			["I11", {}, 0.3],
			["I12", {"symbol_notice_rear_m": 1.4}, 0.1],
			["I15", {"notice_path_cap_m": 4.2}, 0.1],
			["I16", {"notice_path_cap_m": 5.0, "symbol_giveup_m": 6.0}, 0.1],
			["I17", {"turn_pause_s": 0.5}, 0.1],
			["I18", {"beacon_h_m": 3.0, "wall_h_max": 3.0}, 0.1],
		]) -> void:
	var errors: PackedStringArray = _config(knobs).validate(dt_max)
	assert_int(errors.size()).override_failure_message("%s fixture: %s" % [id, errors]).is_equal(1)
	assert_str(errors[0]).starts_with(id + ":")


func test_a_falling_cap_breaks_only_i13() -> void:
	var records: Array = []
	for pair: Array in [[1, 3], [2, 2]]:
		var o := OccupationStageData.new()
		o.faction_id = "faction_fixture"
		o.stage = pair[0]
		o.clutter_caps = {"poster": pair[1]}
		records.append(o)
	var errors: PackedStringArray = OverworldConfig.new().validate(OverworldConfig.DT_MAX_DEFAULT, records)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).starts_with("I13:")
	assert_str(errors[0]).contains("poster stage 1->2")


func test_the_shipped_stage_records_pass_i13() -> void:
	var records: Array = []
	for s: int in [1, 2, 3]:
		records.append(load("res://data/occupation_stages/ostage_bureaucratia_stage%d.tres" % s))
	assert_array(Array(OverworldConfig.new().validate(OverworldConfig.DT_MAX_DEFAULT, records))).is_empty()


## The GDD's worked example values name their invariant.
func test_the_gdd_examples_name_their_ids(id: String, knobs: Dictionary, dt_max: float,
		test_parameters := [
			["I1", {"f_chase": 0.9}, 0.1],
			["I3", {"encounter_grace_s": 0.5}, 0.1],
			["I4", {"symbol_giveup_m": 5.0, "symbol_chase_m": 3.5}, 0.1],
			["I5", {"flee_grace_s": 2.0, "walk_speed": 3.0, "symbol_giveup_m": 8.0}, 0.1],
			["I11", {"walk_speed": 4.0}, 0.3],
			["I15", {"symbol_chase_m": 3.5, "notice_path_cap_m": 4.5}, 0.1],
			["I16", {"notice_path_cap_m": 5.0, "symbol_giveup_m": 6.0}, 0.1],
			["I17", {"turn_pause_s": 0.5}, 0.1],
			["I18", {"beacon_h_m": 3.0, "wall_h_max": 3.0}, 0.1],
		]) -> void:
	var errors: PackedStringArray = _config(knobs).validate(dt_max)
	var ids: Array[String] = []
	for e: String in errors:
		ids.append(e.get_slice(":", 0))
	assert_array(ids).contains([id])


func test_t_escape_matches_the_gdd_default() -> void:
	# I2's default check: t_escape(2*body_radius) = 9.93 s.
	assert_float(OverworldConfig.new().t_escape(0.6)).is_equal_approx(9.93, 0.01)


func _config(knobs: Dictionary) -> OverworldConfig:
	var cfg := OverworldConfig.new()
	for k: String in knobs:
		cfg.set(k, knobs[k])
	return cfg
