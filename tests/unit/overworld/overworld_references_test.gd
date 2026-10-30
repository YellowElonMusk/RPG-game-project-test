## Story 078, AC-30d (ADR-0012 §3 reference pass): every `enc_`,
## `symbol_id`, `liberation_flag`, `victory_payoff`, decree-gag and item
## reference resolves; each broken one is its own named error.
extends GdUnitTestSuite

const _MAPS: Array[String] = ["town", "segment", "dungeon", "boss_chamber"]
const _SEGMENT_ID: String = "map_paris_segment_placeholder"


func test_the_shipped_maps_resolve() -> void:
	var maps: Dictionary = {}
	for name: String in _MAPS:
		maps["map_paris_%s_placeholder" % name] = _scene(name)
	assert_array(Array(MapValidator.check_references(maps, _catalog(), _registry()))).is_empty()


func test_an_unknown_encounter_id_is_named() -> void:
	var map: OverworldMap = _scene("segment")
	map.symbol_markers()[0].encounter_id = "enc_fixture_missing"
	_assert_error(map, "encounter_id 'enc_fixture_missing' does not resolve")


func test_a_repeated_symbol_id_is_named() -> void:
	var map: OverworldMap = _scene("segment")
	map.symbol_markers()[1].encounter_id = map.symbol_markers()[0].encounter_id
	_assert_error(map, "is not unique")


func test_a_gag_naming_no_symbol_or_an_unregistered_flag_is_named() -> void:
	var map: OverworldMap = _scene("segment")
	var gag: GagInteractable = _gag(map, &"poster_permit_queue")
	gag.liberate_symbol = "sym_fixture_missing"
	gag.liberation_flag = "fixture_unregistered"
	var text: String = _errors(map)
	assert_str(text).contains("liberate_symbol 'sym_fixture_missing' is no symbol on the map")
	assert_str(text).contains("liberation_flag 'fixture_unregistered' is not registered")


func test_a_decree_with_no_raising_flag_or_symbol_is_named() -> void:
	var map: OverworldMap = _scene("segment")
	var decree: GagInteractable = _gag(map, &"decree_permits_town")
	decree.decree_stage = 3
	decree.decree_first_sight = "sym_fixture_missing"
	var text: String = _errors(map)
	assert_str(text).contains("decree_stage 3 has no registered raising flag")
	assert_str(text).contains("decree_first_sight 'sym_fixture_missing' is no symbol on the map")


func test_checkpoint_references_are_named() -> void:
	var map: OverworldMap = _scene("dungeon")
	var cp: CheckpointMarker = map.checkpoints()[0]
	cp.requirement_flag = "fixture_unregistered"
	cp.requirement_item_id = "item_fixture_missing"
	cp.linked_encounter_id = "enc_fixture_missing"
	var text: String = _errors(map, "map_paris_dungeon_placeholder")
	assert_str(text).contains("requirement_flag 'fixture_unregistered' is not registered")
	assert_str(text).contains("requirement_item_id 'item_fixture_missing' does not resolve")
	assert_str(text).contains("linked_encounter_id 'enc_fixture_missing' does not resolve")


func test_victory_payoff_references_are_named() -> void:
	for pair: Array in [
			[{"type": "open", "checkpoint": "cp_fixture_missing"}, "opens 'cp_fixture_missing', no checkpoint"],
			[{"type": "item", "item_id": "item_fixture_missing"}, "item_id 'item_fixture_missing' does not resolve"],
			[{"type": "clue"}, "clue names no facet"],
			[{"type": "loot"}, "type 'loot' is unknown"]]:
		var catalog: RecordCatalogDouble = _catalog()
		var rec: EncounterData = (load("res://data/encounters/enc_paris_clerks_west.tres") as EncounterData).duplicate()
		rec.victory_payoff = pair[0]
		catalog.add(&"encounter", rec)
		var errors: PackedStringArray = MapValidator.check_references(
				{_SEGMENT_ID: _scene("segment")}, catalog, _registry())
		assert_str("\n".join(errors)).contains(pair[1])


func _assert_error(map: OverworldMap, text: String) -> void:
	assert_str(_errors(map)).contains(text)


func _errors(map: OverworldMap, map_id: String = _SEGMENT_ID) -> String:
	return "\n".join(MapValidator.check_references({map_id: map}, _catalog(), _registry()))


func _gag(map: OverworldMap, id: StringName) -> GagInteractable:
	for gag: GagInteractable in map.gags():
		if gag.marker_id == id:
			return gag
	return null


func _scene(name: String) -> OverworldMap:
	return auto_free((load("res://data/maps/paris_%s_placeholder.tscn" % name) as PackedScene).instantiate())


func _registry() -> StoryFlagRegistry:
	return load("res://data/chapters/chapter_paris_flags.tres")


func _catalog() -> RecordCatalogDouble:
	var catalog := RecordCatalogDouble.new()
	for name: String in _MAPS:
		catalog.add(&"map", load("res://data/maps/map_paris_%s_placeholder.tres" % name))
	for f: String in DirAccess.get_files_at("res://data/encounters"):
		if f.ends_with(".tres"):
			catalog.add(&"encounter", load("res://data/encounters/" + f))
	return catalog
