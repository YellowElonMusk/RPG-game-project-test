## Stories 086 (AC-31c) and 119 (AC-50), GDD rules 12 and 16: on the
## Paris first-encounter map (the segment), along the first leg's `L_crit`
## from the Town-side EntryPoint, the first patrol is at least
## `safe_radius_m + symbol_chase_m + first_patrol_clearance_m` along the
## path, the faction clue and the `optional_teach` speaker come before the
## first notice point, and the first patrol's section bypass ratio is at
## most `first_bypass_ratio_max`. The pre-redesign layout fails each.
extends GdUnitTestSuite

const _MAPS: Array[String] = ["town", "segment", "dungeon", "boss_chamber"]
const _SEGMENT_ID: String = "map_paris_segment_placeholder"


func test_the_shipped_segment_passes() -> void:
	var maps: Dictionary = _maps()
	assert_array(Array(MapValidator.check_first_encounter(_steps(), _records(), maps, OverworldConfig.new()))).is_empty()
	var cfg := OverworldConfig.new()
	var m: Dictionary = MapValidator.first_encounter_metrics(maps[_SEGMENT_ID],
			(_records()[_SEGMENT_ID] as MapData).critical_path[0], cfg)
	assert_str(m["first_symbol"]).is_equal("enc_paris_clerks_west")
	assert_float(m["clue"]).is_less(m["first_notice"])
	assert_float(m["teach"]).is_less(m["first_notice"])


func test_the_old_layout_fails_patrol_clearance_clue_and_section_ratio() -> void:
	var maps: Dictionary = _maps()
	var seg: OverworldMap = maps[_SEGMENT_ID]
	for sym: EncounterSymbol in seg.symbol_markers():
		if sym.encounter_id == "enc_paris_clerks_west":
			sym.patrol_path = PackedVector2Array([Vector2(9.5, 5.5), Vector2(14.5, 5.5)])
	for gag: GagInteractable in seg.gags():
		if gag.marker_id == &"gag_permit_poster":
			gag.position = Vector3(8.5, 0.0, 12.5)
	var text: String = "\n".join(MapValidator.check_first_encounter(_steps(), _records(), maps, OverworldConfig.new()))
	assert_str(text).contains("first patrol enc_paris_clerks_west is 6.2 m along L_crit")
	assert_str(text).contains("no faction_clue marker before the first notice point")
	assert_str(text).contains("section bypass ratio 1.43")


func test_a_teaching_speaker_off_the_path_is_named() -> void:
	var maps: Dictionary = _maps()
	for npc: NpcSpawn in (maps[_SEGMENT_ID] as OverworldMap).npc_spawns():
		if npc.optional_teach:
			npc.position = Vector3(20.5, 0.0, 14.5)
	var text: String = "\n".join(MapValidator.check_first_encounter(_steps(), _records(), maps, OverworldConfig.new()))
	assert_str(text).contains("no optional_teach speaker before the first notice point")


func _steps() -> ChapterSteps:
	return load("res://data/chapters/chapter_paris_steps.tres")


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
