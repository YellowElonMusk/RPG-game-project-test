## Story 053, AC-22 (`occupation_stage`): over base stages, stage tables and
## flag sets (the empty set included) the stage equals the formula; removing
## a raising flag keeps the stage and logs a warning; over any sequence of
## loads the stage never decreases.
extends GdUnitTestSuite


func test_stage_equals_the_formula(base: int, table: Dictionary, flags: Array, expected: int,
		test_parameters := [
			[1, {}, [], 1],
			[3, {}, [], 3],
			[1, {"permits_mandatory": 2}, [], 1],
			[1, {"permits_mandatory": 2}, ["permits_mandatory"], 2],
			[1, {"a": 2, "b": 3}, ["a", "b"], 3],
			[2, {"a": 1}, ["a"], 2],
			[1, {"a": 5}, ["a"], 3],
			# No base stage and no table: no stage (story 055).
			[0, {}, [], 0],
			# A table on a stageless map still clamps up from 1.
			[0, {"a": 2}, [], 1],
		]) -> void:
	var rec := _record(base, table)
	var result: Array = OccupationStage.compute(rec, func(f: String) -> bool: return f in flags, 0)
	assert_int(result[0]).is_equal(expected)
	assert_str(result[1]).is_empty()


func test_removing_a_raising_flag_keeps_the_stage_and_warns() -> void:
	var rec := _record(1, {"permits_mandatory": 2})
	var result: Array = OccupationStage.compute(rec, func(_f: String) -> bool: return false, 2)
	assert_int(result[0]).is_equal(2)
	assert_str(result[1]).contains("raising flag was removed")


func test_the_stage_never_decreases_over_loads() -> void:
	var rec := _record(1, {"a": 2, "b": 3})
	var flags: Dictionary = {}
	var stored: int = 0
	var seen: Array[int] = []
	# Flags come and go between loads; each load stores its stage.
	for step: Array in [[], ["a"], ["a", "b"], ["a"], [], ["b"]]:
		flags.clear()
		for f: String in step:
			flags[f] = true
		var result: Array = OccupationStage.compute(rec, func(f: String) -> bool: return flags.has(f), stored)
		stored = result[0]
		seen.append(stored)
	assert_array(seen).is_equal([1, 2, 3, 3, 3, 3])


func test_paris_records_hold_the_expected_base_stages() -> void:
	# Story 055's base-stage half: Town 1, segment 1, dungeon 3.
	for pair: Array in [["town", 1], ["segment", 1], ["dungeon", 3]]:
		var rec: MapData = load("res://data/maps/map_paris_%s_placeholder.tres" % pair[0])
		assert_int(rec.base_stage).is_equal(pair[1])
	var segment: MapData = load("res://data/maps/map_paris_segment_placeholder.tres")
	assert_int(int(segment.stage_table.get("permits_mandatory", 0))).is_equal(2)


func _record(base: int, table: Dictionary) -> MapData:
	var rec := MapData.new()
	rec.id = "map_fixture"
	rec.base_stage = base
	for k: String in table:
		rec.stage_table[k] = table[k]
	return rec
