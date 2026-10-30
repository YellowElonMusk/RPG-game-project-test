## Story 017, AC-8 (GDD rule 4): every MVP `map_` record has `zone_rate`
## 0, and a fixture with `zone_rate = 0.1` fails the map validator naming
## the record (`MapValidator.check_zone_rates()`, run by
## `tools/ci/validate_maps.gd` through `validate_catalog()`).
extends GdUnitTestSuite

const _MAP_DIR: String = "res://data/maps"
const _BAD_RATE: float = 0.1


func test_every_shipped_map_record_has_zone_rate_zero() -> void:
	var records: Array = _shipped_map_records()
	assert_int(records.size()).is_greater(0)
	for rec: MapData in records:
		assert_float(rec.zone_rate).override_failure_message(rec.id).is_equal(0.0)
	assert_array(Array(MapValidator.check_zone_rates(records))).is_empty()


func test_fixture_with_zone_rate_point_one_fails_naming_the_record() -> void:
	var records: Array = _shipped_map_records()
	var bad := MapData.new()
	bad.id = "map_fixture_zoned"
	bad.zone_rate = _BAD_RATE
	records.append(bad)
	var errors: PackedStringArray = MapValidator.check_zone_rates(records)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("map_fixture_zoned").contains("zone_rate")


func _shipped_map_records() -> Array:
	var out: Array = []
	for file: String in DirAccess.get_files_at(_MAP_DIR):
		if file.begins_with("map_") and file.ends_with(".tres"):
			out.append(load(_MAP_DIR.path_join(file)) as MapData)
	return out
