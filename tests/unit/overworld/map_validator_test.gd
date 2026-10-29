## Story 138 (AC-138c): `MapValidator` over the shipped map records passes,
## and an exit naming an unknown EntryPoint is reported. Story 080's
## AC-30f clearance and facing cases live in
## `data/entry_point_exit_clearance_test.gd`.
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


## Every shipped map: exits are checked against their targets, so the
## segment needs the dungeon, and the dungeon the boss chamber.
func _maps() -> Dictionary:
	var maps: Dictionary = {}
	for path: String in [_TOWN, _SEG, "res://data/maps/paris_dungeon_placeholder.tscn",
			"res://data/maps/paris_boss_chamber_placeholder.tscn"]:
		var map: OverworldMap = (load(path) as PackedScene).instantiate() as OverworldMap
		maps[map.map_id] = map
	return maps


func _free(maps: Dictionary) -> void:
	for map: OverworldMap in maps.values():
		map.free()
