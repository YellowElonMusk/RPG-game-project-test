## Story 018, AC-8c (GDD rule 4, Edge Cases): at runtime a map whose record
## carries `zone_rate = 0.1` logs one error and makes zero zone rolls over
## `ceil(60 / dt_max)` Exploring frames.
extends GdUnitTestSuite

const _BAD_RATE: float = 0.1


func test_nonzero_zone_rate_logs_once_and_never_rolls() -> void:
	_assert_suppressed(OverworldConfig.DT_MAX_DEFAULT)


func test_suppressed_at_a_shorter_dt_max() -> void:
	_assert_suppressed(OverworldConfig.DT_MAX_DEFAULT / 2.0)


func test_zero_zone_rate_logs_nothing() -> void:
	var mode: OverworldMode = auto_free(_mode(0.0))
	assert_array(mode.zone_errors).is_empty()
	assert_float(mode.zone_rate).is_equal(0.0)


func _assert_suppressed(dt_max: float) -> void:
	var mode: OverworldMode = auto_free(_mode(_BAD_RATE))
	mode.grace_active = true
	assert_int(mode.zone_errors.size()).is_equal(1)
	assert_str(mode.zone_errors[0]).contains("map_paris_segment_placeholder")
	assert_float(mode.zone_rate).is_equal(0.0)
	var frames: int = ceili(60.0 / dt_max)
	for i: int in frames:
		mode.step_frame(dt_max, Vector2.ZERO)
	assert_int(mode.zone_rolls).is_equal(0)
	assert_int(mode.zone_errors.size()).is_equal(1)


func _mode(rate: float) -> OverworldMode:
	var machine: GameStateMachine = ProbeFixture.GameStateFixtures.make_machine_in_overworld()["machine"]
	var mode := OverworldMode.new()
	mode.config = OverworldConfig.new()
	mode.setup(machine, null)
	mode.world_state = WorldState.new()
	var catalog := RecordCatalogDouble.new()
	var rec: MapData = (load("res://data/maps/map_paris_segment_placeholder.tres") as MapData).duplicate()
	rec.zone_rate = rate
	catalog.add(&"map", rec)
	for id: String in ["enc_paris_clerks_west", "enc_paris_clerks_east"]:
		catalog.add(&"encounter", RecordCatalogDouble.make_encounter(id))
	mode.encounter_catalog = catalog
	mode.load_map((load(ProbeFixture.SEGMENT) as PackedScene).instantiate() as OverworldMap)
	return mode
