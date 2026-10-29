## Story 138 / story 080 (AC-138c, AC-30f): `MapValidator` over the shipped
## map records passes, and each broken placement is named.
extends GdUnitTestSuite

const _TOWN: String = "res://data/maps/paris_town_placeholder.tscn"
const _SEG: String = "res://data/maps/paris_segment_placeholder.tscn"


func test_shipped_maps_validate_clean() -> void:
	var catalog: ContentCatalogService = (Engine.get_main_loop() as SceneTree).root \
			.get_node(^"ContentCatalog") as ContentCatalogService
	assert_int(catalog.all_records(&"map").size()).is_greater_equal(2)
	assert_array(Array(MapValidator.validate_catalog(catalog, OverworldConfig.new()))).is_empty()


func test_unknown_entry_target_is_reported() -> void:
	var maps: Dictionary = _maps()
	(maps["map_paris_town_placeholder"] as OverworldMap).map_exits()[0].target_entry_id = &"nope"
	var errors: PackedStringArray = MapValidator.validate_maps(maps, OverworldConfig.new())
	_free(maps)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("nope")


func test_entry_inside_clearance_is_reported() -> void:
	var cfg := OverworldConfig.new()
	var maps: Dictionary = _maps()
	var seg: OverworldMap = maps["map_paris_segment_placeholder"]
	var entry: EntryPoint = seg.entry_points()[0]
	var rect: Rect2 = seg.map_exits()[0].trigger_rect
	var dist: float = MapValidator.distance_to_rect(entry.ground_position(seg), rect)
	# Non-default config: a clearance just past the authored distance fails.
	cfg.entry_clearance_m = dist - cfg.body_radius + 0.1
	var errors: PackedStringArray = MapValidator.validate_maps(maps, cfg)
	_free(maps)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("from_town")


func test_entry_facing_a_wall_is_reported() -> void:
	var maps: Dictionary = _maps()
	var seg: OverworldMap = maps["map_paris_segment_placeholder"]
	seg.entry_points()[0].facing = Vector2.ZERO
	var errors: PackedStringArray = MapValidator.validate_maps(maps, OverworldConfig.new())
	_free(maps)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("does not face")


func test_distance_to_rect_is_zero_inside_and_euclidean_outside() -> void:
	var rect := Rect2(1, 1, 2, 2)
	assert_float(MapValidator.distance_to_rect(Vector2(2, 2), rect)).is_equal(0.0)
	assert_float(MapValidator.distance_to_rect(Vector2(6, 7), rect)).is_equal_approx(5.0, 0.0001)


func _maps() -> Dictionary:
	var town: OverworldMap = (load(_TOWN) as PackedScene).instantiate() as OverworldMap
	var seg: OverworldMap = (load(_SEG) as PackedScene).instantiate() as OverworldMap
	return {town.map_id: town, seg.map_id: seg}


func _free(maps: Dictionary) -> void:
	for map: OverworldMap in maps.values():
		map.free()
