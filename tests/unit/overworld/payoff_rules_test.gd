## Story 051, AC-21c (GDD rule 7a "Rules for payoffs"): on each banded
## map, an `open` payoff leads to a pocket (or, on the dungeon, a shortcut);
## at least half the symbols carry `clue` or `open`; `none` is capped,
## never on a Static symbol or the first symbol on the critical path; clue
## facets are unique region-wide and never the poster's; every tell is in
## view of its patrol; no fight item meets a critical-path requirement;
## pockets hold a `change` gag plus a remark or facet.
extends GdUnitTestSuite

const _MAPS: Array[String] = ["town", "segment", "dungeon", "boss_chamber"]
const _DUNGEON: String = "map_paris_dungeon_placeholder"


func test_the_shipped_payoffs_pass() -> void:
	assert_array(Array(_check(_maps(), _catalog()))).is_empty()


func test_reusing_a_clue_record_repeats_its_facet() -> void:
	var maps: Dictionary = _maps()
	_symbol(maps, "sym_dungeon_clerks_hall").encounter_id = "enc_paris_clerks_west"
	assert_str("\n".join(_check(maps, _catalog()))).contains("clue facet 'permit_takes_three_rounds' repeats")


func test_a_clue_on_the_posters_facet_is_named() -> void:
	var catalog: RecordCatalogDouble = _catalog()
	_payoff(catalog, "enc_paris_clerks_hall", {"type": "clue", "facet": "permit_ban", "text": "x"})
	assert_str("\n".join(_check(_maps(), catalog))).contains("repeats the first-encounter poster")


func test_none_on_the_first_symbol_and_over_the_cap_are_named() -> void:
	var maps: Dictionary = _maps()
	_symbol(maps, "sym_dungeon_clerks_first_room").encounter_id = "enc_paris_clerks_keen"
	var text: String = "\n".join(_check(maps, _catalog()))
	assert_str(text).contains("the first symbol along the critical path, 'sym_dungeon_clerks_first_room', has a `none` payoff")
	assert_str(text).contains("3 `none` payoffs (at most 2 for 6 symbols)")


func test_too_few_clue_or_open_is_named() -> void:
	var maps: Dictionary = _maps()
	for sid: String in ["sym_dungeon_clerks_hall", "sym_dungeon_clerks_hall_north"]:
		_symbol(maps, sid).encounter_id = "enc_paris_clerks_keen"
	assert_str("\n".join(_check(maps, _catalog()))).contains("only 2 of 6 patrolling symbols carry `clue` or `open`")


func test_a_missing_tell_is_named() -> void:
	var maps: Dictionary = _maps()
	for gag: GagInteractable in (maps[_DUNGEON] as OverworldMap).gags():
		if gag.marker_id == &"tell_hall_poster":
			gag.position = Vector3(2.5, 0.0, 30.5)
	assert_str("\n".join(_check(maps, _catalog()))).contains("'sym_dungeon_clerks_hall' has no payoff tell")


func test_a_pocket_without_its_change_gag_is_named() -> void:
	var maps: Dictionary = _maps()
	for gag: GagInteractable in (maps[_DUNGEON] as OverworldMap).gags():
		if gag.marker_id == &"gag_stamp_cupboard":
			gag.position = Vector3(10.5, 0.0, 14.5)
	assert_str("\n".join(_check(maps, _catalog()))).contains("opens a pocket without a `change` gag")


func test_a_segment_open_with_no_pocket_is_named() -> void:
	var maps: Dictionary = _maps()
	var seg: OverworldMap = maps["map_paris_segment_placeholder"]
	# Gate an open stretch of floor instead: it adds no cells, and the segment
	# has no story encounter, so it is no shortcut either.
	seg.find_checkpoint(&"cp_segment_pocket").blocked_rect = Rect2(12, 14, 1, 1)
	var text: String = "\n".join(_check(maps, _catalog()))
	assert_str(text).contains("opens neither a pocket nor (on a dungeon) a shortcut")
	assert_str(text).contains("map_paris_segment_placeholder: no `open` payoff leads to an optional pocket or a shortcut")


func test_a_fight_item_on_the_critical_path_is_named() -> void:
	var maps: Dictionary = _maps()
	var boom: CheckpointMarker = (maps[_DUNGEON] as OverworldMap).find_checkpoint(&"cp_permit_boom")
	boom.requirement_flag = ""
	boom.requirement_item_id = "item_fixture_badge"
	var catalog: RecordCatalogDouble = _catalog()
	_payoff(catalog, "enc_paris_clerks_keen", {"type": "item", "item_id": "item_fixture_badge", "label": "Badge"})
	assert_str("\n".join(_check(maps, catalog))).contains("item 'item_fixture_badge' meets critical-path checkpoint 'cp_permit_boom'")


func _check(maps: Dictionary, catalog: RecordCatalogDouble) -> PackedStringArray:
	return PayoffRules.check(maps, _records(), catalog, OverworldConfig.new(), PresentationConfig.new())


func _symbol(maps: Dictionary, sid: String) -> EncounterSymbol:
	for sym: EncounterSymbol in (maps[_DUNGEON] as OverworldMap).symbol_markers():
		if sym.symbol_id == sid:
			return sym
	return null


func _payoff(catalog: RecordCatalogDouble, id: String, payoff: Dictionary) -> void:
	var rec: EncounterData = (catalog.get_record(&"encounter", id) as EncounterData).duplicate()
	rec.victory_payoff = payoff
	catalog.add(&"encounter", rec)


func _catalog() -> RecordCatalogDouble:
	var catalog := RecordCatalogDouble.new()
	for f: String in DirAccess.get_files_at("res://data/encounters"):
		if f.ends_with(".tres"):
			catalog.add(&"encounter", load("res://data/encounters/" + f))
	return catalog


func _records() -> Dictionary:
	var out: Dictionary = {}
	for name: String in _MAPS:
		var rec: MapData = load("res://data/maps/map_paris_%s_placeholder.tres" % name)
		out[rec.id] = rec
	return out


func _maps() -> Dictionary:
	var out: Dictionary = {}
	for name: String in _MAPS:
		out["map_paris_%s_placeholder" % name] = auto_free(
				(load("res://data/maps/paris_%s_placeholder.tscn" % name) as PackedScene).instantiate())
	return out
